// Evitar caídas por EPIPE cuando stdout/stderr se cierran
process.stdout?.on('error', (err) => { if (err.code === 'EPIPE') return; });
process.stderr?.on('error', (err) => { if (err.code === 'EPIPE') return; });

const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const fs = require('fs/promises');
const fsSync = require('fs');
const { exec, execFile } = require('child_process');
const dotenv = require('dotenv');

// Cargar variables de entorno
dotenv.config({ path: path.join(__dirname, '../../.env') });

const aiService = require('../services/ai');
const { resolveInsideWorkspace, isCommandDenied, computeLineDiff } = require('./safety');

// GPU / raster switches — production only, applied before app.whenReady()
const _isDevEarly = process.env.NODE_ENV === 'development' || process.env.ELECTRON_RELOAD === '1';
if (!_isDevEarly) {
  try {
    app.commandLine.appendSwitch('enable-gpu-rasterization');
    app.commandLine.appendSwitch('enable-zero-copy');
  } catch (_) {}
}

// Live reload en desarrollo con Hot Reload / Hot Swap de CSS (dev-only, never bundled via build.files)
const isDev = _isDevEarly;
if (isDev && !process.env.ELECTRON_NO_RELOAD) {
  try {
    require('electron-reload')(path.join(__dirname, '..'), {
      electron: path.join(__dirname, '../../node_modules/.bin/electron'),
      ignored: (targetPath) => /node_modules|[/\\]\./.test(targetPath) || targetPath.endsWith('.css'),
      awaitWriteFinish: true
    });
  } catch (err) {
    console.error('Error al inicializar electron-reload:', err);
  }
}

let mainWindow = null;

function startRealtimeSync() {
  if (!aiService.isAuthenticated() || !mainWindow) return;
  aiService.startSyncStream((event) => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('sync:cloud-event', event);
    }
  }, (err) => {
    try {
      if (process.stdout?.writable) {
        console.warn('Realtime sync stream warning:', err.message);
      }
    } catch (_) {}
  });

  aiService.startDesktopRemoteStream((event) => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('desktop:remote-event', event);
    }
  }, (err) => {
    try {
      if (process.stdout?.writable) {
        console.warn('Desktop remote stream warning:', err.message);
      }
    } catch (_) {}
  });
}

function stopRealtimeSync() {
  aiService.stopSyncStream();
  aiService.stopDesktopRemoteStream();
}

function createWindow() {
  const iconPath = path.join(__dirname, '../assets/icon.png');
  if (process.platform === 'darwin' && app.dock) {
    try {
      app.dock.setIcon(iconPath);
    } catch (_) {}
  }

  mainWindow = new BrowserWindow({
    width: 1240,
    height: 840,
    minWidth: 900,
    minHeight: 600,
    title: 'Newton AI',
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#1F2528',
    show: true,
    icon: iconPath,
    webPreferences: {
      preload: path.join(__dirname, '../preload/preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
      spellcheck: false,
      backgroundThrottling: false,
      v8CacheOptions: 'code'
    }
  });

  mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));
  mainWindow.once('ready-to-show', () => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.show();
      mainWindow.focus();
    }
  });
  // Failsafe: if ready-to-show never fires (e.g. renderer error), force show after 1.5 s
  setTimeout(() => {
    if (mainWindow && !mainWindow.isDestroyed() && !mainWindow.isVisible()) {
      console.warn('[Newton] ready-to-show did not fire — forcing window visible');
      mainWindow.show();
    }
  }, 1500);
  mainWindow.webContents.on('did-fail-load', (_e, code, desc, url) => {
    console.error(`[Newton] did-fail-load ${code} ${desc} — ${url}`);
  });

  mainWindow.webContents.on('did-finish-load', () => {
    startRealtimeSync();
  });

  if (process.env.NODE_ENV === 'development') {
    // mainWindow.webContents.openDevTools();

    // Hot swap de CSS en tiempo real sin recargar la app ni perder estado
    try {
      const chokidar = require('chokidar');
      const rendererDir = path.join(__dirname, '../renderer');
      const cssWatcher = chokidar.watch(path.join(rendererDir, '**/*.css'), {
        ignoreInitial: true,
        awaitWriteFinish: {
          stabilityThreshold: 100,
          pollInterval: 50
        }
      });

      cssWatcher.on('change', (filePath) => {
        if (!mainWindow || mainWindow.isDestroyed()) return;
        const relativePath = path.relative(rendererDir, filePath);
        const fileName = path.basename(filePath);
        console.log(`[Hot CSS] Archivo modificado: ${relativePath} -> recargando estilos...`);
        
        mainWindow.webContents.executeJavaScript(`
          (() => {
            const links = Array.from(document.querySelectorAll('link[rel="stylesheet"]'));
            const target = links.find(l => {
              const href = l.getAttribute('href') || '';
              return href.includes('${fileName}') || href.includes('${relativePath}');
            });
            if (target) {
              const baseHref = target.getAttribute('href').split('?')[0];
              target.setAttribute('href', baseHref + '?hot=' + Date.now());
            } else {
              links.forEach(l => {
                const baseHref = l.getAttribute('href').split('?')[0];
                l.setAttribute('href', baseHref + '?hot=' + Date.now());
              });
            }
          })()
        `).catch((err) => console.error('Error aplicando Hot CSS:', err));
      });

      mainWindow.on('closed', () => {
        cssWatcher.close();
      });
    } catch (err) {
      console.warn('No se pudo inicializar Hot CSS watcher:', err);
    }
  }

  mainWindow.on('closed', () => {
    stopRealtimeSync();
    mainWindow = null;
  });
}

