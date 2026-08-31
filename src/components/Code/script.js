// src/components/Code/script.js
// Newton Code - Editor interactivo con ejecución, gestión de archivos, preview HTML, C y Rust

const BACKEND_URL = 'http://localhost:5000';
const CODE_EDITOR_KEY = 'newton_code_content';
const CODE_LANG_KEY = 'newton_code_language';
const CODE_THEME_KEY = 'newton_code_theme';
const CODE_TABS_KEY = 'newton_code_tabs';

export default class CodeComponent {
    constructor() {
        this.editor = null;
        this.currentFile = null;
        this.files = [];
        this.isRunning = false;
        this.language = localStorage.getItem(CODE_LANG_KEY) || 'python';
        this.theme = localStorage.getItem(CODE_THEME_KEY) || 'light';
        this._initialized = false;
        this._cmLoaded = false;
        this.consoleVisible = false;
        this.previewVisible = false;
        this.notificationTimeout = null;
        this.openTabs = this.loadTabs();
        this.activeTab = null;
        this.autoSaveTimer = null;
        this.fontSize = 14;
        this.wordWrap = false;
        this.init();
    }

    // ========== INIT ==========

    async init() {
        if (this._initialized) return;
        this._initialized = true;

        await this.loadCodeMirror();
        this.setupEditor();
        await this.loadFiles();
        this.setupEventListeners();
        this.restoreContent();
        this.applyTheme();
        this.setupResizeHandle();
        this.renderTabs();
        this.updateUI();
        this.setupAutosave();

        console.log('🧑‍💻 Newton Code initialized');
        if (typeof Moke !== 'undefined') {
            Moke.emit('code_ready', { 
                language: this.language, 
                theme: this.theme,
                files: this.files.length 
            });
        }
    }

    refresh() {
        if (this.editor) {
            this.editor.refresh();
        }
    }

    destroy() {
        if (this.autoSaveTimer) {
            clearInterval(this.autoSaveTimer);
        }
        this.saveTabs();
        this.hidePreview();
        this.hideConsole();
    }

    // ========== LANGUAGE INFO ==========

    getLanguageInfo(lang) {
        const map = {
            python: { name: 'Python', mode: 'python', icon: 'terminal', ext: 'py', badge: 'python' },
            javascript: { name: 'JavaScript', mode: 'javascript', icon: 'doc', ext: 'js', badge: 'javascript' },
            html: { name: 'HTML', mode: 'htmlmixed', icon: 'globe', ext: 'html', badge: 'html' },
            css: { name: 'CSS', mode: 'css', icon: 'paint_palette', ext: 'css', badge: 'css' },
            json: { name: 'JSON', mode: 'javascript', icon: 'doc_text', ext: 'json', badge: 'json' },
            c: { name: 'C', mode: 'clike', icon: 'bolt', ext: 'c', badge: 'c' },
            rust: { name: 'Rust', mode: 'rust', icon: 'cpu', ext: 'rs', badge: 'rust' },
            text: { name: 'Text', mode: 'text', icon: 'text_quote', ext: 'txt', badge: '' }
        };
        return map[lang] || map.python;
    }

    // ========== CODE MIRROR LOADING ==========

    loadCodeMirror() {
        return new Promise((resolve) => {
            if (window.CodeMirror) {
                this._cmLoaded = true;
                resolve();
                return;
            }

            const link = document.createElement('link');
            link.rel = 'stylesheet';
            link.href = 'https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.css';
            document.head.appendChild(link);

            const script = document.createElement('script');
            script.src = 'https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.js';
            script.onload = () => {
                // Load required addons first (simple.js is needed for Rust)
                const addons = [
                    'https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/addon/mode/simple.min.js',
                    'https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/addon/edit/closebrackets.min.js',
                    'https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/addon/edit/matchbrackets.min.js',
                    'https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/addon/comment/comment.min.js',
                    'https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/addon/fold/foldcode.min.js',
                    'https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/addon/fold/foldgutter.min.js',
                    'https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/addon/fold/brace-fold.min.js'
                ];

                let addonsLoaded = 0;
                addons.forEach(src => {
                    const s = document.createElement('script');
                    s.src = src;
                    s.onload = s.onerror = () => {
                        addonsLoaded++;
                        if (addonsLoaded === addons.length) {
                            this._loadModes().then(() => {
                                this._cmLoaded = true;
                                resolve();
                            });
                        }
                    };
                    document.head.appendChild(s);
                });
            };
            document.head.appendChild(script);
        });
    }

