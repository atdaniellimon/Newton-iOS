// /src/components/Config/script.js
// Configuration controller for BYOK, Multi-Provider & Theme Management

if (typeof window.NewtonModels === 'undefined') {
    const script = document.createElement('script');
    script.src = '/src/components/Models/script.js';
    document.head.appendChild(script);
}

let configInitialized = false;

function initConfigPage() {
    const providerSelect = document.getElementById('config-provider-select');
    const apiKeyInput = document.getElementById('config-api-key');
    const toggleKeyBtn = document.getElementById('toggle-key-visibility');
    const baseUrlInput = document.getElementById('config-base-url');
    const baseUrlGroup = document.getElementById('base-url-group');
    const baseUrlHint = document.getElementById('base-url-hint');
    
    const badge = document.getElementById('api-status-badge');
    const modelDisplay = document.getElementById('current-model');
    const tempSlider = document.getElementById('config-temperature');
    const tempLabel = document.getElementById('temp-value');
    const tokensSlider = document.getElementById('config-max-tokens');
    const tokensLabel = document.getElementById('maxtokens-value');
    const systemPromptInput = document.getElementById('config-system-prompt');
    const statusEl = document.getElementById('config-status');
    const saveBtn = document.getElementById('save-config');
    const testBtn = document.getElementById('test-config');
    const changeModelBtn = document.getElementById('change-model-btn');
    const modelSelector = document.getElementById('model-selector');
    const modelSelect = document.getElementById('model-select');
    const modelCustomInput = document.getElementById('model-custom-input');
    const modelConfirm = document.getElementById('model-select-confirm');
    const modelCancel = document.getElementById('model-select-cancel');
    const resetPromptBtn = document.getElementById('reset-prompt-btn');

    const themeDarkBtn = document.getElementById('theme-select-dark');
    const themeLightBtn = document.getElementById('theme-select-light');
    const themeToggleBtn = document.getElementById('theme-toggle-btn');

    if (!badge || !saveBtn || !testBtn || !modelDisplay) {
        setTimeout(initConfigPage, 100);
        return;
    }

    if (configInitialized) return;
    configInitialized = true;

    // Load initial values from NewtonCore / LocalStorage
    const core = window.newtonCore;

    function updateModelDisplay() {
        if (!modelDisplay || !core) return;
        const currentId = core.currentModel;
        const name = window.getModelName ? window.getModelName(currentId) : currentId;
        modelDisplay.textContent = name;
    }

    if (providerSelect && core) {
        providerSelect.value = core.currentProvider || 'openrouter';
        apiKeyInput.value = core.getApiKey(core.currentProvider) || '';
        baseUrlInput.value = core.baseUrl || 'http://localhost:11434/v1';

        function updateBaseUrlVisibility(provider) {
            if (!baseUrlGroup) return;
            const isCustomOrLocal = (provider === 'ollama' || provider === 'llamacpp' || provider === 'openai_compatible' || provider === 'anthropic_compatible');
            baseUrlGroup.style.display = isCustomOrLocal ? 'block' : 'none';
            if (isCustomOrLocal && baseUrlInput) {
                if (provider === 'llamacpp') {
                    baseUrlInput.placeholder = 'http://localhost:8080/v1';
                    if (!baseUrlInput.value || baseUrlInput.value === 'http://localhost:11434/v1' || baseUrlInput.value === 'http://localhost:1234/v1') {
                        baseUrlInput.value = 'http://localhost:8080/v1';
                    }
                    if (baseUrlHint) baseUrlHint.textContent = 'Endpoint for llama.cpp llama-server instance';
                } else if (provider === 'openai_compatible') {
                    baseUrlInput.placeholder = 'http://localhost:1234/v1 or https://api.together.xyz/v1';
                    if (!baseUrlInput.value || baseUrlInput.value === 'http://localhost:11434/v1') {
                        baseUrlInput.value = 'http://localhost:1234/v1';
                    }
                    if (baseUrlHint) baseUrlHint.textContent = 'Base URL for LM Studio, vLLM, Ollama, Together AI, or OpenAI proxy';
                } else if (provider === 'anthropic_compatible') {
                    baseUrlInput.placeholder = 'https://api.anthropic.com/v1 (or custom proxy)';
                    if (!baseUrlInput.value || baseUrlInput.value === 'http://localhost:11434/v1' || baseUrlInput.value === 'http://localhost:1234/v1') {
                        baseUrlInput.value = 'https://api.anthropic.com/v1';
                    }
                    if (baseUrlHint) baseUrlHint.textContent = 'Base URL for Anthropic Messages API or proxy endpoint';
                } else {
                    baseUrlInput.placeholder = 'http://localhost:11434/v1';
                    if (!baseUrlInput.value) {
                        baseUrlInput.value = 'http://localhost:11434/v1';
                    }
                    if (baseUrlHint) baseUrlHint.textContent = 'Endpoint URL for Ollama local API';
                }
            }
        }

        updateBaseUrlVisibility(providerSelect.value);

        providerSelect.addEventListener('change', async () => {
            const provider = providerSelect.value;
            core.setProvider(provider);
            apiKeyInput.value = core.getApiKey(provider) || '';
            updateBaseUrlVisibility(provider);
            updateBadge();
            await populateModelSelector();
            if (modelSelect && modelSelect.value) {
                core.setModel(modelSelect.value);
                updateModelDisplay();
            }
        });
    }

    // Toggle API Key visibility
    if (toggleKeyBtn && apiKeyInput) {
        toggleKeyBtn.addEventListener('click', () => {
            const isPassword = apiKeyInput.type === 'password';
            apiKeyInput.type = isPassword ? 'text' : 'password';
            const icon = toggleKeyBtn.querySelector('i');
            if (icon) {
                icon.className = isPassword ? 'f7-icons:eye_slash' : 'f7-icons:eye';
            }
        });
    }

    // Theme selector handlers
    if (themeDarkBtn) {
        themeDarkBtn.addEventListener('click', () => {
            if (core) core.setTheme('dark');
        });
    }
    if (themeLightBtn) {
        themeLightBtn.addEventListener('click', () => {
            if (core) core.setTheme('light');
        });
    }
    if (themeToggleBtn) {
        themeToggleBtn.addEventListener('click', () => {
            if (core) core.toggleTheme();
        });
    }

    // Populate model selector dynamically with zero-latency synchronous initial render
    async function populateModelSelector() {
        if (!modelSelect || !core) return;
        
        const fallbackMap = {
            openrouter: [
                { id: 'anthropic/claude-3.5-sonnet', name: 'Anthropic: Claude 3.5 Sonnet' },
                { id: 'deepseek/deepseek-r1', name: 'DeepSeek: R1 (Reasoning)' },
                { id: 'openai/gpt-4o', name: 'OpenAI: GPT-4o' },
                { id: 'openai/gpt-4o-mini', name: 'OpenAI: GPT-4o Mini' },
                { id: 'meta-llama/llama-3.3-70b-instruct', name: 'Meta: Llama 3.3 70B' },
                { id: 'google/gemini-2.0-flash-exp:free', name: 'Google: Gemini 2.0 Flash (Free)' }
            ],
            openai: [
                { id: 'gpt-4o', name: 'GPT-4o' },
                { id: 'gpt-4o-mini', name: 'GPT-4o Mini' },
                { id: 'o3-mini', name: 'o3-mini' }
            ],
            anthropic: [
                { id: 'claude-3-7-sonnet-20250219', name: 'Claude 3.7 Sonnet' },
                { id: 'claude-3-5-sonnet-20241022', name: 'Claude 3.5 Sonnet' },
                { id: 'claude-3-5-haiku-20241022', name: 'Claude 3.5 Haiku' },
                { id: 'claude-3-opus-20240229', name: 'Claude 3 Opus' }
            ],
            openai_compatible: [
                { id: 'default', name: 'Default Server Model' },
                { id: 'gpt-4o', name: 'GPT-4o' },
                { id: 'gpt-4o-mini', name: 'GPT-4o Mini' },
                { id: 'llama-3.3-70b-instruct', name: 'Llama 3.3 70B Instruct' },
                { id: 'deepseek-r1', name: 'DeepSeek R1' },
                { id: 'qwen2.5-coder-32b-instruct', name: 'Qwen 2.5 Coder 32B' }
            ],
            anthropic_compatible: [
                { id: 'claude-3-7-sonnet-20250219', name: 'Claude 3.7 Sonnet' },
                { id: 'claude-3-5-sonnet-20241022', name: 'Claude 3.5 Sonnet' },
                { id: 'claude-3-5-haiku-20241022', name: 'Claude 3.5 Haiku' },
                { id: 'claude-3-opus-20240229', name: 'Claude 3 Opus' }
            ],
            gemini: [
                { id: 'gemini-1.5-flash', name: 'Gemini 1.5 Flash' },
                { id: 'gemini-1.5-pro', name: 'Gemini 1.5 Pro' }
            ],
            groq: [
                { id: 'llama-3.3-70b-versatile', name: 'Llama 3.3 70B' },
                { id: 'deepseek-r1-distill-llama-70b', name: 'DeepSeek R1 Distill 70B' }
            ],
            deepseek: [
                { id: 'deepseek-chat', name: 'DeepSeek-V3 (Chat)' },
                { id: 'deepseek-reasoner', name: 'DeepSeek-R1 (Reasoner)' }
            ],
            ollama: [
                { id: 'llama3', name: 'Llama 3 (Ollama)' },
                { id: 'mistral', name: 'Mistral 7B (Ollama)' },
                { id: 'deepseek-r1', name: 'DeepSeek R1 (Ollama)' }
            ],
            llamacpp: [
                { id: 'default', name: 'llama.cpp Server Model' },
                { id: 'llama-3-8b-instruct', name: 'Llama 3 8B (llama.cpp)' },
                { id: 'deepseek-r1-gguf', name: 'DeepSeek R1 GGUF' }
            ]
        };

        const provider = providerSelect ? providerSelect.value : core.currentProvider;
        const initialModels = fallbackMap[provider] || fallbackMap.openrouter;
        
        function renderOptions(list) {
            modelSelect.innerHTML = '';
            const activeModel = core.currentModel;
            for (const model of list) {
                const option = document.createElement('option');
                option.value = model.id;
                option.textContent = model.name || model.id;
                option.title = model.description || '';
                if (model.id === activeModel) option.selected = true;
                modelSelect.appendChild(option);
            }
            if (list.length > 0 && !modelSelect.value) {
                modelSelect.value = list[0].id;
            }
            if (modelCustomInput && activeModel) {
                modelCustomInput.value = activeModel;
            }
            updateModelDisplay();
        }

        // 1. Render immediately synchronously (zero latency for iOS Mobile Safari!)
        renderOptions(initialModels);

        // 2. Async update if dynamic models arrive
        try {
            const dynamicModels = await core.fetchProviderModels(provider);
            if (Array.isArray(dynamicModels) && dynamicModels.length > 0) {
                renderOptions(dynamicModels);
            }
        } catch (e) {}
    }

    function updateBadge() {
        if (!badge || !core) return;
        const configured = core.isConfigured();
        badge.innerHTML = configured 
            ? `<i class="f7-icons">checkmark_alt</i> Connected to ${core.currentProvider.toUpperCase()}`
            : `<i class="f7-icons">exclamationmark_triangle</i> ${core.currentProvider.toUpperCase()} - Config / Key Required`;
        badge.style.background = configured ? 'rgba(167, 192, 128, 0.25)' : 'rgba(230, 126, 128, 0.25)';
        badge.style.color = configured ? 'var(--success)' : 'var(--danger)';
    }

    function showStatus(msg, type) {
        if (!statusEl) return;
        statusEl.innerHTML = msg;
        statusEl.className = 'config-status ' + (type || '');
        statusEl.style.display = 'block';
        setTimeout(() => { statusEl.style.display = 'none'; }, 4000);
    }

    // Populate initial controls
    if (tempSlider && core) {
        tempSlider.value = core.temperature;
        tempLabel.textContent = core.temperature;
        tempSlider.oninput = () => { tempLabel.textContent = tempSlider.value; };
    }
    if (tokensSlider && core) {
        tokensSlider.value = core.maxTokens;
        tokensLabel.textContent = core.maxTokens;
        tokensSlider.oninput = () => { tokensLabel.textContent = tokensSlider.value; };
    }
    if (systemPromptInput && core) {
        systemPromptInput.value = core.customSystemPrompt || '';
    }

    updateBadge();
    updateModelDisplay();
    populateModelSelector();

    // Model Change Modal listeners
    if (changeModelBtn && modelSelector) {
        changeModelBtn.onclick = async () => {
            await populateModelSelector();
            if (modelCustomInput && core) {
                modelCustomInput.value = core.currentModel || '';
            }
            modelSelector.style.display = 'block';
        };
    }
    if (modelCancel && modelSelector) {
        modelCancel.onclick = () => { modelSelector.style.display = 'none'; };
    }
    if (modelConfirm && core) {
        modelConfirm.onclick = () => {
            const customVal = modelCustomInput ? modelCustomInput.value.trim() : '';
            const selected = customVal || (modelSelect ? modelSelect.value : '');
            if (selected) {
                core.setModel(selected);
                updateModelDisplay();
                showStatus(`<i class="f7-icons">checkmark_alt</i> Model set to ${selected}`, 'success');
            }
            modelSelector.style.display = 'none';
        };
    }

    // Save Settings
    if (saveBtn && core) {
        saveBtn.onclick = (e) => {
            if (e) e.preventDefault();
            performSaveConfig();
        };
    }

    // Test Connection
    if (testBtn && core) {
        testBtn.onclick = async (e) => {
            if (e) e.preventDefault();
            showStatus('<i class="f7-icons">hourglass</i> Testing connection...', 'info');
            try {
                const res = await core.generateResponse('Hello! Respond with one word "Connected".');
                showStatus(`<i class="f7-icons">checkmark_alt</i> Connection successful! Response received.`, 'success');
            } catch (err) {
                showStatus(`<i class="f7-icons">xmark_circle</i> Connection failed: ${err.message}`, 'danger');
            }
        };
    }

    // Reset prompt button
    if (resetPromptBtn && core) {
        resetPromptBtn.onclick = () => {
            if (systemPromptInput) systemPromptInput.value = '';
            core.setSystemPrompt('');
            showStatus('<i class="f7-icons">arrow_counterclockwise</i> System prompt reset', 'success');
        };
    }

    // Onboarding Wizard Listeners
    initOnboardingWizard();
}