// -------------------------------------------------------------
// IPC Handlers: AI Gateway & Singularity
// -------------------------------------------------------------

ipcMain.handle('ai:get-me', async () => {
  try {
    const data = await aiService.getMe();
    return { success: true, data };
  } catch (error) {
    console.error('Error fetching user info:', error);
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:get-config', () => {
  return { success: true, data: aiService.getConfig() };
});

ipcMain.handle('auth:login', async (event, credentials) => {
  try {
    const data = await aiService.login(credentials);
    startRealtimeSync();
    return { success: true, data };
  } catch (error) {
    console.error('Error logging in:', error);
    return { success: false, error: error.message };
  }
});

ipcMain.handle('auth:register', async (event, payload) => {
  try {
    const data = await aiService.register(payload);
    startRealtimeSync();
    return { success: true, data };
  } catch (error) {
    console.error('Error registering:', error);
    return { success: false, error: error.message };
  }
});

ipcMain.handle('auth:logout', async () => {
  try {
    stopRealtimeSync();
    const data = await aiService.logout();
    return { success: true, data };
  } catch (error) {
    console.error('Error logging out:', error);
    return { success: false, error: error.message };
  }
});

ipcMain.handle('auth:set-api-key', (event, key) => {
  try {
    const res = aiService.setApiKey(key);
    startRealtimeSync();
    return { success: true, data: res };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('auth:status', () => {
  return {
    success: true,
    data: {
      isAuthenticated: aiService.isAuthenticated(),
      config: aiService.getConfig()
    }
  };
});

ipcMain.handle('ai:rotate-key', async () => {
  try {
    const data = await aiService.rotateApiKey();
    return { success: true, data };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:get-models', async () => {
  try {
    const data = await aiService.getModels();
    return { success: true, data };
  } catch (error) {
    console.error('Error fetching models:', error);
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:get-chats', async (event, { limit = 50, offset = 0 } = {}) => {
  try {
    const data = await aiService.getChats(limit, offset);
    return { success: true, data };
  } catch (error) {
    console.error('Error fetching chats:', error);
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:create-chat', async (event, payload = {}) => {
  try {
    const data = await aiService.createChat(payload);
    return { success: true, data };
  } catch (error) {
    console.error('Error creating chat:', error);
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:get-messages', async (event, { chatId, limit = 50, before = null } = {}) => {
  try {
    const data = await aiService.getChatMessages(chatId, limit, before);
    return { success: true, data };
  } catch (error) {
    console.error('Error getting messages:', error);
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:update-chat', async (event, { chatId, data } = {}) => {
  try {
    const res = await aiService.updateChat(chatId, data);
    return { success: true, data: res };
  } catch (error) {
    console.error('Error updating chat:', error);
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:delete-chat', async (event, chatId) => {
  try {
    const res = await aiService.deleteChat(chatId);
    return { success: true, data: res };
  } catch (error) {
    console.error('Error deleting chat:', error);
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:get-usage', async () => {
  try {
    const data = await aiService.getUsage();
    return { success: true, data };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:get-usage-history', async (event, { days = 7, limit = 30 } = {}) => {
  try {
    const data = await aiService.getUsageHistory(days, limit);
    return { success: true, data };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:upload-file', async (event, payload) => {
  try {
    const data = await aiService.uploadFile(payload);
    return { success: true, data };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:get-file-metadata', async (event, fileId) => {
  try {
    const data = await aiService.getFileMetadata(fileId);
    return { success: true, data };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:generate-title', async (event, prompt) => {
  try {
    const title = await aiService.generateTitle(prompt);
    return { success: true, data: title };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('auth:resend-verification', async (event, email) => {
  try {
    const res = await aiService.resendVerification(email);
    return { success: true, data: res };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:generate-image', async (event, payload) => {
  try {
    const res = await aiService.generateImage(payload);
    return { success: true, data: res };
  } catch (error) {
    console.error('Error generating image:', error);
    return { success: false, error: error.message };
  }
});

ipcMain.handle('ai:send-message', async (event, payload) => {
  try {
    let pendingDeltas = '';
    let pendingFull = '';
    let flushTimer = null;
    const FLUSH_MS = 48;
    const flush = () => {
      if (!pendingDeltas) return;
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('ai:stream-chunk', { type: 'delta', text: pendingDeltas, full: pendingFull });
      }
      pendingDeltas = '';
    };
    const response = await aiService.sendMessage(payload, (chunk) => {
      if (!mainWindow || mainWindow.isDestroyed()) return;
      if (chunk.type === 'delta') {
        pendingDeltas += chunk.text;
        pendingFull = chunk.full;
        if (!flushTimer) flushTimer = setTimeout(() => { flushTimer = null; flush(); }, FLUSH_MS);
        return;
      }
      // Flush coalesced deltas before non-delta events to preserve order
      if (pendingDeltas) { if (flushTimer) { clearTimeout(flushTimer); flushTimer = null; } flush(); }
      mainWindow.webContents.send('ai:stream-chunk', chunk);
    });
    if (flushTimer) { clearTimeout(flushTimer); flushTimer = null; }
    flush();
    return { success: true, data: response };
  } catch (error) {
    console.error('Error in AI handler:', error);
    return { success: false, error: error.message };
  }
});

// -------------------------------------------------------------
// IPC Handlers: Code Mode & Workspaces Management (Dynamic)
// -------------------------------------------------------------

// --- Workspace safety helpers live in ./safety.js (unit-tested) ----------

// Git helpers for the agent (read ops + commit; never push).
function runGit(workspacePath, args) {
  return new Promise((resolve) => {
    execFile('git', args, { cwd: workspacePath, maxBuffer: 1024 * 1024 * 2, timeout: 30000 }, (err, stdout, stderr) => {
      resolve({
        success: !err,
        stdout: stdout || '',
        stderr: stderr || (err ? err.message : ''),
        exitCode: err ? (err.code || 1) : 0
      });
    });
  });
}

ipcMain.handle('workspace:git', async (_event, { workspacePath, action, args = {} }) => {
  try {
    if (action === 'status') {
      const st = await runGit(workspacePath, ['status', '--porcelain=v1', '-b']);
      const diffStat = await runGit(workspacePath, ['diff', '--stat', 'HEAD']);
      return { success: st.success, stdout: st.stdout + (diffStat.stdout ? '\n' + diffStat.stdout : ''), stderr: st.stderr };
    }
    if (action === 'diff') {
      return await runGit(workspacePath, args.staged ? ['diff', '--cached'] : ['diff']);
    }
    if (action === 'log') {
      return await runGit(workspacePath, ['log', '--oneline', `-n${Math.min(parseInt(args.limit, 10) || 10, 50)}`]);
    }
    if (action === 'commit') {
      if (!args.message || typeof args.message !== 'string') {
        return { success: false, stderr: 'commit requires a "message" parameter' };
      }
      const add = await runGit(workspacePath, ['add', '-A']);
      if (!add.success) return add;
      return await runGit(workspacePath, ['commit', '-m', args.message]);
    }
    return { success: false, stderr: `Unknown git action "${action}"` };
  } catch (error) {
    return { success: false, stderr: error.message };
  }
});

// --- Code-mode chat persistence (userData, one JSON per workspace) -------

function getCodeChatsDir() {
  return path.join(app.getPath('userData'), 'code-chats');
}

function codeChatFile(workspacePath) {
  const slug = workspacePath.replace(/[^a-zA-Z0-9._-]+/g, '__') + '.json';
  return path.join(getCodeChatsDir(), slug);
}

ipcMain.handle('code-chats:load', async () => {
  try {
    const dir = getCodeChatsDir();
    const list = [];
    if (!fsSync.existsSync(dir)) return { success: true, data: list };
    for (const f of await fs.readdir(dir)) {
      if (!f.endsWith('.json')) continue;
      try {
        const parsed = JSON.parse(await fs.readFile(path.join(dir, f), 'utf8'));
        if (parsed && parsed.workspacePath && Array.isArray(parsed.chats)) {
          list.push({ workspacePath: parsed.workspacePath, chats: parsed.chats });
        }
      } catch (_) {}
    }
    return { success: true, data: list };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('code-chats:save', async (_event, { workspacePath, chats }) => {
  try {
    const file = codeChatFile(workspacePath);
    await fs.mkdir(path.dirname(file), { recursive: true });
    await fs.writeFile(file, JSON.stringify({ workspacePath, chats }), 'utf8');
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

function getWorkspacesConfigFile() {
  try {
    return path.join(app.getPath('userData'), 'workspaces.json');
  } catch (e) {
    return path.join(__dirname, '../../.workspaces.json');
  }
}

let _wsCache = null;
let _wsCacheAt = 0;
const WS_CACHE_MS = 2000;
async function getSavedWorkspaces() {
  const now = Date.now();
  if (_wsCache && (now - _wsCacheAt) < WS_CACHE_MS) return _wsCache;
  const configFile = getWorkspacesConfigFile();
  try {
    if (fsSync.existsSync(configFile)) {
      const raw = await fs.readFile(configFile, 'utf8');
      const data = JSON.parse(raw);
      if (Array.isArray(data) && data.length > 0) {
        _wsCache = data.filter(w => fsSync.existsSync(w.path));
        _wsCacheAt = now;
        return _wsCache;
      }
    }
  } catch (e) {
    console.warn('Error reading workspaces config:', e);
  }

  // Seed default workspaces if not configured
  const seed = [];
  try {
    const parentDir = path.resolve(__dirname, '../../..');
    const entries = await fs.readdir(parentDir, { withFileTypes: true });
    for (const ent of entries) {
      if (ent.isDirectory() && !ent.name.startsWith('.')) {
        const fullPath = path.join(parentDir, ent.name);
        seed.push({
          name: ent.name,
          path: fullPath,
          hasGit: fsSync.existsSync(path.join(fullPath, '.git'))
        });
      }
    }
  } catch (e) {}

  if (seed.length === 0) {
    const desktopPath = path.resolve(__dirname, '../..');
    seed.push({
      name: path.basename(desktopPath),
      path: desktopPath,
      hasGit: fsSync.existsSync(path.join(desktopPath, '.git'))
    });
  }

  await saveWorkspaces(seed);
  _wsCache = seed;
  _wsCacheAt = Date.now();
  return seed;
}

async function saveWorkspaces(workspaces) {
  _wsCache = workspaces;
  _wsCacheAt = Date.now();
  const configFile = getWorkspacesConfigFile();
  try {
    await fs.mkdir(path.dirname(configFile), { recursive: true });
    await fs.writeFile(configFile, JSON.stringify(workspaces, null, 2), 'utf8');
  } catch (e) {
    console.warn('Error saving workspaces config:', e);
  }
}

// Desktop Remote Control (iOS Bridge)
ipcMain.handle('desktop:sync-workspaces', async (_event, workspaces) => {
  try {
    return await aiService.syncDesktopWorkspaces(workspaces);
  } catch (err) {
    return { success: false, error: err.message };
  }
});

ipcMain.handle('desktop:report-step', async (_event, stepPayload) => {
  try {
    return await aiService.reportDesktopStep(stepPayload);
  } catch (err) {
    return { success: false, error: err.message };
  }
});

ipcMain.handle('desktop:heartbeat', async (_event, activeWorkspace) => {
  try {
    return await aiService.desktopHeartbeat(activeWorkspace);
  } catch (err) {
    return { success: false, error: err.message };
  }
});

// List all workspace folders
ipcMain.handle('workspace:list', async () => {
  try {
    const workspaces = await getSavedWorkspaces();
    return { success: true, data: workspaces };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Add workspace folder
ipcMain.handle('workspace:add', async (event, folderPath) => {
  try {
    const workspaces = await getSavedWorkspaces();
    if (!workspaces.some(w => w.path === folderPath)) {
      workspaces.push({
        name: path.basename(folderPath),
        path: folderPath,
        hasGit: fsSync.existsSync(path.join(folderPath, '.git'))
      });
      await saveWorkspaces(workspaces);
    }
    return { success: true, data: workspaces };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Remove workspace folder
ipcMain.handle('workspace:remove', async (event, folderPath) => {
  try {
    let workspaces = await getSavedWorkspaces();
    workspaces = workspaces.filter(w => w.path !== folderPath);
    await saveWorkspaces(workspaces);
    return { success: true, data: workspaces };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Inspect workspace summary — mtime-guarded cache (skip re-read when nothing changed)
const _wsSummaryCache = new Map(); // workspacePath -> { mtimeMs, data }
ipcMain.handle('workspace:get-summary', async (event, workspacePath) => {
  try {
    if (!fsSync.existsSync(workspacePath)) {
      return { success: false, error: 'Directory does not exist' };
    }

    try {
      const st = fsSync.statSync(workspacePath);
      const cached = _wsSummaryCache.get(workspacePath);
      if (cached && cached.mtimeMs === st.mtimeMs) {
        return { success: true, data: cached.data };
      }
    } catch (_) {}

    const entries = await fs.readdir(workspacePath, { withFileTypes: true });
    const files = [];
    let readme = '';
    let packageInfo = null;
    let mainEntrypoint = null;
    let gitConfig = null;

    const ignorePatterns = new Set(['.git', 'node_modules', '.venv', 'venv', '__pycache__', '.DS_Store', 'dist', 'build', '.system_generated']);

    for (const ent of entries) {
      if (ignorePatterns.has(ent.name) || ent.name.startsWith('.')) continue;
      files.push({
        name: ent.name,
        isDirectory: ent.isDirectory()
      });

      // 1. Readme
      if (ent.name.toLowerCase() === 'readme.md' && !ent.isDirectory()) {
        try {
          const content = await fs.readFile(path.join(workspacePath, ent.name), 'utf8');
          readme = content.slice(0, 2500);
        } catch (_) {}
      }

      // 2. Node / JS package.json
      if (ent.name === 'package.json' && !ent.isDirectory()) {
        try {
          const raw = await fs.readFile(path.join(workspacePath, ent.name), 'utf8');
          const parsed = JSON.parse(raw);
          packageInfo = {
            name: parsed.name,
            version: parsed.version,
            description: parsed.description,
            main: parsed.main,
            dependencies: Object.keys(parsed.dependencies || {}),
            devDependencies: Object.keys(parsed.devDependencies || {}),
            scripts: parsed.scripts || {}
          };
        } catch (_) {}
      }

      // 3. Python pyproject.toml / requirements.txt
      if ((ent.name === 'pyproject.toml' || ent.name === 'requirements.txt') && !ent.isDirectory() && !packageInfo) {
        try {
          const raw = await fs.readFile(path.join(workspacePath, ent.name), 'utf8');
          packageInfo = {
            type: ent.name,
            snippet: raw.slice(0, 1000)
          };
        } catch (_) {}
      }

      // 4. Rust Cargo.toml
      if (ent.name === 'Cargo.toml' && !ent.isDirectory() && !packageInfo) {
        try {
          const raw = await fs.readFile(path.join(workspacePath, ent.name), 'utf8');
          packageInfo = {
            type: 'Cargo.toml',
            snippet: raw.slice(0, 1000)
          };
        } catch (_) {}
      }
    }

    // Inspect primary entrypoint if found (e.g. index.js, main.js, app.py, src/index.ts)
    const candidates = ['index.js', 'src/main/main.js', 'src/index.js', 'src/App.tsx', 'main.py', 'app.py', 'src/main.rs'];
    for (const c of candidates) {
      const fullCand = path.join(workspacePath, c);
      if (fsSync.existsSync(fullCand)) {
        try {
          const content = await fs.readFile(fullCand, 'utf8');
          mainEntrypoint = {
            relativePath: c,
            content: content.slice(0, 2000),
            totalLines: content.split('\n').length
          };
          break;
        } catch (_) {}
      }
    }

    // Inspect project memory directory: .newton/ (plan.md & memory.md)
    let projectMemory = null;
    const newtonDir = path.join(workspacePath, '.newton');
    if (fsSync.existsSync(newtonDir)) {
      projectMemory = {};
      const planFile = path.join(newtonDir, 'plan.md');
      const memoryFile = path.join(newtonDir, 'memory.md');

      if (fsSync.existsSync(planFile)) {
        try {
          projectMemory.plan = (await fs.readFile(planFile, 'utf8')).slice(0, 3000);
        } catch (_) {}
      }
      if (fsSync.existsSync(memoryFile)) {
        try {
          projectMemory.knowledge = (await fs.readFile(memoryFile, 'utf8')).slice(0, 5000);
        } catch (_) {}
      }
    }

    const result = {
      path: workspacePath,
      name: path.basename(workspacePath),
      files,
      readme,
      packageInfo,
      mainEntrypoint,
      projectMemory
    };
    try {
      const st2 = fsSync.statSync(workspacePath);
      _wsSummaryCache.set(workspacePath, { mtimeMs: st2.mtimeMs, data: result });
    } catch (_) {
      _wsSummaryCache.set(workspacePath, { mtimeMs: 0, data: result });
    }
    return { success: true, data: result };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Get current git branch
ipcMain.handle('workspace:get-branch', async (event, workspacePath) => {
  return new Promise((resolve) => {
    exec('git branch --show-current', { cwd: workspacePath }, (err, stdout) => {
      if (err || !stdout.trim()) {
        resolve({ success: true, branch: 'main' });
      } else {
        resolve({ success: true, branch: stdout.trim() });
      }
    });
  });
});

// List files in workspace (supports maxDepth and recursive scanning)
ipcMain.handle('workspace:list-files', async (event, { workspacePath, subPath = '', maxDepth = 4, recursive = true }) => {
  try {
    const baseDir = resolveInsideWorkspace(workspacePath, subPath || '');
    const ignorePatterns = new Set(['.git', 'node_modules', '.venv', 'venv', '__pycache__', '.DS_Store', 'dist', 'build', '.system_generated', 'Pods', 'xcuserdata', 'DerivedData']);

    // Determine effective recursion: default true so models like Singularity Matrix explore deeper directories
    const effectiveRecursive = recursive !== false;
    const effectiveMaxDepth = Math.max(3, maxDepth || 3);

    async function scan(currentDir, currentDepth) {
      if (currentDepth > effectiveMaxDepth) return [];
      const entries = await fs.readdir(currentDir, { withFileTypes: true });
      const results = [];

      for (const ent of entries) {
        if (ignorePatterns.has(ent.name) || ent.name.startsWith('.')) continue;
        const full = path.join(currentDir, ent.name);
        const rel = path.relative(workspacePath, full);
        const isDir = ent.isDirectory();
        results.push({
          name: ent.name,
          isDirectory: isDir,
          relativePath: rel,
          depth: currentDepth
        });

        if (isDir && effectiveRecursive && currentDepth < effectiveMaxDepth) {
          try {
            const children = await scan(full, currentDepth + 1);
            results.push(...children);
          } catch (_) {}
        }
      }
      return results;
    }

    const files = await scan(baseDir, 1);
    files.sort((a, b) => (b.isDirectory ? 1 : 0) - (a.isDirectory ? 1 : 0) || a.relativePath.localeCompare(b.relativePath));
    return { success: true, data: files };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Read file (supports reading whole file or specific line ranges, line count & metadata)
ipcMain.handle('workspace:read-file', async (event, { workspacePath, relativePath, startLine = null, endLine = null }) => {
  try {
    const fullPath = resolveInsideWorkspace(workspacePath, relativePath);
    const stat = await fs.stat(fullPath);
    if (stat.isDirectory()) {
      return { success: false, error: `Path "${relativePath}" is a directory, not a file.` };
    }

    const content = await fs.readFile(fullPath, 'utf8');
    const lines = content.split('\n');
    const totalLines = lines.length;

    if (startLine != null || endLine != null) {
      const s = Math.max(1, startLine || 1);
      const e = Math.min(totalLines, endLine || totalLines);
      const slice = lines.slice(s - 1, e);
      const numberedContent = slice.map((line, idx) => `${s + idx}: ${line}`).join('\n');
      return {
        success: true,
        data: {
          content: slice.join('\n'),
          numberedContent,
          startLine: s,
          endLine: e,
          totalLines,
          sizeBytes: stat.size,
          isPartial: true
        }
      };
    }

    // Default safety boundary: if file exceeds 200 lines or 20KB, return first 200 lines with notice
    const MAX_UNPAGINATED_LINES = 200;
    if (totalLines > MAX_UNPAGINATED_LINES) {
      const slice = lines.slice(0, MAX_UNPAGINATED_LINES);
      const numberedContent = slice.map((line, idx) => `${1 + idx}: ${line}`).join('\n');
      const truncatedNotice = `\n\n[Notice: File truncated. Showing lines 1-${MAX_UNPAGINATED_LINES} of ${totalLines}. Use read_file with startLine: ${MAX_UNPAGINATED_LINES + 1} to inspect further.]`;
      return {
        success: true,
        data: {
          content: slice.join('\n') + truncatedNotice,
          numberedContent: numberedContent + truncatedNotice,
          startLine: 1,
          endLine: MAX_UNPAGINATED_LINES,
          totalLines,
          sizeBytes: stat.size,
          isPartial: true,
          truncated: true
        }
      };
    }

    return {
      success: true,
      data: {
        content,
        totalLines,
        sizeBytes: stat.size,
        isPartial: false
      }
    };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Write file — returns a line diff of the change for UI rendering
ipcMain.handle('workspace:write-file', async (event, { workspacePath, relativePath, content }) => {
  try {
    const fullPath = resolveInsideWorkspace(workspacePath, relativePath);
    let before = '';
    try { before = await fs.readFile(fullPath, 'utf8'); } catch (_) {}
    await fs.mkdir(path.dirname(fullPath), { recursive: true });
    await fs.writeFile(fullPath, content, 'utf8');
    return { success: true, diff: computeLineDiff(before, content), created: before === '' };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Surgical Edit File (replace unique exact block)
ipcMain.handle('workspace:edit-file', async (event, { workspacePath, relativePath, old_str, new_str }) => {
  try {
    if (!relativePath) return { success: false, error: 'relativePath is required' };
    if (old_str == null || new_str == null) return { success: false, error: 'Both old_str and new_str are required' };

    const fullPath = resolveInsideWorkspace(workspacePath, relativePath);
    const content = await fs.readFile(fullPath, 'utf8');

    const occurrences = content.split(old_str).length - 1;
    if (occurrences === 0) {
      return { success: false, error: `old_str was not found in ${relativePath}. Check exact indentation and whitespace.` };
    }
    if (occurrences > 1) {
      return { success: false, error: `old_str matches ${occurrences} occurrences in ${relativePath}. Please include more surrounding context to make it unique.` };
    }

    const updated = content.replace(old_str, new_str);
    await fs.writeFile(fullPath, updated, 'utf8');
    return { success: true, message: `Successfully replaced 1 occurrence in ${relativePath}`, diff: computeLineDiff(content, updated) };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Grep search across workspace files — argv-based, no shell interpolation
ipcMain.handle('workspace:grep-search', async (event, { workspacePath, query, subPath = '' }) => {
  try {
    if (!query) return { success: false, error: 'query is required' };
    const targetDir = resolveInsideWorkspace(workspacePath, subPath || '');

    return new Promise((resolve) => {
      execFile('grep', [
        '-rnI', '-E',
        '--exclude-dir=.git', '--exclude-dir=node_modules', '--exclude-dir=.venv',
        '--exclude-dir=venv', '--exclude-dir=__pycache__', '--exclude-dir=dist', '--exclude-dir=build',
        query, '.'
      ], { cwd: targetDir, maxBuffer: 1024 * 1024 * 2, timeout: 20000 }, (err, stdout) => {
        if (err && !stdout) {
          resolve({ success: true, matches: [], count: 0 });
          return;
        }
        const lines = (stdout || '').trim().split('\n').filter(Boolean).slice(0, 40);
        const matches = lines.map(line => {
          const parts = line.split(':');
          const file = parts[0];
          const lineNum = parseInt(parts[1], 10) || 0;
          const snippet = parts.slice(2).join(':').trim();
          return { file, line: lineNum, snippet };
        });
        resolve({ success: true, count: matches.length, matches });
      });
    });
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Create file
ipcMain.handle('workspace:create-file', async (event, { workspacePath, relativePath, content = '' }) => {
  try {
    const fullPath = resolveInsideWorkspace(workspacePath, relativePath);
    await fs.mkdir(path.dirname(fullPath), { recursive: true });
    await fs.writeFile(fullPath, content, 'utf8');
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Delete file
ipcMain.handle('workspace:delete-file', async (event, { workspacePath, relativePath }) => {
  try {
    const fullPath = resolveInsideWorkspace(workspacePath, relativePath);
    if (fullPath === path.resolve(workspacePath)) {
      return { success: false, error: 'Refusing to delete the workspace root.' };
    }
    const stat = await fs.stat(fullPath);
    if (stat.isDirectory()) {
      await fs.rm(fullPath, { recursive: true, force: true });
    } else {
      await fs.unlink(fullPath);
    }
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Execute bash command in workspace (protected with 45-second timeout)
ipcMain.handle('workspace:exec-bash', async (event, { workspacePath, command, approved = false }) => {
  if (isCommandDenied(command)) {
    return { success: false, stdout: '', stderr: `Command rejected by Newton safety policy: "${command}". This pattern (sudo, destructive rm, piped shell download, raw disk write) is never allowed.`, exitCode: 126 };
  }
  return new Promise((resolve) => {
    exec(command, { cwd: workspacePath, shell: '/bin/zsh', maxBuffer: 1024 * 1024 * 4, timeout: 45000 }, (err, stdout, stderr) => {
      resolve({
        success: !err,
        stdout: stdout || '',
        stderr: stderr || (err ? err.message : ''),
        exitCode: err ? (err.code || 1) : 0
      });
    });
  });
});

// Open native folder picker dialog
ipcMain.handle('workspace:choose-folder', async () => {
  if (!mainWindow) return { success: false };
  const res = await dialog.showOpenDialog(mainWindow, {
    properties: ['openDirectory', 'createDirectory']
  });
  if (res.canceled || !res.filePaths.length) {
    return { success: false, canceled: true };
  }
  const folderPath = res.filePaths[0];
  return {
    success: true,
    data: {
      name: path.basename(folderPath),
      path: folderPath
    }
  };
});

ipcMain.handle('app:get-info', () => {
  return {
    version: app.getVersion(),
    platform: process.platform,
    node: process.versions.node,
    electron: process.versions.electron
  };
});

// App Lifecycle
app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
