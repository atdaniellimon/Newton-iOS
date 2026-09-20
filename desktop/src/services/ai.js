const fs = require('fs');
const path = require('path');
const dns = require('dns');
const dotenv = require('dotenv');

try {
  if (typeof dns.setDefaultResultOrder === 'function') {
    dns.setDefaultResultOrder('ipv4first');
  }
} catch (_) {}

dotenv.config({ path: path.join(__dirname, '../../.env') });

class AIService {
  constructor() {
    this.baseUrl = process.env.NEWTON_API_URL || 'https://api.newton.daniellimon.uk';
    this.sessionFile = this._resolveSessionFile();
    this.apiKey = this._loadApiKey();
  }

  _resolveSessionFile() {
    const os = require('os');
    const homeNewton = path.join(os.homedir(), '.newton/session.json');

    try {
      const { app } = require('electron');
      if (app && typeof app.getPath === 'function') {
        const p = path.join(app.getPath('userData'), 'session.json');
        if (fs.existsSync(p)) return p;
      }
    } catch (e) {}

    const newtonAppSupport = path.join(os.homedir(), 'Library/Application Support/Newton/session.json');
    if (fs.existsSync(newtonAppSupport)) return newtonAppSupport;

    const desktopAppSupport = path.join(os.homedir(), 'Library/Application Support/newton-desktop/session.json');
    if (fs.existsSync(desktopAppSupport)) return desktopAppSupport;

    if (fs.existsSync(homeNewton)) return homeNewton;

    const localSession = path.join(__dirname, '../../.session.json');
    if (fs.existsSync(localSession)) return localSession;

    try {
      const { app } = require('electron');
      if (app && typeof app.getPath === 'function') {
        return path.join(app.getPath('userData'), 'session.json');
      }
    } catch (e) {}

    return homeNewton;
  }

  _loadApiKey() {
    const os = require('os');
    const candidatePaths = [
      this.sessionFile,
      path.join(os.homedir(), 'Library/Application Support/Newton/session.json'),
      path.join(os.homedir(), 'Library/Application Support/newton-desktop/session.json'),
      path.join(os.homedir(), '.newton/session.json'),
      path.join(__dirname, '../../.session.json')
    ];

    try {
      const { app } = require('electron');
      if (app && typeof app.getPath === 'function') {
        candidatePaths.unshift(path.join(app.getPath('userData'), 'session.json'));
      }
    } catch (e) {}

    for (const p of candidatePaths) {
      try {
        if (p && fs.existsSync(p)) {
          const raw = fs.readFileSync(p, 'utf8');
          const data = JSON.parse(raw);
          if (data && typeof data.apiKey === 'string' && data.apiKey.trim().length > 0) {
            return data.apiKey.trim();
          }
        }
      } catch (e) {}
    }

    return process.env.NEWTON_API_KEY || '';
  }

  _saveApiKey(key) {
    this.apiKey = key || '';
    const os = require('os');
    const targetPaths = new Set();
    if (this.sessionFile) targetPaths.add(this.sessionFile);
    targetPaths.add(path.join(os.homedir(), '.newton/session.json'));
    targetPaths.add(path.join(os.homedir(), 'Library/Application Support/newton-desktop/session.json'));
    targetPaths.add(path.join(os.homedir(), 'Library/Application Support/Newton/session.json'));

    try {
      const { app } = require('electron');
      if (app && typeof app.getPath === 'function') {
        targetPaths.add(path.join(app.getPath('userData'), 'session.json'));
      }
    } catch (e) {}

    const payload = JSON.stringify({ apiKey: key || null, updatedAt: Date.now() }, null, 2);
    for (const targetPath of targetPaths) {
      try {
        const dir = path.dirname(targetPath);
        if (!fs.existsSync(dir)) {
          fs.mkdirSync(dir, { recursive: true });
        }
        fs.writeFileSync(targetPath, payload, 'utf8');
      } catch (e) {
        // Continue saving to others
      }
    }
  }

  isAuthenticated() {
    return Boolean(this.apiKey && this.apiKey.trim().length > 0);
  }

  setApiKey(key) {
    this._saveApiKey(key);
    return { success: true, apiKey: this.apiKey };
  }