function performSaveConfig() {
    const core = window.newtonCore;
    if (!core) return;

    const providerSelect = document.getElementById('config-provider-select');
    const apiKeyInput = document.getElementById('config-api-key');
    const baseUrlInput = document.getElementById('config-base-url');
    const tempSlider = document.getElementById('config-temperature');
    const tokensSlider = document.getElementById('config-max-tokens');
    const systemPromptInput = document.getElementById('config-system-prompt');
    const statusEl = document.getElementById('config-status');

    function showStatus(msg, type = 'info') {
        if (!statusEl) return;
        statusEl.className = `config-status ${type}`;
        statusEl.innerHTML = msg;
        statusEl.style.display = 'block';
        setTimeout(() => { statusEl.style.display = 'none'; }, 4000);
    }

    const provider = providerSelect ? providerSelect.value : core.currentProvider;
    core.setProvider(provider);
    if (apiKeyInput) core.setApiKey(provider, apiKeyInput.value.trim());
    if (baseUrlInput) {
        core.baseUrl = baseUrlInput.value.trim();
        localStorage.setItem('newton_base_url', core.baseUrl);
    }

    if (tempSlider) core.setTemperature(parseFloat(tempSlider.value));
    if (tokensSlider) core.setMaxTokens(parseInt(tokensSlider.value));
    if (systemPromptInput) core.setSystemPrompt(systemPromptInput.value.trim());

    if (core.updateStatusBadge) core.updateStatusBadge();
    if (typeof updateBadge === 'function') updateBadge();
    showStatus('<i class="f7-icons">checkmark_alt</i> Configuration saved successfully!', 'success');
}
window.performSaveConfig = performSaveConfig;

