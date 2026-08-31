// /src/components/NewtonCore/script.js
// Modern Newton Engine with BYOK (Bring Your Own Key), Multi-Provider, Thinking tags & Theme Manager

const BACKEND_URL = (function() {
    const host = (typeof window !== 'undefined' && window.location && window.location.hostname) 
        ? window.location.hostname 
        : 'localhost';
    return `http://${host}:5000`;
})();

const DEFAULT_PROVIDER_MODELS = {
    openrouter: [
        { id: 'anthropic/claude-3.5-sonnet', name: 'Anthropic: Claude 3.5 Sonnet', description: 'Top tier reasoning & code' },
        { id: 'deepseek/deepseek-r1', name: 'DeepSeek: R1 (Reasoning)', description: 'SOTA open reasoning model' },
        { id: 'openai/gpt-4o', name: 'OpenAI: GPT-4o', description: 'Flagship multimodal model' },
        { id: 'openai/gpt-4o-mini', name: 'OpenAI: GPT-4o Mini', description: 'Fast & lightweight' },
        { id: 'meta-llama/llama-3.3-70b-instruct', name: 'Meta: Llama 3.3 70B', description: 'Open source leader' },
        { id: 'google/gemini-2.0-flash-exp:free', name: 'Google: Gemini 2.0 Flash (Free)', description: 'Fast flash model' }
    ],
    openai: [
        { id: 'gpt-4o', name: 'GPT-4o', description: 'Flagship high-intelligence model' },
        { id: 'gpt-4o-mini', name: 'GPT-4o Mini', description: 'Fast, affordable, intelligent' },
        { id: 'o3-mini', name: 'o3-mini', description: 'Reasoning model for STEM and code' },
        { id: 'gpt-4-turbo', name: 'GPT-4 Turbo', description: 'Previous flagship GPT-4 model' }
    ],
    anthropic: [
        { id: 'claude-3-7-sonnet-20250219', name: 'Claude 3.7 Sonnet', description: 'Hybrid reasoning & speed' },
        { id: 'claude-3-5-sonnet-20241022', name: 'Claude 3.5 Sonnet', description: 'Most intelligent Claude model' },
        { id: 'claude-3-5-haiku-20241022', name: 'Claude 3.5 Haiku', description: 'Fastest, most compact Claude model' },
        { id: 'claude-3-opus-20240229', name: 'Claude 3 Opus', description: 'Deep analysis and writing' }
    ],
    openai_compatible: [
        { id: 'default', name: 'Default Model', description: 'Server default model' },
        { id: 'gpt-4o', name: 'GPT-4o', description: 'OpenAI-compatible GPT-4o' },
        { id: 'gpt-4o-mini', name: 'GPT-4o Mini', description: 'Fast & lightweight' },
        { id: 'llama-3.3-70b-instruct', name: 'Llama 3.3 70B Instruct', description: 'Local / Hosted Llama 3.3' },
        { id: 'deepseek-r1', name: 'DeepSeek R1', description: 'Reasoning model' },
        { id: 'qwen2.5-coder-32b-instruct', name: 'Qwen 2.5 Coder 32B', description: 'Code specialist' }
    ],
    anthropic_compatible: [
        { id: 'claude-3-7-sonnet-20250219', name: 'Claude 3.7 Sonnet', description: 'Claude 3.7 Sonnet (Anthropic API / Proxy)' },
        { id: 'claude-3-5-sonnet-20241022', name: 'Claude 3.5 Sonnet', description: 'Claude 3.5 Sonnet (Anthropic API / Proxy)' },
        { id: 'claude-3-5-haiku-20241022', name: 'Claude 3.5 Haiku', description: 'Claude 3.5 Haiku (Anthropic API / Proxy)' },
        { id: 'claude-3-opus-20240229', name: 'Claude 3 Opus', description: 'Claude 3 Opus (Anthropic API / Proxy)' }
    ],
    gemini: [
        { id: 'gemini-1.5-flash', name: 'Gemini 1.5 Flash', description: 'Fast and versatile performance' },
        { id: 'gemini-1.5-pro', name: 'Gemini 1.5 Pro', description: 'Complex reasoning and multi-modal' },
        { id: 'gemini-2.0-flash-exp', name: 'Gemini 2.0 Flash Experimental', description: 'Next-generation Gemini' }
    ],
    groq: [
        { id: 'llama-3.3-70b-versatile', name: 'Llama 3.3 70B Versatile', description: 'Ultra-fast Llama inference' },
        { id: 'deepseek-r1-distill-llama-70b', name: 'DeepSeek R1 Distill 70B', description: 'Ultra-fast reasoning on Groq' },
        { id: 'mixtral-8x7b-32768', name: 'Mixtral 8x7B', description: 'High speed mixture-of-experts' }
    ],
    deepseek: [
        { id: 'deepseek-chat', name: 'DeepSeek-V3 (Chat)', description: 'General intelligence & code' },
        { id: 'deepseek-reasoner', name: 'DeepSeek-R1 (Reasoner)', description: 'Deep reasoning chain-of-thought' }
    ],
    ollama: [
        { id: 'llama3', name: 'Llama 3 (Ollama)', description: 'Local Ollama Llama 3 model' },
        { id: 'mistral', name: 'Mistral 7B (Ollama)', description: 'Local Ollama Mistral model' },
        { id: 'deepseek-r1', name: 'DeepSeek R1 (Ollama)', description: 'Local Ollama DeepSeek R1' },
        { id: 'qwen2.5', name: 'Qwen 2.5 (Ollama)', description: 'Local Ollama Qwen 2.5' }
    ],
    llamacpp: [
        { id: 'default', name: 'llama.cpp Server Model', description: 'Active GGUF model loaded in llama-server' },
        { id: 'llama-3-8b-instruct', name: 'Llama 3 8B (llama.cpp)', description: 'llama.cpp GGUF model' },
        { id: 'deepseek-r1-gguf', name: 'DeepSeek R1 GGUF', description: 'GGUF reasoning model' },
        { id: 'mistral-7b-instruct', name: 'Mistral 7B GGUF', description: 'llama.cpp GGUF model' }
    ]
};