  _extractErrorMessage(data, status, defaultMsg) {
    if (!data) return defaultMsg || `HTTP ${status}`;
    if (data.error && typeof data.error === 'object') {
      const { code, message } = data.error;
      if (code === 'tier_upgrade_required') {
        return message || "El modelo 'Singularity-Matrix' requiere el plan Newton Pro o Matrix.";
      }
      if (code === 'daily_image_quota_exceeded') {
        return message || "Has alcanzado la cuota diaria de generación de imágenes. Se reinicia a las 00:00:00 UTC.";
      }
      if (code === 'no_credits') {
        return message || "Se han agotado los créditos mensuales de tokens. Actualiza tu plan o añade créditos.";
      }
      if (code === 'account_locked') {
        return message || "Cuenta bloqueada temporalmente por intentos fallidos. Intenta de nuevo en 15 minutos.";
      }
      return message ? `[${code || status}] ${message}` : (defaultMsg || `Error (${status})`);
    }
    if (typeof data.error === 'string') return data.error;
    if (data.detail && typeof data.detail === 'object') return data.detail.message || JSON.stringify(data.detail);
    return data.detail || data.message || defaultMsg || `HTTP ${status}`;
  }

  async login({ username, password }) {
    const url = `${this.baseUrl}/auth/login`;
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password })
    });

    const data = await res.json().catch(() => ({}));
    if (!res.ok || !data.ok) {
      const msg = this._extractErrorMessage(data, res.status, `HTTP ${res.status}: Credenciales inválidas`);
      throw new Error(msg);
    }

    if (data.api_key) {
      this._saveApiKey(data.api_key);
    }
    return data;
  }

  async register({ username, email, password, tier = 'base' }) {
    const url = `${this.baseUrl}/auth/register`;
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, email, password, tier })
    });

    const data = await res.json().catch(() => ({}));
    if (!res.ok || !data.ok) {
      const msg = this._extractErrorMessage(data, res.status, `HTTP ${res.status}: Error al registrar cuenta`);
      throw new Error(msg);
    }

    if (data.api_key) {
      this._saveApiKey(data.api_key);
    }
    return data;
  }

  async logout() {
    this.stopSyncStream();
    if (this.apiKey) {
      try {
        await fetch(`${this.baseUrl}/auth/logout`, {
          method: 'POST',
          headers: this.getHeaders()
        }).catch(() => {});
      } catch (e) {}
    }
    this._saveApiKey(null);
    return { ok: true, message: 'Logged out successfully' };
  }

  startSyncStream(onEvent, onError) {
    if (!this.isAuthenticated()) return null;
    this.stopSyncStream();

    const https = require('https');
    const http = require('http');
    const parsedUrl = new URL(`${this.baseUrl}/nwtn/sync/events`);
    const isHttps = parsedUrl.protocol === 'https:';
    const client = isHttps ? https : http;

    let isAborted = false;

    const connect = () => {
      if (isAborted || !this.isAuthenticated()) return;

      const options = {
        hostname: parsedUrl.hostname,
        port: parsedUrl.port || (isHttps ? 443 : 80),
        path: parsedUrl.pathname + (parsedUrl.search || ''),
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache'
        }
      };

      const req = client.request(options, (res) => {
        if (res.statusCode !== 200) {
          if (onError) onError(new Error(`Sync stream HTTP ${res.statusCode}`));
          setTimeout(() => { if (!isAborted) connect(); }, 8000);
          return;
        }

        let buffer = '';
        let currentEventType = null;
        res.on('data', (chunk) => {
          buffer += chunk.toString('utf8');
          const lines = buffer.split('\n');
          buffer = lines.pop();

          for (const line of lines) {
            const trimmed = line.trim();
            if (trimmed.startsWith('event:')) {
              currentEventType = trimmed.slice(6).trim();
            } else if (trimmed.startsWith('data:')) {
              const jsonStr = trimmed.slice(5).trim();
              if (jsonStr && jsonStr !== '[DONE]') {
                try {
                  const payload = JSON.parse(jsonStr);
                  // Normalizar evento para que contenga { event, data }
                  const ev = (currentEventType && !payload.event)
                    ? { event: currentEventType, data: payload }
                    : (payload.event ? payload : { event: currentEventType || 'sync', data: payload });
                  if (onEvent) onEvent(ev);
                } catch (e) {}
              }
              currentEventType = null;
            }
          }
        });

        res.on('end', () => {
          setTimeout(() => { if (!isAborted) connect(); }, 3000);
        });

        res.on('error', (err) => {
          if (onError) onError(err);
          setTimeout(() => { if (!isAborted) connect(); }, 5000);
        });
      });

      req.on('error', (err) => {
        if (onError) onError(err);
        setTimeout(() => { if (!isAborted) connect(); }, 5000);
      });

      this._syncReq = req;
      req.end();
    };

    connect();

    return () => {
      isAborted = true;
      this.stopSyncStream();
    };
  }

  stopSyncStream() {
    if (this._syncReq) {
      try { this._syncReq.destroy(); } catch (e) {}
      this._syncReq = null;
    }
  }

  startDesktopRemoteStream(onEvent, onError) {
    if (!this.isAuthenticated()) return null;
    this.stopDesktopRemoteStream();

    const https = require('https');
    const http = require('http');
    const parsedUrl = new URL(`${this.baseUrl}/nwtn/desktop/session/stream`);
    const isHttps = parsedUrl.protocol === 'https:';
    const client = isHttps ? https : http;

    let isAborted = false;

    const connect = () => {
      if (isAborted || !this.isAuthenticated()) return;

      const options = {
        hostname: parsedUrl.hostname,
        port: parsedUrl.port || (isHttps ? 443 : 80),
        path: parsedUrl.pathname + (parsedUrl.search || ''),
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache'
        }
      };

      const req = client.request(options, (res) => {
        if (res.statusCode !== 200) {
          if (onError) onError(new Error(`Desktop remote stream HTTP ${res.statusCode}`));
          setTimeout(() => { if (!isAborted) connect(); }, 8000);
          return;
        }

        let buffer = '';
        let currentEventType = null;
        res.on('data', (chunk) => {
          buffer += chunk.toString('utf8');
          const lines = buffer.split('\n');
          buffer = lines.pop();

          for (const line of lines) {
            const trimmed = line.trim();
            if (trimmed.startsWith('event:')) {
              currentEventType = trimmed.slice(6).trim();
            } else if (trimmed.startsWith('data:')) {
              const jsonStr = trimmed.slice(5).trim();
              if (jsonStr && jsonStr !== '[DONE]') {
                try {
                  const payload = JSON.parse(jsonStr);
                  const ev = (currentEventType && !payload.event)
                    ? { event: currentEventType, data: payload }
                    : (payload.event ? payload : { event: currentEventType || 'remote', data: payload });
                  if (onEvent) onEvent(ev);
                } catch (e) {}
              }
              currentEventType = null;
            }
          }
        });

        res.on('end', () => {
          setTimeout(() => { if (!isAborted) connect(); }, 3000);
        });

        res.on('error', (err) => {
          if (onError) onError(err);
          setTimeout(() => { if (!isAborted) connect(); }, 5000);
        });
      });

      req.on('error', (err) => {
        if (onError) onError(err);
        setTimeout(() => { if (!isAborted) connect(); }, 5000);
      });

      this._remoteReq = req;
      req.end();
    };

    connect();

    return () => {
      isAborted = true;
      this.stopDesktopRemoteStream();
    };
  }

  stopDesktopRemoteStream() {
    if (this._remoteReq) {
      try { this._remoteReq.destroy(); } catch (e) {}
      this._remoteReq = null;
    }
  }

  async syncDesktopWorkspaces(workspaces) {
    try {
      const res = await fetch(`${this.baseUrl}/nwtn/desktop/workspaces/sync`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({ workspaces })
      });
      return await res.json();
    } catch (err) {
      return { success: false, error: err.message };
    }
  }

  async reportDesktopStep(stepPayload) {
    try {
      const res = await fetch(`${this.baseUrl}/nwtn/desktop/step`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(stepPayload)
      });
      return await res.json();
    } catch (err) {
      return { success: false, error: err.message };
    }
  }

  getHeaders(extra = {}) {
    const headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Newton-Desktop/0.1.0',
      ...extra
    };
    if (this.apiKey) {
      headers['Authorization'] = `Bearer ${this.apiKey}`;
    }
    return headers;
  }

  getConfig() {
    return {
      url: this.baseUrl,
      apiKey: this.apiKey,
      maskedKey: this.apiKey ? `${this.apiKey.slice(0, 10)}••••••••${this.apiKey.slice(-6)}` : 'No configurada',
      isAuthenticated: this.isAuthenticated()
    };
  }

  async request(endpoint, options = {}) {
    const url = `${this.baseUrl}${endpoint}`;
    const res = await fetch(url, {
      ...options,
      headers: this.getHeaders(options.headers || {})
    });

    if (!res.ok) {
      const errBody = await res.json().catch(() => ({}));
      throw new Error(this._extractErrorMessage(errBody, res.status, `HTTP ${res.status}: ${res.statusText}`));
    }
    return await res.json();
  }

  async getMe() {
    return this.request('/auth/me');
  }

  async rotateApiKey() {
    const res = await this.request('/auth/rotate-key', { method: 'POST' });
    if (res.api_key) {
      this._saveApiKey(res.api_key);
    }
    return res;
  }

  async getModels() {
    return this.request('/nwtn/models');
  }

  async getChats(limit = 50, offset = 0) {
    return this.request(`/nwtn/chats?limit=${limit}&offset=${offset}`);
  }

  async createChat({ title = 'New chat', model = 'Singularity', system_prompt = null } = {}) {
    return this.request('/nwtn/chats', {
      method: 'POST',
      body: JSON.stringify({ title, model, system_prompt })
    });
  }

  async getChatMessages(chatId, limit = 50, before = null) {
    let url = `/nwtn/chats/${chatId}/messages?limit=${limit}`;
    if (before) url += `&before=${encodeURIComponent(before)}`;
    return this.request(url);
  }

  async updateChat(chatId, { title, is_pinned, model }) {
    return this.request(`/nwtn/chats/${chatId}`, {
      method: 'PATCH',
      body: JSON.stringify({ title, is_pinned, model })
    });
  }

  async deleteChat(chatId) {
    return this.request(`/nwtn/chats/${chatId}`, {
      method: 'DELETE'
    });
  }

  async generateImage({ prompt, n = 1, reference = null }) {
    return this.request('/nwtn/images', {
      method: 'POST',
      body: JSON.stringify({ prompt, n, reference })
    });
  }

  async sendMessage({ chatId, prompt, model = 'Singularity', history = [], system = null, isGhost = false }, onChunk = null) {
    const isCloudChat = chatId && !isGhost;
    const endpoint = isCloudChat
      ? `/nwtn/chats/${chatId}/messages?stream=true`
      : `/nwtn/chat?stream=true`;

    const bodyData = isCloudChat
      ? { prompt, model, ...(system ? { system } : {}) }
      : { prompt, model, history, ...(system ? { system } : {}), stream: true };

    const res = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify(bodyData)
    });

    if (!res.ok) {
      const errJson = await res.json().catch(() => ({}));
      throw new Error(this._extractErrorMessage(errJson, res.status, `HTTP ${res.status}`));
    }

    // Capture response headers for billing & image quotas
    const creditsLeftHdr = res.headers.get('x-credits-left');
    const imagesUsedHdr = res.headers.get('x-daily-images-used');
    const imagesLimitHdr = res.headers.get('x-daily-images-limit');

    if (onChunk && (creditsLeftHdr || imagesUsedHdr || imagesLimitHdr)) {
      onChunk({
        type: 'headers:quotas',
        creditsLeft: creditsLeftHdr ? parseInt(creditsLeftHdr, 10) : undefined,
        imagesUsed: imagesUsedHdr ? parseInt(imagesUsedHdr, 10) : undefined,
        imagesLimit: imagesLimitHdr || undefined
      });
    }

    let fullReply = '';
    let donePayload = null;

    const reader = res.body.getReader();
    const decoder = new TextDecoder('utf-8');
    let buffer = '';

    while (true) {
      const { value, done } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop();

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || !trimmed.startsWith('data:')) continue;

        const payloadStr = trimmed.slice(5).trim();
        if (payloadStr === '[DONE]') {
          break;
        }

        try {
          const data = JSON.parse(payloadStr);
          if (data.error) {
            const errMsg = typeof data.error === 'object' ? (data.error.message || JSON.stringify(data.error)) : data.error;
            if (onChunk) onChunk({ type: 'error', error: errMsg });
            throw new Error(errMsg);
          }
          if (data.type && data.type.startsWith('orbit:')) {
            if (onChunk) onChunk({ type: data.type, tool: data.tool, data });
          }
          if (data.delta) {
            fullReply += data.delta;
            if (onChunk) onChunk({ type: 'delta', text: data.delta, full: fullReply });
          }
          if (data.done) {
            donePayload = data;
            if (data.reply) fullReply = data.reply;
          }
        } catch (e) {
          if (e.message && e.message.includes('error')) throw e;
          // Ignore partial json parse errors
        }
      }
    }

    if (onChunk) {
      onChunk({ type: 'done', text: fullReply, meta: donePayload });
    }

    return {
      reply: fullReply,
      meta: donePayload
    };
  }
}

module.exports = new AIService();