// Event delegation for Save button to guarantee iOS Mobile Safari touch compatibility
document.addEventListener('click', (e) => {
    const target = e.target.closest('#save-config');
    if (target) {
        e.preventDefault();
        performSaveConfig();
    }
});

let lastTouchTime = 0;
document.addEventListener('touchend', (e) => {
    const target = e.target.closest('#save-config');
    if (target) {
        const now = Date.now();
        if (now - lastTouchTime < 400) return; // Prevent double-trigger
        lastTouchTime = now;
        e.preventDefault();
        performSaveConfig();
    }
});

function initOnboardingWizard() {
    const modal = document.getElementById('onboarding-modal');
    const startBtn = document.getElementById('onboarding-start-btn');
    const skipBtn = document.getElementById('onboarding-skip-btn');
    const apiKeyInput = document.getElementById('onboarding-api-key');
    const providerOptions = document.querySelectorAll('.provider-option');

    let selectedProvider = 'openrouter';

    providerOptions.forEach(opt => {
        opt.addEventListener('click', () => {
            providerOptions.forEach(o => o.classList.remove('selected'));
            opt.classList.add('selected');
            selectedProvider = opt.dataset.provider;
        });
    });

    if (startBtn && window.newtonCore) {
        startBtn.onclick = () => {
            const key = apiKeyInput ? apiKeyInput.value.trim() : '';
            window.newtonCore.setProvider(selectedProvider);
            if (key) {
                window.newtonCore.setApiKey(selectedProvider, key);
            }
            localStorage.setItem('newton_onboarding_dismissed', 'true');
            if (modal) modal.classList.remove('active');
            window.newtonCore.updateStatusBadge();
        };
    }

    if (skipBtn) {
        skipBtn.onclick = () => {
            localStorage.setItem('newton_onboarding_dismissed', 'true');
            if (modal) modal.classList.remove('active');
        };
    }
}

document.addEventListener('DOMContentLoaded', initConfigPage);
if (document.readyState === 'complete' || document.readyState === 'interactive') {
    initConfigPage();
}