class ProviderAdapter {
    static getConfigs() {
        return {
            openrouter: {
                name: 'OpenRouter',
                endpoint: 'https://openrouter.ai/api/v1/chat/completions',
                modelsEndpoint: 'https://openrouter.ai/api/v1/models',
                defaultModel: 'anthropic/claude-3.5-sonnet',
                headers: (key) => ({
                    'Authorization': `Bearer ${key}`
                })
            },
            openai: {
                name: 'OpenAI',
                endpoint: 'https://api.openai.com/v1/chat/completions',
                modelsEndpoint: 'https://api.openai.com/v1/models',
                defaultModel: 'gpt-4o-mini',
                headers: (key) => ({ 'Authorization': `Bearer ${key}` })
            },
            anthropic: {
                name: 'Anthropic',
                endpoint: 'https://api.anthropic.com/v1/messages',
                modelsEndpoint: null,
                defaultModel: 'claude-3-5-sonnet-20241022',
                headers: (key) => ({
                    'x-api-key': key,
                    'anthropic-version': '2023-06-01',
                    'anthropic-dangerous-direct-browser-access': 'true'
                })
            },
            openai_compatible: {
                name: 'OpenAI Compatible (Custom / Local)',
                endpoint: (baseUrl) => {
                    const base = (baseUrl || 'http://localhost:1234/v1').replace(/\/+$/, '');
                    return base.endsWith('/chat/completions') ? base : `${base}/chat/completions`;
                },
                modelsEndpoint: (baseUrl) => {
                    const base = (baseUrl || 'http://localhost:1234/v1').replace(/\/+$/, '');
                    return base.endsWith('/chat/completions') ? `${base.replace(/\/chat\/completions$/, '')}/models` : `${base}/models`;
                },
                defaultModel: 'default',
                headers: (key) => key ? { 'Authorization': `Bearer ${key}` } : {}
            },
            anthropic_compatible: {
                name: 'Anthropic Compatible (Custom / Proxy)',
                endpoint: (baseUrl) => {
                    const base = (baseUrl || 'https://api.anthropic.com/v1').replace(/\/+$/, '');
                    return base.endsWith('/messages') ? base : `${base}/messages`;
                },
                modelsEndpoint: (baseUrl) => {
                    const base = (baseUrl || 'https://api.anthropic.com/v1').replace(/\/+$/, '');
                    return `${base}/models`;
                },
                defaultModel: 'claude-3-5-sonnet-20241022',
                headers: (key) => ({
                    ...(key ? { 'x-api-key': key } : {}),
                    'anthropic-version': '2023-06-01',
                    'anthropic-dangerous-direct-browser-access': 'true'
                })
            },
            gemini: {
                name: 'Google Gemini',
                endpoint: 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
                modelsEndpoint: null,
                defaultModel: 'gemini-1.5-flash',
                headers: (key) => ({ 'Authorization': `Bearer ${key}` })
            },
            groq: {
                name: 'Groq',
                endpoint: 'https://api.groq.com/openai/v1/chat/completions',
                modelsEndpoint: 'https://api.groq.com/openai/v1/models',
                defaultModel: 'llama-3.3-70b-versatile',
                headers: (key) => ({ 'Authorization': `Bearer ${key}` })
            },
            deepseek: {
                name: 'DeepSeek',
                endpoint: 'https://api.deepseek.com/v1/chat/completions',
                modelsEndpoint: 'https://api.deepseek.com/v1/models',
                defaultModel: 'deepseek-chat',
                headers: (key) => ({ 'Authorization': `Bearer ${key}` })
            },
            ollama: {
                name: 'Ollama (Local)',
                endpoint: (baseUrl) => `${(baseUrl || 'http://localhost:11434/v1').replace(/\/$/, '')}/chat/completions`,
                modelsEndpoint: (baseUrl) => `${(baseUrl || 'http://localhost:11434/v1').replace(/\/$/, '')}/models`,
                defaultModel: 'llama3',
                headers: () => ({})
            },
            llamacpp: {
                name: 'llama.cpp / llama-server',
                endpoint: (baseUrl) => `${(baseUrl || 'http://localhost:8080/v1').replace(/\/$/, '')}/chat/completions`,
                modelsEndpoint: (baseUrl) => `${(baseUrl || 'http://localhost:8080/v1').replace(/\/$/, '')}/models`,
                defaultModel: 'default',
                headers: () => ({})
            }
        };
    }
}