    _loadModes() {
        return new Promise((resolve) => {
            const modes = ['python', 'javascript', 'htmlmixed', 'css', 'xml', 'clike', 'rust'];
            let loaded = 0;
            modes.forEach(mode => {
                const s = document.createElement('script');
                s.src = `https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/${mode}/${mode}.min.js`;
                s.onload = s.onerror = () => {
                    loaded++;
                    if (loaded === modes.length) resolve();
                };
                document.head.appendChild(s);
            });
        });
    }

    // ========== EDITOR SETUP ==========

    setupEditor() {
        const textarea = document.getElementById('code-editor');
        if (!textarea) {
            console.warn('Code editor textarea not found');
            return;
        }

        this.editor = CodeMirror.fromTextArea(textarea, {
            lineNumbers: true,
            mode: this.language,
            theme: this.theme === 'dark' ? 'material' : 'default',
            indentUnit: 4,
            tabSize: 4,
            autoCloseBrackets: true,
            matchBrackets: true,
            foldGutter: true,
            gutters: ['CodeMirror-linenumbers', 'CodeMirror-foldgutter'],
            extraKeys: {
                "Ctrl-S": () => this.saveFile(),
                "Cmd-S": () => this.saveFile(),
                "Ctrl-Enter": () => this.runCode(),
                "Cmd-Enter": () => this.runCode(),
                "Ctrl-/": () => this.toggleComment(),
                "Cmd-/": () => this.toggleComment(),
                "Ctrl-`": () => this.toggleConsole(),
                "Cmd-`": () => this.toggleConsole(),
            }
        });

        this.editor.on('change', () => {
            localStorage.setItem(CODE_EDITOR_KEY, this.editor.getValue());
        });

        this.editor.on('cursorActivity', () => {
            const cursor = this.editor.getCursor();
            const lineColEl = document.getElementById('status-line-col');
            if (lineColEl) {
                lineColEl.textContent = `Ln ${cursor.line + 1}, Col ${cursor.ch + 1}`;
            }
        });

        this.editor.setSize(null, '100%');

        const resizeObserver = new ResizeObserver(() => {
            if (this.editor) this.editor.refresh();
        });
        const wrapper = document.querySelector('.code-editor-wrapper');
        if (wrapper) resizeObserver.observe(wrapper);
    }

    toggleComment() {
        const editor = this.editor;
        const from = editor.getCursor('start');
        const to = editor.getCursor('end');
        editor.toggleComment({ from, to });
    }

    // ========== THEME ==========

    applyTheme() {
        const container = document.querySelector('.code-container');
        const wrapper = document.querySelector('.code-editor-wrapper');
        if (!container || !wrapper) return;

        if (this.theme === 'dark') {
            container.classList.add('dark-mode');
            wrapper.classList.add('dark');
            this.editor.setOption('theme', 'material');
        } else {
            container.classList.remove('dark-mode');
            wrapper.classList.remove('dark');
            this.editor.setOption('theme', 'default');
        }
        localStorage.setItem(CODE_THEME_KEY, this.theme);
        setTimeout(() => this.editor.refresh(), 100);
    }

    toggleTheme() {
        this.theme = this.theme === 'dark' ? 'light' : 'dark';
        this.applyTheme();
        this.showNotification(`Theme: ${this.theme}`, 'info');
    }

    // ========== CONTENT RESTORE ==========

    restoreContent() {
        const saved = localStorage.getItem(CODE_EDITOR_KEY);
        if (saved && saved.trim()) {
            this.editor.setValue(saved);
        } else {
            const defaults = {
                python: '# Write your Python code here\nprint("Hello, Newton!")\n\n# You can use any Python library\nimport math\nprint(math.sqrt(16))',
                javascript: '// Write your JavaScript code here\nconsole.log("Hello, Newton!");\n\n// You can use standard JS\nconst arr = [1,2,3];\narr.forEach(x => console.log(x));',
                html: '<!-- Write your HTML here -->\n<!DOCTYPE html>\n<html>\n<head>\n  <title>Newton Code</title>\n</head>\n<body>\n  <h1>Hello, Newton!</h1>\n</body>\n</html>',
                css: '/* Write your CSS here */\nbody {\n  background: #f0f0f0;\n  font-family: sans-serif;\n}\n\nh1 {\n  color: #333;\n}',
                json: '{\n  "name": "Newton Code",\n  "version": "1.0",\n  "features": ["editing", "execution", "file management"]\n}',
                c: '#include <stdio.h>\n\nint main() {\n    printf("Hello, Newton!\\n");\n    return 0;\n}',
                rust: 'fn main() {\n    println!("Hello, Newton!");\n}'
            };
            this.editor.setValue(defaults[this.language] || defaults.python);
        }
        this.setLanguage(this.language);
    }

    setLanguage(lang) {
        this.language = lang;
        const modeMap = {
            python: 'python',
            javascript: 'javascript',
            html: 'htmlmixed',
            css: 'css',
            json: 'javascript',
            c: 'clike',
            rust: 'rust',
            text: 'text'
        };
        this.editor.setOption('mode', modeMap[lang] || 'python');
        localStorage.setItem(CODE_LANG_KEY, lang);
        const select = document.getElementById('code-language');
        if (select) select.value = lang;
        this.updateUI();
    }

    // ========== UI UPDATE ==========

    updateUI() {
        const badge = document.getElementById('code-lang-badge');
        const previewBtn = document.getElementById('code-preview-btn');
        const statusText = document.getElementById('code-status-text');
        const statusDot = document.querySelector('.status-dot');
        
        if (badge) {
            const info = this.getLanguageInfo(this.language);
            badge.textContent = info.name;
            badge.className = `code-lang-badge ${info.badge}`;
        }
        
        if (previewBtn) {
            previewBtn.style.display = this.language === 'html' ? 'inline-flex' : 'none';
        }
        
        if (statusText) {
            statusText.textContent = this.isRunning ? 'Running...' : 'Ready';
        }

        const breadcrumbEl = document.getElementById('breadcrumb-file');
        if (breadcrumbEl) {
            breadcrumbEl.textContent = this.currentFile || 'script.py';
        }
        
        if (statusDot) {
            if (this.isRunning) {
                statusDot.className = 'status-dot running';
            } else {
                statusDot.className = 'status-dot';
            }
        }
    }

    // ========== FILE MANAGEMENT ==========

    async loadFiles() {
        if (!window.newtonCore) {
            console.warn('NewtonCore not ready');
            return;
        }
        const data = await window.newtonCore.listFiles();
        if (data && data.success) {
            this.files = data.files || [];
            this.renderFileList();
        } else {
            this.files = [];
            this.renderFileList();
        }
    }