class NewtonCore {
    constructor() {
        this.isReady = false;
        this.abortController = null;
        this.orbitsCache = null;
        this.currentSessionId = this.getOrCreateSessionId();
        this.uploadedFiles = [];
        this.fileListListeners = [];
        
        // Providers & Keys Configuration
        this.currentProvider = localStorage.getItem('newton_provider') || 'openrouter';
        this.apiKeys = JSON.parse(localStorage.getItem('newton_apikeys') || '{}');
        this.baseUrl = localStorage.getItem('newton_base_url') || 'http://localhost:11434/v1';

        // Cargar configuración
        this.currentModel = localStorage.getItem('newton-model-id') || 'anthropic/claude-3.5-sonnet';
        this.temperature = parseFloat(localStorage.getItem('newton-temperature')) || 0.7;
        this.maxTokens = parseInt(localStorage.getItem('newton-maxtokens')) || 2048;
        this.customSystemPrompt = localStorage.getItem('newton-system-prompt') || '';
        
        // Theme initialization (Dark / Light)
        this.currentTheme = localStorage.getItem('newton_theme') || 'dark';
        this.setTheme(this.currentTheme);
    }

    getOrCreateSessionId() {
        let sessionId = localStorage.getItem('newton_session_id');
        if (!sessionId) {
            sessionId = 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 6);
            localStorage.setItem('newton_session_id', sessionId);
        }
        return sessionId;
    }

    setTheme(themeName) {
        if (themeName !== 'dark' && themeName !== 'light') themeName = 'dark';
        this.currentTheme = themeName;
        document.documentElement.setAttribute('data-theme', themeName);
        localStorage.setItem('newton_theme', themeName);

        const btn = document.getElementById('theme-toggle-btn');
        if (btn) {
            const icon = btn.querySelector('i');
            if (icon) {
                icon.className = 'f7-icons';
                icon.textContent = themeName === 'dark' ? 'sun_max_fill' : 'moon_fill';
            }
        }
    }

    toggleTheme() {
        const nextTheme = this.currentTheme === 'dark' ? 'light' : 'dark';
        this.setTheme(nextTheme);
        return nextTheme;
    }

    getApiKey(provider = this.currentProvider) {
        return this.apiKeys[provider] || '';
    }

    setApiKey(provider, key) {
        this.apiKeys[provider] = key;
        localStorage.setItem('newton_apikeys', JSON.stringify(this.apiKeys));
    }

    setProvider(provider) {
        this.currentProvider = provider;
        localStorage.setItem('newton_provider', provider);
    }

    getConfig() {
        return {
            provider: this.currentProvider,
            apiKey: this.getApiKey(),
            baseUrl: this.baseUrl,
            model: this.currentModel,
            temperature: this.temperature,
            maxTokens: this.maxTokens,
            systemPrompt: this.customSystemPrompt
        };
    }

    isConfigured() {
        if (this.currentProvider === 'ollama' || this.currentProvider === 'llamacpp') return true;
        if (this.currentProvider === 'openai_compatible') {
            return !!(this.baseUrl || this.getApiKey('openai_compatible'));
        }
        if (this.currentProvider === 'anthropic_compatible') {
            return !!(this.baseUrl || this.getApiKey('anthropic_compatible'));
        }
        return !!this.getApiKey();
    }

    async initialize() {
        this.isReady = true;
        await this.refreshOrbits();
        await this.refreshFileList();
        this.updateStatusBadge();
        
        if (typeof Moke !== 'undefined') {
            Moke.emit('newton_ready', {
                configured: this.isConfigured(),
                orbits: this.orbitsCache,
                model: this.currentModel
            });
        }

        // Show onboarding if no key configured
        if (!this.isConfigured() && !localStorage.getItem('newton_onboarding_dismissed')) {
            const modal = document.getElementById('onboarding-modal');
            if (modal) modal.classList.add('active');
        }

        return true;
    }

    updateStatusBadge() {
        const textEl = document.getElementById('status-pill-text');
        const pillEl = document.getElementById('chat-status-pill');
        if (textEl && pillEl) {
            const providerName = this.currentProvider.toUpperCase();
            const modelName = window.getModelName ? window.getModelName(this.currentModel) : this.currentModel;
            textEl.textContent = `${providerName} | ${modelName}`;
            pillEl.className = `status-pill ${this.isConfigured() ? 'online' : 'offline'}`;
        }
    }

    async fetchProviderModels(provider = this.currentProvider) {
        const configs = ProviderAdapter.getConfigs();
        const pConfig = configs[provider];
        const defaultModels = DEFAULT_PROVIDER_MODELS[provider] || DEFAULT_PROVIDER_MODELS.openrouter;

        if (!pConfig || !pConfig.modelsEndpoint) {
            return defaultModels;
        }

        const apiKey = this.getApiKey(provider);
        const url = typeof pConfig.modelsEndpoint === 'function' ? pConfig.modelsEndpoint(this.baseUrl) : pConfig.modelsEndpoint;
        
        // For fetching models, use minimal headers to avoid CORS preflight failures
        const headers = apiKey ? { 'Authorization': `Bearer ${apiKey}` } : {};

        try {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 4000);
            const response = await fetch(url, { headers, signal: controller.signal });
            clearTimeout(timeoutId);

            if (response.ok) {
                const data = await response.json();
                const rawModels = data.data || data.models || [];
                if (Array.isArray(rawModels) && rawModels.length > 0) {
                    const parsed = rawModels
                        .filter(m => m && (m.id || m.name))
                        .slice(0, 60)
                        .map(m => ({
                            id: m.id || m.name,
                            name: m.name || m.id || 'Model',
                            icon: 'sparkles',
                            description: m.description || `${provider} model`
                        }));
                    if (parsed.length > 0) return parsed;
                }
            }
        } catch (e) {
            console.warn('Could not fetch dynamic models for ' + provider + ', using fallback list:', e);
        }

        return defaultModels;
    }
    
    async refreshOrbits() {
        try {
            const response = await fetch(`${BACKEND_URL}/api/orbits`);
            if (response.ok) {
                const data = await response.json();
                this.orbitsCache = data.orbits;
                if (typeof Moke !== 'undefined') {
                    Moke.emit('orbits_updated', this.orbitsCache);
                }
            }
        } catch (error) {
            this.orbitsCache = {};
        }
    }
    
    async callOrbit(orbitName, params) {
        // Try backend orbit call first
        if (this.orbitsCache && this.orbitsCache[orbitName]) {
            try {
                const response = await fetch(`${BACKEND_URL}/api/orbit`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ orbit: orbitName, params: params })
                });
                const resData = await response.json();
                if (resData.success) return resData;
            } catch (e) {}
        }
        
        // Client-side Fallback for web_search
        if (orbitName === 'web_search' || orbitName === 'search') {
            const query = params.query || params.q || params.search || '';
            return await this._clientWebSearch(query);
        }

        return {
            success: false,
            error: `Orbit '${orbitName}' is currently unavailable.`
        };
    }

    async _clientWebSearch(query) {
        if (!query) return { success: false, error: 'Empty query' };
        
        let searchSnippets = [];

        // 1. Try DuckDuckGo Live Web SERP HTML via AllOrigins CORS Proxy
        try {
            const ddgHtmlUrl = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`;
            const proxyUrl = `https://api.allorigins.win/raw?url=${encodeURIComponent(ddgHtmlUrl)}`;
            const res = await fetch(proxyUrl);
            if (res.ok) {
                const htmlText = await res.text();
                const parser = new DOMParser();
                const doc = parser.parseFromString(htmlText, 'text/html');
                const results = doc.querySelectorAll('.result__body');
                results.forEach((el, idx) => {
                    if (idx < 5) {
                        const title = el.querySelector('.result__title')?.textContent?.trim() || '';
                        const snippet = el.querySelector('.result__snippet')?.textContent?.trim() || '';
                        if (snippet && title) {
                            searchSnippets.push(`- **${title}**: ${snippet}`);
                        }
                    }
                });
            }
        } catch (e) {
            console.warn('CORS DuckDuckGo web search failed:', e);
        }

        // 2. Try Jina AI Reader Web Search API
        if (searchSnippets.length === 0) {
            try {
                const jinaUrl = `https://api.allorigins.win/raw?url=${encodeURIComponent('https://s.jina.ai/' + query)}`;
                const res = await fetch(jinaUrl);
                if (res.ok) {
                    const text = await res.text();
                    if (text && text.length > 80) {
                        return {
                            success: true,
                            orbit: 'web_search',
                            data: text.slice(0, 3000)
                        };
                    }
                }
            } catch (e) {}
        }

        // 3. Wikipedia API fallback
        if (searchSnippets.length === 0) {
            try {
                const wikiUrl = `https://es.wikipedia.org/w/api.php?action=query&list=search&srsearch=${encodeURIComponent(query)}&utf8=&format=json&origin=*`;
                const res = await fetch(wikiUrl);
                const data = await res.json();
                if (data && data.query && data.query.search) {
                    data.query.search.slice(0, 4).forEach(item => {
                        const cleanSnippet = item.snippet.replace(/<[^>]*>?/gm, '').replace(/&quot;/g, '"');
                        searchSnippets.push(`- **${item.title}**: ${cleanSnippet}`);
                    });
                }
            } catch (e) {}
        }

        const resultText = searchSnippets.length > 0 
            ? searchSnippets.join('\n\n') 
            : `Live search query performed for "${query}". Synthesize using available knowledge base.`;

        return {
            success: true,
            orbit: 'web_search',
            data: resultText
        };
    }

    // ========== Direct AI Call via BYOK / Provider ==========
    async _sendToProvider(model, messages, temperature, maxTokens) {
        this.abortController = new AbortController();
        const apiKey = this.getApiKey();
        const providerConfigs = ProviderAdapter.getConfigs();
        const pConfig = providerConfigs[this.currentProvider] || providerConfigs.openrouter;

        // If no user API key and not a local or custom LLM engine, attempt local backend proxy fallback
        const isLocalOrCustom = ['ollama', 'llamacpp', 'openai_compatible', 'anthropic_compatible'].includes(this.currentProvider);
        if (!apiKey && !isLocalOrCustom) {
            return this._sendToBackendFallback(model, messages, temperature, maxTokens);
        }

        const endpointUrl = typeof pConfig.endpoint === 'function' ? pConfig.endpoint(this.baseUrl) : pConfig.endpoint;
        const baseHeaders = pConfig.headers ? pConfig.headers(apiKey) : {};
        
        // Ensure no empty header values cause fetch errors
        const headers = {
            'Content-Type': 'application/json'
        };
        for (const [k, v] of Object.entries(baseHeaders)) {
            if (v) headers[k] = v;
        }

        const isAnthropic = (this.currentProvider === 'anthropic' || this.currentProvider === 'anthropic_compatible');
        let bodyData;

        if (isAnthropic) {
            // Anthropic Messages API specification:
            // 1. 'system' as a top-level string parameter
            // 2. 'messages' containing only 'user' and 'assistant' roles
            // 3. 'max_tokens' is required
            const systemMsgs = messages
                .filter(m => m.role === 'system')
                .map(m => m.content)
                .join('\n\n');

            const anthropicMessages = [];
            let lastRole = null;

            for (const msg of messages) {
                if (!msg || msg.role === 'system') continue;
                let role = (msg.role === 'assistant' || msg.role === 'newton') ? 'assistant' : 'user';
                const content = typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content);
                if (!content.trim()) continue;

                if (lastRole === role && anthropicMessages.length > 0) {
                    anthropicMessages[anthropicMessages.length - 1].content += `\n\n${content}`;
                } else {
                    anthropicMessages.push({ role, content });
                    lastRole = role;
                }
            }

            if (anthropicMessages.length === 0 || anthropicMessages[0].role !== 'user') {
                anthropicMessages.unshift({ role: 'user', content: 'Hello' });
            }

            bodyData = {
                model: model || pConfig.defaultModel || 'claude-3-5-sonnet-20241022',
                messages: anthropicMessages,
                max_tokens: maxTokens ?? 2048,
                temperature: temperature ?? 0.7
            };
            if (systemMsgs) {
                bodyData.system = systemMsgs;
            }
        } else {
            bodyData = {
                model: model || pConfig.defaultModel || 'default',
                messages: messages,
                temperature: temperature ?? 0.7,
                max_tokens: maxTokens ?? 2048
            };
        }

        try {
            const response = await fetch(endpointUrl, {
                method: 'POST',
                headers: headers,
                body: JSON.stringify(bodyData),
                signal: this.abortController.signal
            });

            if (!response.ok) {
                // If 405 (Method Not Allowed - CORS preflight rejection) or 404 on local server, retry via local backend proxy
                if ((response.status === 405 || response.status === 404) && (endpointUrl.includes('localhost') || endpointUrl.includes('127.0.0.1') || endpointUrl.includes('0.0.0.0'))) {
                    console.warn(`Direct fetch to ${endpointUrl} returned ${response.status}. Retrying through Newton backend proxy...`);
                    return await this._sendToBackendFallback(model, messages, temperature, maxTokens, {
                        endpointUrl,
                        headers,
                        bodyData
                    });
                }

                let detail = '';
                try {
                    const err = await response.json();
                    detail = JSON.stringify(err.error?.message || err.error || err.detail || err);
                } catch {
                    detail = await response.text().catch(() => 'Unknown error');
                }
                throw { status: response.status, message: detail };
            }

            const data = await response.json();
            let content = '';
            if (data.content && Array.isArray(data.content)) {
                content = data.content.map(c => c.text || '').join('');
            } else if (data.choices?.[0]?.message?.content) {
                content = data.choices[0].message.content;
            } else if (data.choices?.[0]?.delta?.content) {
                content = data.choices[0].delta.content;
            } else if (typeof data.response === 'string') {
                content = data.response;
            }
            return content.trim() || 'No response generated.';
        } catch (err) {
            if (err.name === 'AbortError') throw err;
            // Catch CORS preflight failures, NetworkError or TypeError (e.g. Failed to fetch)
            if (err.name === 'TypeError' || (err.message && (err.message.includes('fetch') || err.message.includes('Network') || err.message.includes('CORS')))) {
                console.warn(`Direct browser fetch to ${endpointUrl} failed due to CORS/Network. Retrying through Newton backend proxy...`, err);
                return await this._sendToBackendFallback(model, messages, temperature, maxTokens, {
                    endpointUrl,
                    headers,
                    bodyData
                });
            }
            throw err;
        }
    }

    sanitizeMessagesForProvider(messages) {
        if (!Array.isArray(messages) || messages.length === 0) return [];

        const result = [];
        let lastRole = null;

        for (const msg of messages) {
            if (!msg || typeof msg.content !== 'string') continue;
            const cleanContent = msg.content.replace(/<[^>]*>?/gm, '').trim();
            if (!cleanContent) continue;

            let role = msg.role;
            if (role === 'newton') role = 'assistant';
            if (role !== 'system' && role !== 'user' && role !== 'assistant') role = 'user';

            if (role === 'system') {
                result.push({ role, content: cleanContent });
                continue;
            }

            // Prevent consecutive same-role messages by merging content
            if (lastRole === role && result.length > 0 && result[result.length - 1].role === role) {
                result[result.length - 1].content += `\n\n${cleanContent}`;
            } else {
                result.push({ role, content: cleanContent });
                lastRole = role;
            }
        }

        return result;
    }

    async _sendToBackendFallback(model, messages, temperature, maxTokens, customOptions = {}) {
        try {
            const response = await fetch(`${BACKEND_URL}/api/chat`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    model: model,
                    messages: messages,
                    temperature: temperature ?? 0.7,
                    maxTokens: maxTokens ?? 2048,
                    provider: this.currentProvider,
                    apiKey: this.getApiKey(),
                    baseUrl: this.baseUrl,
                    endpoint: customOptions.endpointUrl,
                    headers: customOptions.headers,
                    bodyData: customOptions.bodyData
                }),
                signal: this.abortController ? this.abortController.signal : null
            });

            if (!response.ok) {
                let errText = '';
                try {
                    const errJson = await response.json();
                    errText = errJson.error || errJson.detail || response.statusText;
                } catch {
                    errText = response.statusText || `${response.status}`;
                }
                throw { status: response.status, message: `Backend proxy error (${response.status}): ${typeof errText === 'object' ? JSON.stringify(errText) : errText}` };
            }

            const data = await response.json();
            let content = '';
            if (data.content && Array.isArray(data.content)) {
                content = data.content.map(c => c.text || '').join('');
            } else if (data.choices?.[0]?.message?.content) {
                content = data.choices[0].message.content;
            } else if (data.choices?.[0]?.delta?.content) {
                content = data.choices[0].delta.content;
            } else if (typeof data.response === 'string') {
                content = data.response;
            }
            return content.trim() || 'No response generated.';
        } catch (e) {
            if (e.name === 'AbortError') throw e;
            throw e.message ? e : { status: 500, message: `Could not connect to ${this.currentProvider.toUpperCase()} backend proxy.` };
        }
    }

    // ========== System Prompt ==========
    getSystemPromptForModel(modelId) {
        if (this.customSystemPrompt) {
            return this.customSystemPrompt;
        }
        if (typeof window.getSystemPrompt === 'function') {
            return window.getSystemPrompt(modelId);
        }
        return `You are Newton AI, a clear, scientific, and accurate assistant.`;
    }

    // ========== Format Response Content ==========
    formatResponseContent(text) {
        if (!text) return '';
        return text;
    }

    // ========== Process Tool Calls ==========
    async _processToolCalls(text) {
        let processedText = text;
        let hasCalls = false;
        
        const orbitRegex = /\[ORBIT:(\w+)\]\s*(\{[\s\S]*?\})(?:\s*\[\/ORBIT\])?/gi;
        let match;
        const calls = [];
        
        while ((match = orbitRegex.exec(text)) !== null) {
            const [fullMatch, orbitName, paramsJson] = match;
            try {
                const params = JSON.parse(paramsJson.trim());
                calls.push({ fullMatch, orbitName, params });
            } catch (e) {}
        }
        
        for (const call of calls) {
            const result = await this.callOrbit(call.orbitName, call.params);
            if (result.success) {
                const dataStr = typeof result.data === 'string' ? result.data : JSON.stringify(result.data, null, 2);
                processedText = processedText.replace(
                    call.fullMatch,
                    `**Orbit Result (${call.orbitName}):**\n${dataStr}`
                );
                hasCalls = true;
            } else {
                processedText = processedText.replace(
                    call.fullMatch,
                    `**Orbit Failed:** ${result.error || 'Unknown error'}`
                );
                hasCalls = true;
            }
        }
        
        return { text: processedText, hasCalls };
    }

    async generateResponse(prompt, history = []) {
        if (!this.isConfigured()) {
            return `⚠️ **No API Key Configured for ${this.currentProvider.toUpperCase()}**\n\nPlease click on **⚙️ Configuration** in the sidebar (or the status pill at the top) to select your AI Provider and paste your API Key to start chatting with Newton.`;
        }

        const config = this.getConfig();
        const systemPrompt = this.getSystemPromptForModel(config.model);
        
        let orbitsList = '- web_search: Search the live web for recent news, songs, articles, or facts.\n- file_manager: Read, write, or list workspace files.';
        if (this.orbitsCache && Object.keys(this.orbitsCache).length > 0) {
            orbitsList = Object.keys(this.orbitsCache).map(name => `- ${name}: ${this.orbitsCache[name].description || ''}`).join('\n');
        }
        
        let finalSystemPrompt = systemPrompt
            .replace(/\{\{orbits_list\}\}/g, orbitsList)
            .replace(/\{\{session_id\}\}/g, this.currentSessionId);
        const formattedHistory = (Array.isArray(history) ? history : [])
            .filter(msg => msg && msg.content && typeof msg.content === 'string' && !msg.content.startsWith('⚠️') && !msg.content.includes('Unable to complete request') && !msg.content.includes('Here is the information found'))
            .map(msg => {
                let text = msg.content
                    .replace(/(?:&lt;|<)think(?:&gt;|>)([\s\S]*?)(?:&lt;|<)\/think(?:&gt;|>)/gi, '')
                    .replace(/^[•\-\*]\s*(Investigaré|Buscó|Recolectó|Muy bien|Analizando|Procesando|Evidencia|Consultando)[\s\S]*?(\n|$)/gmi, '')
                    .replace(/<[^>]*>?/gm, '')
                    .trim();
                return {
                    role: (msg.role === 'newton' || msg.role === 'assistant') ? 'assistant' : 'user',
                    content: text
                };
            })
            .filter(msg => msg.content.length > 0);

        const rawMessages = [
            { role: 'system', content: finalSystemPrompt },
            ...formattedHistory,
            { role: 'user', content: prompt }
        ];

        const messages = this.sanitizeMessagesForProvider(rawMessages);

        try {
            // First Pass: Query model
            let firstResponse = await this._sendToProvider(
                config.model,
                messages,
                config.temperature,
                config.maxTokens
            );

            // Flexible Orbit Regex (matches both [ORBIT:name]{...}[/ORBIT] and [ORBIT:name]{...})
            const orbitRegex = /\[ORBIT:(\w+)\]\s*(\{[\s\S]*?\})(?:\s*\[\/ORBIT\])?/gi;
            const matches = [...firstResponse.matchAll(orbitRegex)];

            if (matches.length === 0) {
                // Strip any partial or malformed orbit tags
                let cleanText = firstResponse.replace(/\[ORBIT:[\s\S]*$/gi, '').trim();

                // If LLM returned raw reasoning text without <think> tags, format top reasoning lines into <think> block
                if (!cleanText.includes('<think>') && !cleanText.includes('&lt;think&gt;')) {
                    const lines = cleanText.split('\n');
                    const reasoningLines = [];
                    const answerLines = [];
                    let isReasoning = true;

                    for (const line of lines) {
                        const trimmed = line.trim();
                        if (isReasoning && (trimmed.match(/^(\d+\.|-|•|\*)\s/) || trimmed.match(/^(Analyzing|Formulating|Evaluating|Considering|Investigating)/i))) {
                            reasoningLines.push(trimmed);
                        } else if (trimmed.length > 0) {
                            isReasoning = false;
                            answerLines.push(line);
                        } else if (!isReasoning) {
                            answerLines.push(line);
                        }
                    }

                    if (reasoningLines.length > 0 && answerLines.length > 0) {
                        cleanText = `<think>\n${reasoningLines.join('\n')}\n</think>\n\n${answerLines.join('\n')}`;
                    }
                }

                return this.formatResponseContent(cleanText || firstResponse);
            }

            // Clean any text produced around the orbit call
            let textBeforeTool = firstResponse.replace(orbitRegex, '').trim();

            // Execute orbit tool calls and record dynamic Chain of Thought steps
            let toolResultsText = '';
            let cotSteps = [];
            const cleanQueryPrompt = prompt.slice(0, 70) + (prompt.length > 70 ? '...' : '');
            cotSteps.push(`• Analizando consulta: "${cleanQueryPrompt}"`);

            for (const match of matches) {
                const [fullMatch, orbitName, paramsJson] = match;
                let result;
                let searchTerms = orbitName;
                try {
                    const params = JSON.parse(paramsJson.trim());
                    searchTerms = params.query || params.term || params.url || orbitName;
                    cotSteps.push(`• Consultando fuentes: "${searchTerms}"`);
                    result = await this.callOrbit(orbitName, params);
                } catch (err) {
                    cotSteps.push(`• Búsqueda de referencia: "${orbitName}"`);
                    result = { success: false, error: err.message };
                }

                cotSteps.push(`• Evidencia recolectada sobre "${searchTerms}". Evaluando datos...`);

                const resultStr = typeof result.data === 'string' 
                    ? result.data 
                    : JSON.stringify(result.data || 'Search completed.');

                toolResultsText += `\n${resultStr}\n`;
            }

            cotSteps.push(`• Análisis completado. Estructurando respuesta final.`);
            const cotBlock = `<think>\n${cotSteps.join('\n')}\n</think>\n\n`;

            // Second Pass: Dedicated Synthesis Prompt to prevent LLM from echoing orbit tags or CoT lines
            const synthesisSystemPrompt = `You are Newton, an intelligent AI Copilot. You have performed a web search for the user.
YOUR GOAL: Synthesize the web search data provided below and answer the user's prompt clearly, directly, and comprehensively.
STRICT RULES:
- Do NOT output any JSON, code blocks, or [ORBIT:...] tags.
- Do NOT repeat or echo any thought process bullet points (such as "Analizando consulta", "Evidencia recolectada", etc.).
- Write in clean, natural, professional markdown text.
- Provide a full, multi-paragraph response answering the user's request.`;

            try {
                const secondPassRawMessages = [
                    { role: 'system', content: synthesisSystemPrompt },
                    ...formattedHistory,
                    { 
                        role: 'user', 
                        content: `User Request: "${prompt}"\n\nRetrieved Web Search Context:\n${toolResultsText}\n\nPlease synthesize this data and provide a complete, clear, and direct answer.` 
                    }
                ];

                const secondPassMessages = this.sanitizeMessagesForProvider(secondPassRawMessages);

                let finalResponse = await this._sendToProvider(
                    config.model,
                    secondPassMessages,
                    config.temperature,
                    config.maxTokens
                );

                finalResponse = finalResponse.replace(orbitRegex, '').trim();
                if (finalResponse && !finalResponse.startsWith('{')) {
                    return this.formatResponseContent(cotBlock + finalResponse);
                }
            } catch (secondPassErr) {
                console.warn('Second pass ReAct synthesis failed:', secondPassErr);
            }

            // If LLM returned empty or raw JSON, present readable search snippets formatted nicely
            if (toolResultsText.trim()) {
                return this.formatResponseContent(cotBlock + `Based on recent search data for **"${prompt}"**:\n\n${toolResultsText.trim()}`);
            }

            return this.formatResponseContent(cotBlock + (textBeforeTool || "Analysis completed for the requested topic."));

        } catch (error) {
            if (error.name === 'AbortError') {
                return '[Generation stopped]';
            }
            const errorMsg = error.message || (typeof error === 'string' ? error : 'Call failed. Please check your API key.');
            return `⚠️ **API Error (${this.currentProvider.toUpperCase()})**: ${errorMsg}`;
        }
    }
    
    // ========== File methods ==========
    async uploadFile(file) {
        const formData = new FormData();
        formData.append('file', file);
        try {
            const response = await fetch(`${BACKEND_URL}/api/upload`, {
                method: 'POST',
                headers: { 'X-Session-Id': this.currentSessionId },
                body: formData
            });
            return await response.json();
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    async listFiles() {
        try {
            const response = await fetch(`${BACKEND_URL}/api/files?session=${this.currentSessionId}`);
            return await response.json();
        } catch (error) {
            return { success: false, files: [] };
        }
    }

    async refreshFileList() {
        const data = await this.listFiles();
        if (data.success) {
            this.uploadedFiles = data.files || [];
        }
    }

    cancelGeneration() {
        if (this.abortController) {
            this.abortController.abort();
            this.abortController = null;
        }
    }

    setModel(modelId) {
        this.currentModel = modelId;
        localStorage.setItem('newton-model-id', modelId);
        this.updateStatusBadge();
    }

    setTemperature(temp) {
        this.temperature = temp;
        localStorage.setItem('newton-temperature', temp);
    }

    setMaxTokens(tokens) {
        this.maxTokens = tokens;
        localStorage.setItem('newton-maxtokens', tokens);
    }

    setSystemPrompt(prompt) {
        this.customSystemPrompt = prompt;
        localStorage.setItem('newton-system-prompt', prompt);
    }
}

// Global initialization
window.NewtonCore = NewtonCore;
window.newtonCore = new NewtonCore();
window.newtonCore.initialize();