    renderFileList() {
        const container = document.getElementById('code-file-list');
        if (!container) return;

        if (!this.files || this.files.length === 0) {
            container.innerHTML = '<div class="file-empty">📂 No files</div>';
            return;
        }

        container.innerHTML = this.files.map(f => `
            <div class="code-file-item ${this.currentFile === f.name ? 'active' : ''}" data-file="${f.name}">
                <span class="file-icon">${this.getFileIcon(f.name)}</span>
                <span class="file-name" title="${f.name}">${f.name}</span>
                <button class="file-delete" data-file="${f.name}" title="Delete">✕</button>
            </div>
        `).join('');

        container.querySelectorAll('.code-file-item').forEach(item => {
            item.addEventListener('click', (e) => {
                if (e.target.closest('.file-delete')) return;
                const filename = item.dataset.file;
                if (filename) this.openFile(filename);
            });
        });

        container.querySelectorAll('.file-delete').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                e.stopPropagation();
                const filename = btn.dataset.file;
                if (!filename) return;
                const confirmed = await Moke.confirm(`Delete "${filename}"?`, {
                    okText: 'Delete',
                    cancelText: 'Cancel'
                });
                if (confirmed) {
                    const result = await window.newtonCore.deleteFile(filename);
                    if (result.success) {
                        await this.loadFiles();
                        this.removeTab(filename);
                        if (this.currentFile === filename) {
                            this.currentFile = null;
                            this.editor.setValue('');
                            localStorage.removeItem(CODE_EDITOR_KEY);
                        }
                        this.showNotification(`Deleted: ${filename}`, 'info');
                    } else {
                        this.showNotification(`Failed to delete: ${result.error}`, 'error');
                    }
                }
            });
        });
    }

    getFileIcon(filename) {
        const ext = filename.split('.').pop().toLowerCase();
        const icons = {
            'py': '🐍',
            'js': '📜',
            'html': '🌐',
            'css': '🎨',
            'json': '📋',
            'txt': '📝',
            'md': '📝',
            'csv': '📊',
            'c': '⚡',
            'rs': '🦀',
            'png': '🖼️',
            'jpg': '🖼️',
            'jpeg': '🖼️',
            'gif': '🖼️',
            'svg': '🖼️',
            'xml': '📄',
            'yaml': '📄',
            'yml': '📄',
            'toml': '📄',
            'sh': '💻',
            'bash': '💻',
            'zsh': '💻',
            'gitignore': '📄',
        };
        return icons[ext] || '📄';
    }

    async openFile(filename) {
        if (!window.newtonCore) return;
        this.showNotification(`Opening: ${filename}...`, 'info');
        
        const result = await window.newtonCore.callOrbit('file_manager', {
            action: 'read',
            session_id: window.newtonCore.currentSessionId,
            filename: filename
        });

        if (result.success) {
            this.currentFile = filename;
            this.editor.setValue(result.data.content || '');
            localStorage.setItem(CODE_EDITOR_KEY, result.data.content || '');
            
            const ext = filename.split('.').pop().toLowerCase();
            const langMap = {
                py: 'python',
                js: 'javascript',
                html: 'htmlmixed',
                css: 'css',
                json: 'javascript',
                c: 'c',
                rs: 'rust',
                txt: 'text',
                md: 'text',
                xml: 'text',
                yaml: 'text',
                yml: 'text',
                sh: 'text'
            };
            this.setLanguage(langMap[ext] || 'python');
            
            this.addTab(filename);
            this.updateUI();
            this.hidePreview();
            
            document.querySelectorAll('.code-file-item').forEach(el => {
                el.classList.toggle('active', el.dataset.file === filename);
            });
            
            this.showNotification(`Opened: ${filename}`, 'success');
        } else {
            this.showNotification(`Failed to open: ${result.error}`, 'error');
        }
    }

    async saveFile() {
        if (!this.currentFile) {
            const name = await Moke.prompt('File name:', 'script.py');
            if (!name) return;
            this.currentFile = name;
        }
        
        const content = this.editor.getValue();
        const blob = new Blob([content], { type: 'text/plain' });
        const file = new File([blob], this.currentFile);
        
        this.showNotification(`Saving: ${this.currentFile}...`, 'info');
        
        const result = await window.newtonCore.uploadFile(file);
        if (result.success) {
            await this.loadFiles();
            this.addTab(this.currentFile);
            document.querySelectorAll('.code-file-item').forEach(el => {
                el.classList.toggle('active', el.dataset.file === this.currentFile);
            });
            this.showNotification(`Saved: ${this.currentFile}`, 'success');
        } else {
            this.showNotification(`Failed to save: ${result.error}`, 'error');
        }
    }

    async createNewFile() {
        const name = await Moke.prompt('New file name:', 'script.py');
        if (!name) return;
        
        const ext = name.split('.').pop().toLowerCase();
        const templates = {
            py: '# New Python file\n\ndef main():\n    print("Hello, Newton!")\n\nif __name__ == "__main__":\n    main()\n',
            js: '// New JavaScript file\n\nfunction main() {\n    console.log("Hello, Newton!");\n}\n\nmain();\n',
            html: '<!-- New HTML file -->\n<!DOCTYPE html>\n<html>\n<head>\n    <meta charset="UTF-8">\n    <meta name="viewport" content="width=device-width, initial-scale=1.0">\n    <title>New Page</title>\n</head>\n<body>\n    <h1>Hello, Newton!</h1>\n</body>\n</html>',
            css: '/* New CSS file */\n\nbody {\n    font-family: sans-serif;\n    background: #f5f5f7;\n    color: #1a1a2e;\n}\n',
            json: '{\n    "name": "New Project",\n    "version": "1.0.0",\n    "description": ""\n}\n',
            c: '#include <stdio.h>\n\nint main() {\n    printf("Hello, Newton!\\n");\n    return 0;\n}\n',
            rs: 'fn main() {\n    println!("Hello, Newton!");\n}\n',
            txt: 'New text file\n\nWrite your content here...\n'
        };
        const content = templates[ext] || '';
        
        this.editor.setValue(content);
        localStorage.setItem(CODE_EDITOR_KEY, content);
        this.currentFile = name;
        await this.saveFile();
        
        const langMap = {
            py: 'python',
            js: 'javascript',
            html: 'htmlmixed',
            css: 'css',
            json: 'javascript',
            c: 'c',
            rs: 'rust',
            txt: 'text'
        };
        this.setLanguage(langMap[ext] || 'python');
        this.showNotification(`Created: ${name}`, 'success');
    }

    // ========== TABS ==========

    loadTabs() {
        try {
            const raw = localStorage.getItem(CODE_TABS_KEY);
            return raw ? JSON.parse(raw) : [];
        } catch { return []; }
    }

    saveTabs() {
        localStorage.setItem(CODE_TABS_KEY, JSON.stringify(this.openTabs));
    }

    addTab(filename) {
        if (!this.openTabs.includes(filename)) {
            this.openTabs.push(filename);
            this.saveTabs();
            this.renderTabs();
        }
        this.setActiveTab(filename);
    }

    removeTab(filename) {
        this.openTabs = this.openTabs.filter(f => f !== filename);
        this.saveTabs();
        this.renderTabs();
        if (this.activeTab === filename) {
            this.activeTab = this.openTabs.length > 0 ? this.openTabs[this.openTabs.length - 1] : null;
            if (this.activeTab) {
                this.openFile(this.activeTab);
            } else {
                this.currentFile = null;
                this.editor.setValue('');
                localStorage.removeItem(CODE_EDITOR_KEY);
                this.updateUI();
            }
        }
    }

    setActiveTab(filename) {
        this.activeTab = filename;
        this.renderTabs();
    }

    renderTabs() {
        const container = document.querySelector('.code-tabs');
        if (!container) return;
        
        if (this.openTabs.length === 0) {
            container.innerHTML = '';
            return;
        }
        
        container.innerHTML = this.openTabs.map(f => `
            <div class="code-tab ${f === this.activeTab ? 'active' : ''}" data-file="${f}">
                <span class="tab-icon">${this.getFileIcon(f)}</span>
                <span class="tab-name">${f}</span>
                <button class="tab-close" data-file="${f}">✕</button>
            </div>
        `).join('');
        
        container.querySelectorAll('.code-tab').forEach(tab => {
            tab.addEventListener('click', (e) => {
                if (e.target.closest('.tab-close')) return;
                const filename = tab.dataset.file;
                if (filename) this.openFile(filename);
            });
        });
        
        container.querySelectorAll('.tab-close').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                const filename = btn.dataset.file;
                if (filename) this.removeTab(filename);
            });
        });
    }

    // ========== CODE EXECUTION ==========

    async runCode() {
        if (this.isRunning) return;
        const code = this.editor.getValue();
        const lang = this.language;
        const consoleEl = document.getElementById('console-content');
        const progressBar = document.getElementById('code-progress');
        
        if (!consoleEl) return;

        this.showConsole();
        consoleEl.innerHTML = '<i class="f7-icons">hourglass</i> Executing...';
        this.isRunning = true;
        document.getElementById('code-run').disabled = true;
        document.getElementById('code-stop').disabled = false;
        if (progressBar) progressBar.classList.add('running');

        try {
            if (lang === 'python') {
                if (!window.pyodide) {
                    consoleEl.innerHTML = '<i class="f7-icons">arrow_2_circlepath</i> Loading Pyodide Python (WebAssembly)...';
                    window.pyodide = await loadPyodide();
                }
                let outputBuffer = '';
                window.pyodide.setStdout({
                    batched: (str) => { outputBuffer += str + '\n'; }
                });
                window.pyodide.setStderr({
                    batched: (str) => { outputBuffer += '[Error] ' + str + '\n'; }
                });
                window.js_sync_input = (promptText) => {
                    const promptMsg = promptText || "🐍 Python input():";
                    const raw = window.prompt(promptMsg);
                    const val = raw !== null ? raw : "";
                    outputBuffer += `> input(): ${val}\n`;
                    return val;
                };

                const wrappedCode = `import builtins, js

def _clean_sync_input(prompt_msg=""):
    p_str = str(prompt_msg) if prompt_msg is not None else ""
    if p_str:
        print(p_str, end="", flush=True)
    return str(js.js_sync_input(p_str))

builtins.input = _clean_sync_input

${code}`;

                await window.pyodide.runPythonAsync(wrappedCode);
                consoleEl.innerHTML = `<pre>${this.escapeHtml(outputBuffer || '(execution finished cleanly)')}</pre>`;
                this.showNotification('Python executed via Pyodide Wasm', 'success');
            } else if (lang === 'javascript') {
                let outputBuffer = '';
                const mockConsole = {
                    log: (...args) => { outputBuffer += args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' ') + '\n'; },
                    error: (...args) => { outputBuffer += '[ERROR] ' + args.join(' ') + '\n'; },
                    warn: (...args) => { outputBuffer += '[WARN] ' + args.join(' ') + '\n'; }
                };
                const runner = new Function('console', code);
                runner(mockConsole);
                consoleEl.innerHTML = `<pre>${this.escapeHtml(outputBuffer || '(execution finished cleanly)')}</pre>`;
                this.showNotification('JavaScript executed', 'success');
            } else if (lang === 'html' || lang === 'htmlmixed') {
                this.showPreview();
                consoleEl.innerHTML = '<pre>Live preview updated in preview tab.</pre>';
            } else {
                // Fallback to backend execution
                const response = await fetch(`${BACKEND_URL}/api/execute`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ code, language: lang, timeout: 15 })
                });
                const result = await response.json();
                if (result.success) {
                    consoleEl.innerHTML = `<pre>${this.escapeHtml(result.output || '(no output)')}</pre>`;
                } else {
                    consoleEl.innerHTML = `<pre style="color: var(--danger);">Error: ${this.escapeHtml(result.error || 'Execution failed')}</pre>`;
                }
            }
        } catch (error) {
            consoleEl.innerHTML = `<pre style="color: var(--danger);">Execution Error: ${this.escapeHtml(error.message)}</pre>`;
            this.showNotification(`Error: ${error.message}`, 'error');
        } finally {
            this.isRunning = false;
            document.getElementById('code-run').disabled = false;
            document.getElementById('code-stop').disabled = true;
            if (progressBar) progressBar.classList.remove('running');
        }
    }

    stopExecution() {
        this.isRunning = false;
        document.getElementById('code-run').disabled = false;
        document.getElementById('code-stop').disabled = true;
        document.getElementById('console-content').innerHTML = 
            '<span style="color:#888;">⏹ Execution stopped by user.</span>';
        document.getElementById('code-progress')?.classList.remove('running');
        this.updateUI();
        this.showNotification('Execution stopped', 'info');
    }

    // ========== CONSOLE ==========

    showConsole() {
        const consoleEl = document.querySelector('.code-console');
        if (!consoleEl) return;
        consoleEl.classList.add('visible');
        this.consoleVisible = true;
    }

    hideConsole() {
        const consoleEl = document.querySelector('.code-console');
        if (!consoleEl) return;
        consoleEl.classList.remove('visible');
        this.consoleVisible = false;
    }

    toggleConsole() {
        if (this.consoleVisible) {
            this.hideConsole();
        } else {
            this.showConsole();
        }
    }

    clearConsole() {
        const consoleEl = document.getElementById('console-content');
        if (consoleEl) {
            consoleEl.innerHTML = '💡 Ready';
        }
    }

    setupResizeHandle() {
        const consoleEl = document.querySelector('.code-console');
        const handle = consoleEl?.querySelector('.console-resize-handle');
        if (!handle || !consoleEl) return;

        let startY, startHeight;

        const onMouseMove = (e) => {
            const deltaY = startY - e.clientY;
            const newHeight = Math.min(
                Math.max(startHeight + deltaY, 100),
                window.innerHeight * 0.6
            );
            consoleEl.style.height = newHeight + 'px';
        };

        const onMouseUp = () => {
            document.removeEventListener('mousemove', onMouseMove);
            document.removeEventListener('mouseup', onMouseUp);
        };

        handle.addEventListener('mousedown', (e) => {
            e.preventDefault();
            startY = e.clientY;
            startHeight = consoleEl.offsetHeight;
            document.addEventListener('mousemove', onMouseMove);
            document.addEventListener('mouseup', onMouseUp);
        });
    }

    // ========== HTML PREVIEW ==========

    showPreview() {
        const container = document.getElementById('code-preview-container');
        const frame = document.getElementById('code-preview-frame');
        const content = this.editor.getValue();
        
        if (!container || !frame) return;
        
        container.classList.add('visible');
        this.previewVisible = true;
        
        try {
            const doc = frame.contentDocument || frame.contentWindow?.document;
            if (doc) {
                doc.open();
                doc.write(content);
                doc.close();
            }
        } catch (e) {
            // Si hay error, mostrar mensaje
            this.showNotification('Error rendering preview', 'error');
        }
        
        this.showNotification('Preview opened', 'info');
    }

    hidePreview() {
        const container = document.getElementById('code-preview-container');
        if (container) {
            container.classList.remove('visible');
            this.previewVisible = false;
        }
    }

    togglePreview() {
        if (this.language === 'html' || this.language === 'htmlmixed') {
            if (this.previewVisible) {
                this.hidePreview();
            } else {
                this.showPreview();
            }
        } else {
            this.showNotification('Preview only available for HTML', 'info');
        }
    }

    refreshPreview() {
        if (this.previewVisible && (this.language === 'html' || this.language === 'htmlmixed')) {
            this.showPreview();
        }
    }

    openPreviewInNewTab() {
        const content = this.editor.getValue();
        const blob = new Blob([content], { type: 'text/html' });
        const url = URL.createObjectURL(blob);
        window.open(url, '_blank');
        setTimeout(() => URL.revokeObjectURL(url), 10000);
    }

    // ========== AUTOSAVE ==========

    setupAutosave() {
        if (this.autoSaveTimer) {
            clearInterval(this.autoSaveTimer);
        }
        this.autoSaveTimer = setInterval(() => {
            if (this.currentFile && this.editor) {
                const content = this.editor.getValue();
                const saved = localStorage.getItem(CODE_EDITOR_KEY);
                if (saved !== content) {
                    this._autosave();
                }
            }
        }, 10000);
    }

    async _autosave() {
        if (!this.currentFile) return;
        const content = this.editor.getValue();
        const blob = new Blob([content], { type: 'text/plain' });
        const file = new File([blob], this.currentFile);
        await window.newtonCore.uploadFile(file);
    }

    // ========== SIDEBAR TOGGLE ==========

    toggleSidebar() {
        const sidebar = document.querySelector('.code-sidebar');
        if (sidebar) {
            sidebar.classList.toggle('collapsed');
            setTimeout(() => this.editor.refresh(), 300);
        }
    }

    // ========== NOTIFICATIONS ==========

    showNotification(message, type = 'info') {
        let notification = document.querySelector('.code-notification');
        if (!notification) {
            notification = document.createElement('div');
            notification.className = 'code-notification';
            document.body.appendChild(notification);
        }

        clearTimeout(this.notificationTimeout);
        notification.textContent = message;
        notification.className = `code-notification ${type}`;
        notification.classList.add('show');

        this.notificationTimeout = setTimeout(() => {
            notification.classList.remove('show');
        }, 2500);
    }

    // ========== AI CODE ASSISTANT ==========

    async askAICodeAssistant() {
        const input = document.getElementById('code-ai-input');
        const prompt = input ? input.value.trim() : '';
        if (!prompt) return;

        if (!window.newtonCore) {
            this.showNotification('NewtonCore is not initialized', 'error');
            return;
        }

        const currentCode = this.editor ? this.editor.getValue() : '';
        const lang = this.language;

        this.showNotification('Newton AI is processing your request...', 'info');

        const aiPrompt = `You are Newton AI Code Assistant.
The user wants you to edit, refactor, optimize, or write code in ${lang}.

Current File Content:
\`\`\`${lang}
${currentCode}
\`\`\`

User Request: "${prompt}"

INSTRUCTIONS:
1. Provide the complete updated code inside a single code block marked with \`\`\`${lang} ... \`\`\`.
2. Briefly explain your changes or solution after the code block.`;

        try {
            const response = await window.newtonCore.generateResponse(aiPrompt);

            // Extract code block if present
            const codeBlockRegex = /```(?:\w+)?\n([\s\S]*?)```/;
            const match = response.match(codeBlockRegex);

            if (match && match[1] && this.editor) {
                this.editor.setValue(match[1].trim());
                this.showNotification('Code updated by Newton AI!', 'success');
            } else {
                this.showNotification('AI response received', 'info');
            }

            this.showConsole();
            const consoleEl = document.getElementById('console-content');
            if (consoleEl) {
                consoleEl.innerHTML = `<pre>🤖 <strong>Newton AI Response:</strong>\n\n${this.escapeHtml(response)}</pre>`;
            }

            if (input) input.value = '';
        } catch (err) {
            this.showNotification(`AI Error: ${err.message || 'Call failed'}`, 'error');
        }
    }

    // ========== EDITOR CONTROLS ==========

    copyCode() {
        if (!this.editor) return;
        const code = this.editor.getValue();
        navigator.clipboard.writeText(code).then(() => {
            this.showNotification('Code copied to clipboard!', 'success');
        }).catch(() => {
            this.showNotification('Failed to copy code', 'error');
        });
    }

    toggleWordWrap() {
        if (!this.editor) return;
        this.wordWrap = !this.wordWrap;
        this.editor.setOption('lineWrapping', this.wordWrap);
        this.showNotification(`Word Wrap: ${this.wordWrap ? 'ON' : 'OFF'}`, 'info');
    }

    changeFontSize(delta) {
        if (!this.editor) return;
        this.fontSize = Math.min(Math.max(this.fontSize + delta, 10), 24);
        const cmEl = document.querySelector('.code-editor-wrapper .CodeMirror');
        if (cmEl) {
            cmEl.style.fontSize = `${this.fontSize}px`;
            this.editor.refresh();
        }
        this.showNotification(`Font size: ${this.fontSize}px`, 'info');
    }

    // ========== UTILITIES ==========

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // ========== EVENT LISTENERS ==========

    setupEventListeners() {
        // Language selector
        const langSelect = document.getElementById('code-language');
        if (langSelect) {
            langSelect.addEventListener('change', (e) => {
                this.setLanguage(e.target.value);
                if (e.target.value !== 'html' && e.target.value !== 'htmlmixed') {
                    this.hidePreview();
                }
            });
        }

        // Run button
        document.getElementById('code-run')?.addEventListener('click', () => this.runCode());

        // Stop button
        document.getElementById('code-stop')?.addEventListener('click', () => this.stopExecution());

        // Save button
        document.getElementById('code-save')?.addEventListener('click', () => this.saveFile());

        // New file button
        document.getElementById('code-new-file')?.addEventListener('click', () => this.createNewFile());

        // Sidebar toggle
        document.querySelector('.toggle-sidebar')?.addEventListener('click', () => this.toggleSidebar());

        // Theme toggle
        document.querySelector('.code-theme-btn')?.addEventListener('click', () => this.toggleTheme());

        // Preview button
        document.getElementById('code-preview-btn')?.addEventListener('click', () => this.togglePreview());

        // AI Assistant
        document.getElementById('code-ai-submit')?.addEventListener('click', () => this.askAICodeAssistant());
        document.getElementById('code-ai-input')?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                this.askAICodeAssistant();
            }
        });

        // Editor utility buttons
        document.getElementById('code-copy-btn')?.addEventListener('click', () => this.copyCode());
        document.getElementById('code-wrap-btn')?.addEventListener('click', () => this.toggleWordWrap());
        document.getElementById('code-font-inc')?.addEventListener('click', () => this.changeFontSize(1));
        document.getElementById('code-font-dec')?.addEventListener('click', () => this.changeFontSize(-1));

        // Preview actions
        document.getElementById('preview-refresh')?.addEventListener('click', () => this.refreshPreview());
        document.getElementById('preview-open')?.addEventListener('click', () => this.openPreviewInNewTab());
        document.getElementById('preview-close')?.addEventListener('click', () => this.hidePreview());

        // Console actions
        document.querySelector('.console-clear')?.addEventListener('click', () => this.clearConsole());
        document.querySelector('.console-close')?.addEventListener('click', () => this.hideConsole());

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            const isCodePage = document.querySelector('[moke-page="/code"]')?.style.display !== 'none';
            if (!isCodePage) return;

            if ((e.ctrlKey || e.metaKey) && e.key === '`') {
                e.preventDefault();
                this.toggleConsole();
            }
            if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
                e.preventDefault();
                this.clearConsole();
            }
            if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
                e.preventDefault();
                this.createNewFile();
            }
            if ((e.ctrlKey || e.metaKey) && e.key === 'p') {
                if (this.language === 'html' || this.language === 'htmlmixed') {
                    e.preventDefault();
                    this.togglePreview();
                }
            }
        });

        // Navigate to /code
        window.addEventListener('Moke_PageLoaded', (e) => {
            if (e.detail === '/code') {
                setTimeout(() => {
                    this.refresh();
                    this.loadFiles();
                    this.renderTabs();
                    this.updateUI();
                }, 100);
            }
        });

        // File changes via NewtonCore
        if (window.newtonCore) {
            window.newtonCore.addFileListener(() => {
                this.loadFiles();
            });
        }

        // Cleanup on page unload
        window.addEventListener('beforeunload', () => {
            this.destroy();
        });
    }
}

// Inicializar cuando Moke esté listo
if (typeof Moke !== 'undefined') {
    Moke.on('load', () => {
        // El componente se creará desde Sidebar/script.js
    });
}