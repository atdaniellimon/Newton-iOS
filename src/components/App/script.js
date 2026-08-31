/*
    Newton's app logic - With OpenAI-compatible API, conversation persistence, and markdown rendering
*/

const _placeholders = [
    "Ask Newton.",
    "Expand your knowledge.",
    "Define a movement law.",
    "What's your hypothesis?",
    "State your inquiry.",
    "Challenge the laws of logic.",
    "Explore the frontiers of reason.",
    "Quantize your thoughts.",
    "Propose a theorem.",
    "Calculate your imagination."
];

const _code_placeholders = [
    "Break binary logic.",
    "Expand your stack",
    "Quantize your thoughts.",
    "Break the loop."
]

let hasSentFirstMessage = false;
var attachedFiles = [];
window.attachedFiles = attachedFiles;

function renderAttachmentPreviews() {
    const previewContainer = document.getElementById('input-attachments-preview');
    if (!previewContainer) return;

    if (!attachedFiles || attachedFiles.length === 0) {
        previewContainer.style.display = 'none';
        previewContainer.innerHTML = '';
        return;
    }

    previewContainer.style.display = 'flex';
    previewContainer.innerHTML = attachedFiles.map(file => {
        const icon = file.isImage ? 'photo' : 'doc_text';
        const sizeKb = (file.size / 1024).toFixed(1);
        return `
            <div class="attached-file-pill" data-file-id="${file.id}">
                <i class="f7-icons file-icon">${icon}</i>
                <span>${escapeHtml(file.name)} (${sizeKb} KB)</span>
                <button type="button" class="remove-file-btn" onclick="removeAttachedFile('${file.id}')" title="Remove file">
                    <i class="f7-icons">xmark</i>
                </button>
            </div>
        `;
    }).join('');

    if (typeof checkInputState === 'function') checkInputState();
}
window.renderAttachmentPreviews = renderAttachmentPreviews;

function removeAttachedFile(fileId) {
    attachedFiles = attachedFiles.filter(f => f.id.toString() !== fileId.toString());
    renderAttachmentPreviews();
}
window.removeAttachedFile = removeAttachedFile;

const noChatDiv = document.querySelector('.no-chat');
const noChatImg = noChatDiv?.querySelector('img');
const noChatH1 = noChatDiv?.querySelector('h1');

// ========== Simple Markdown Renderer ==========
function renderMarkdown(text) {
    if (!text) return '';

    let thinkBlockHtml = '';
    
    // 1. Extract <think> blocks into thinkBlockHtml so they are only rendered once at the top
    let cleanText = text.replace(/(?:&lt;|<)think(?:&gt;|>)([\s\S]*?)(?:&lt;|<)\/think(?:&gt;|>)/gi, (match, content) => {
        thinkBlockHtml += `<div class="think-block collapsed">
            <div class="think-header" onclick="this.parentElement.classList.toggle('collapsed')">
                <span style="display:inline-flex; align-items:center;">
                    <span class="think-orb-inline-container" data-orb-state="orbits"></span>
                    <span>Thought process</span>
                </span>
                <i class="f7-icons arrow-icon">chevron_down</i>
            </div>
            <div class="think-content">${content.trim()}</div>
        </div>`;
        return '';
    });

    // 2. Strip any duplicate CoT bullet points leftover in body text
    cleanText = cleanText.replace(/^[•\-\*]\s*(Investigaré|Buscó|Recolectó|Muy bien|Analizando|Procesando|Evidencia|Consultando)[\s\S]*?(\n|$)/gmi, '').trim();

    let html = escapeHtml(cleanText);
    
    html = html.replace(/```(\w*)\n([\s\S]*?)```/g, (match, lang, code) => {
        const safeLang = escapeHtml(lang || 'code');
        const safeCode = escapeHtml(code);
        return `<div class="code-block-wrapper">
            <div class="code-block-header">
                <span class="code-lang-label">${safeLang}</span>
                <button class="code-copy-btn" onclick="navigator.clipboard.writeText(this.closest('.code-block-wrapper').querySelector('code').textContent); this.classList.add('copied'); this.querySelector('.copy-text').textContent='Copied!'; setTimeout(() => { this.classList.remove('copied'); this.querySelector('.copy-text').textContent='Copy'; }, 2000);" title="Copy code">
                    <i class="f7-icons">doc_on_doc</i>
                    <span class="copy-text">Copy</span>
                </button>
            </div>
            <pre><code class="language-${safeLang}">${safeCode}</code></pre>
        </div>`;
    });
    
    html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
    
    html = html.replace(/^### (.+)$/gm, '<h3>$1</h3>');
    html = html.replace(/^## (.+)$/gm, '<h2>$1</h2>');
    html = html.replace(/^# (.+)$/gm, '<h1>$1</h1>');
    
    html = html.replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>');
    html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');
    
    html = html.replace(/~~(.+?)~~/g, '<del>$1</del>');
    
    html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
    
    html = html.replace(/^> (.+)$/gm, '<blockquote>$1</blockquote>');
    
    html = html.replace(/^---$/gm, '<hr>');
    
    const lines = html.split('\n');
    const processed = [];
    let i = 0;
    
    while (i < lines.length) {
        const line = lines[i];
        
        if (line.match(/^- (.+)$/)) {
            const listItems = [];
            while (i < lines.length && lines[i].match(/^- (.+)$/)) {
                const content = lines[i].replace(/^- (.+)$/, '$1');
                listItems.push(`<li>${content}</li>`);
                i++;
            }
            processed.push(`<ul>${listItems.join('')}</ul>`);
            continue;
        }
        
        if (line.match(/^\d+\. (.+)$/)) {
            const listItems = [];
            while (i < lines.length && lines[i].match(/^\d+\. (.+)$/)) {
                const content = lines[i].replace(/^\d+\. (.+)$/, '$1');
                listItems.push(`<li>${content}</li>`);
                i++;
            }
            processed.push(`<ol>${listItems.join('')}</ol>`);
            continue;
        }
        
        processed.push(line);
        i++;
    }
    
    html = processed.join('\n');
    
    const paragraphs = html.split('\n\n');
    if (paragraphs.length > 1) {
        html = paragraphs.map(p => {
            p = p.trim();
            if (!p) return '';
            if (p.startsWith('<') && (
                p.startsWith('<h') || p.startsWith('<pre') || p.startsWith('<div') ||
                p.startsWith('<ul') || p.startsWith('<ol') ||
                p.startsWith('<blockquote') || p.startsWith('<hr') ||
                p.startsWith('<p>')
            )) return p;
            return `<p>${p}</p>`;
        }).join('\n');
    }

    const blockPreserve = /<(pre|code|ul|ol|blockquote|div)[^>]*>[\s\S]*?<\/\1>/gi;
    const blocks = [];
    html = html.replace(blockPreserve, (match) => {
        blocks.push(match);
        return `__BLOCK_${blocks.length - 1}__`;
    });
    
    html = html.replace(/\n/g, '<br>');
    html = html.replace(/__BLOCK_(\d+)__/g, (_, i) => blocks[parseInt(i)]);
    
    return thinkBlockHtml + html;
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// ========== Conversation Management ==========
const CONVERSATIONS_KEY = 'newton_conversations';
const ACTIVE_CONV_KEY = 'newton_active_conversation';

function generateId() {
    return Date.now().toString(36) + '-' + Math.random().toString(36).substr(2, 6);
}

function getAllConversations() {
    try {
        const raw = localStorage.getItem(CONVERSATIONS_KEY);
        return raw ? JSON.parse(raw) : [];
    } catch { return []; }
}

function saveConversationsList(list) {
    localStorage.setItem(CONVERSATIONS_KEY, JSON.stringify(list));
}

function getConversation(id) {
    try {
        const raw = localStorage.getItem(`newton_conv_${id}`);
        return raw ? JSON.parse(raw) : null;
    } catch { return null; }
}

function saveConversation(conv) {
    localStorage.setItem(`newton_conv_${conv.id}`, JSON.stringify(conv));
}

function deleteConversation(id) {
    localStorage.removeItem(`newton_conv_${id}`);
    const list = getAllConversations().filter(c => c.id !== id);
    saveConversationsList(list);
    // If this was the active conversation, clear active
    if (localStorage.getItem(ACTIVE_CONV_KEY) === id) {
        localStorage.removeItem(ACTIVE_CONV_KEY);
    }
    renderConversationList();
}

function createNewConversation() {
    const conv = {
        id: generateId(),
        title: 'New conversation',
        messages: [],
        createdAt: Date.now(),
        updatedAt: Date.now()
    };
    const list = getAllConversations();
    list.unshift({ id: conv.id, title: conv.title, updatedAt: conv.updatedAt });
    saveConversationsList(list);
    saveConversation(conv);
    localStorage.setItem(ACTIVE_CONV_KEY, conv.id);
    return conv;
}

function getOrCreateActiveConversation() {
    const activeId = localStorage.getItem(ACTIVE_CONV_KEY);
    if (activeId) {
        const conv = getConversation(activeId);
        if (conv) return conv;
    }
    return createNewConversation();
}

function addMessageToConversation(role, content) {
    let conv = getOrCreateActiveConversation();
    conv.messages.push({ role, content, timestamp: Date.now() });
    conv.updatedAt = Date.now();

    // Update title from first user message
    if (conv.messages.length === 1 && role === 'user') {
        conv.title = content.slice(0, 50) + (content.length > 50 ? '...' : '');
    }

    saveConversation(conv);

    // Update list entry
    const list = getAllConversations();
    const idx = list.findIndex(c => c.id === conv.id);
    if (idx !== -1) {
        list[idx].title = conv.title;
        list[idx].updatedAt = conv.updatedAt;
    }
    saveConversationsList(list);
    renderConversationList();
}

async function generateAITitleForConversation(convId, userMsg) {
    if (!window.newtonCore || !window.newtonCore.isConfigured()) return;
    try {
        const prompt = `Generate a short 3 to 5 word title summarizing this conversation request: "${userMsg.slice(0, 250)}". Do NOT use quotes, markdown or punctuation. Return ONLY the title.`;
        const titleResponse = await window.newtonCore._sendToProvider(
            window.newtonCore.currentModel,
            [
                { role: 'system', content: 'You generate concise 3-5 word titles for conversations. Reply ONLY with the title text.' },
                { role: 'user', content: prompt }
            ],
            0.3,
            20
        );

        let cleanTitle = titleResponse.trim().replace(/^["'«»]|["'«»]$/g, '').replace(/[.#]$/, '');
        if (cleanTitle && cleanTitle.length > 2 && cleanTitle.length < 60) {
            const conv = getConversation(convId);
            if (conv) {
                conv.title = cleanTitle;
                conv.titleGeneratedByAI = true;
                saveConversation(conv);

                const list = getAllConversations();
                const idx = list.findIndex(c => c.id === conv.id);
                if (idx !== -1) {
                    list[idx].title = cleanTitle;
                    saveConversationsList(list);
                }
                renderConversationList();
            }
        }
    } catch (err) {
        console.warn('Could not generate AI title for conversation:', err);
    }
}

// ========== UI Rendering ==========
function renderConversationList() {
    const list = document.getElementById('conversation-list');
    if (!list) return;

    const conversations = getAllConversations();
    const activeId = localStorage.getItem(ACTIVE_CONV_KEY);

    if (conversations.length === 0) {
        list.innerHTML = '<div style="text-align:center;padding:20px;opacity:0.4;font-size:13px;font-family:var(--ser-font);position:absolute;top:50%;left:50%;transform:translate(-50%, -50%);width:80%;">No conversations yet</div>';
        return;
    }

    list.innerHTML = conversations.map(c => {
        const isActive = c.id === activeId;
        return `<div class="conversation-item ${isActive ? 'active' : ''}" data-id="${c.id}"><i class="f7-icons" style="font-size:14px;flex-shrink:0;">chat_bubble</i><span class="conv-title">${escapeHtml(c.title)}</span><button class="conv-delete" data-id="${c.id}" title="Delete conversation" aria-label="Delete conversation">&times;</button>
        </div>`;
    }).join('');

    // Click to switch conversation
    list.querySelectorAll('.conversation-item').forEach(item => {
        item.addEventListener('click', (e) => {
            if (e.target.closest('.conv-delete')) return;
            const id = item.dataset.id;
            if (id) {
                loadConversation(id);
                if (typeof window.closeMobileSidebar === 'function') window.closeMobileSidebar();
            }
        });
    });

    // Delete buttons
    list.querySelectorAll('.conv-delete').forEach(btn => {
        btn.addEventListener('click', async (e) => {
            e.stopPropagation();
            const id = btn.dataset.id;
            if (id) {
                const confirmed = await Moke.confirm('Delete this conversation?', {
                    okText: 'Delete',
                    cancelText: 'Cancel'
                });
                if (confirmed) {
                    deleteConversation(id);
                    clearChatDisplay();

                    if (localStorage.getItem(ACTIVE_CONV_KEY) !== id) {
                        loadConversation(localStorage.getItem(ACTIVE_CONV_KEY));
                    } else {
                        createNewConversation();
                    }
                }
            }
        });
    });
}

function loadConversation(id) {
    if (!id) return;
    localStorage.setItem(ACTIVE_CONV_KEY, id);
    const conv = getConversation(id);
    if (conv) {
        renderMessages(conv.messages);
    }
    renderConversationList();
}

function renderMessages(messages) {
    const container = document.getElementById('messages-container');
    if (!container) return;

    // Clear all messages but keep no-chat placeholder
    const messagesEls = container.querySelectorAll('.message');
    messagesEls.forEach(el => el.remove());

    if (!messages || messages.length === 0) {
        showNoChat();
        return;
    }

    hideNoChat();

    // Render oldest first (prepend so they go to bottom of column-reverse container)
    for (let i = 0; i < messages.length; i++) {
        const msg = messages[i];
        const isHtml = msg.role === 'assistant';
        const content = isHtml ? renderMarkdown(msg.content) : msg.content;
        createMessageBubble({ message: content, from: msg.role === 'user' ? 'user' : 'newton', isHtml: true });
    }
    if (typeof initThinkingOrbsSystem === 'function') initThinkingOrbsSystem();
}

function clearChatDisplay() {
    const container = document.getElementById('messages-container');
    if (!container) return;
    const messagesEls = container.querySelectorAll('.message');
    messagesEls.forEach(el => el.remove());
    showNoChat();
}

function showNoChat() {
    const noChat = document.querySelector('.no-chat');
    if (noChat) {
        noChat.style.display = '';
        noChat.classList.remove('hidden');
    }
    hasSentFirstMessage = false;
}

function hideNoChat() {
    const noChat = document.querySelector('.no-chat');
    if (noChat) {
        noChat.classList.add('hidden');
        setTimeout(() => {
            noChat.style.display = 'none';
        }, 400);
    }
}



function createMessageBubble({ message, from = 'user', isHtml = false }) {
    const container = document.getElementById('messages-container');

    const messageDiv = document.createElement('div');
    messageDiv.className = `message from-${from}`;

    const bubble = document.createElement('div');
    bubble.className = 'message-bubble';

    if (isHtml) {
        bubble.innerHTML = message;
    } else {
        bubble.innerText = message;
    }

    // Add timestamp
    const time = document.createElement('div');
    time.className = 'message-time';
    time.textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    bubble.appendChild(time);

    messageDiv.appendChild(bubble);
    container.prepend(messageDiv);

    messageDiv.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

    return messageDiv;
}

// ========== Streamed Response Generator ==========
async function streamMessageBubble({ text, from = 'newton' }) {
    const container = document.getElementById('messages-container');

    const messageDiv = document.createElement('div');
    messageDiv.className = `message from-${from}`;

    const bubble = document.createElement('div');
    bubble.className = 'message-bubble streaming-active';

    const time = document.createElement('div');
    time.className = 'message-time';
    time.textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    messageDiv.appendChild(bubble);
    container.prepend(messageDiv);
    messageDiv.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

    const stopBtn = document.getElementById('stop-generating');
    if (stopBtn) stopBtn.classList.add('show');

    let currentIndex = 0;
    const chunkSize = 5;
    const totalLen = text.length;

    return new Promise((resolve) => {
        const interval = setInterval(() => {
            currentIndex += chunkSize;
            if (currentIndex >= totalLen) {
                currentIndex = totalLen;
                clearInterval(interval);
                bubble.classList.remove('streaming-active');
                if (stopBtn) stopBtn.classList.remove('show');
            }

            const currentSubstr = text.slice(0, currentIndex);
            const renderedHtml = renderMarkdown(currentSubstr);
            bubble.innerHTML = renderedHtml;
            bubble.appendChild(time);

            if (currentIndex >= totalLen) {
                resolve(messageDiv);
            }
        }, 14);
    });
}

// Typing indicator with thinking-orbs 3D Canvas Component
function showTypingIndicator() {
    const container = document.getElementById('messages-container');
    const typingDiv = document.createElement('div');
    typingDiv.className = 'message from-newton typing-indicator';
    typingDiv.id = 'typing-indicator';

    const bubble = document.createElement('div');
    bubble.className = 'message-bubble';
    bubble.style.background = 'transparent';
    bubble.style.border = 'none';
    bubble.style.padding = '0';
    bubble.style.boxShadow = 'none';
    
    bubble.innerHTML = `
        <div class="thinking-orb-wrapper">
            <div class="thinking-orb-canvas-container" id="orb-canvas-container">
                <div class="thinking-orb">
                    <div class="orb-ring"></div>
                    <div class="orb-glow"></div>
                    <div class="orb-core"></div>
                </div>
            </div>
            <span class="orb-text">Newton is reasoning...</span>
        </div>
    `;
    typingDiv.appendChild(bubble);
    container.prepend(typingDiv);

    // Initialize thinking-orbs 3D Canvas renderer if loaded
    const orbContainer = bubble.querySelector('#orb-canvas-container');
    if (orbContainer && typeof window.createThinkingOrb === 'function') {
        try {
            window.activeThinkingOrb = window.createThinkingOrb(orbContainer, { state: 'searching', size: 28, isDark: false });
        } catch (e) {}
    }
    
    // Show stop button
    const stopBtn = document.getElementById('stop-generating');
    if (stopBtn) stopBtn.classList.add('show');
    
    return typingDiv;
}

function hideTypingIndicator() {
    const indicator = document.getElementById('typing-indicator');
    if (indicator) indicator.remove();
    
    // Hide stop button
    const stopBtn = document.getElementById('stop-generating');
    if (stopBtn) stopBtn.classList.remove('show');
}
// ========== Send Message ==========
async function sendMessage() {
    const input = document.getElementById('chat-input');
    const userText = input.value.trim();

    if (!userText && attachedFiles.length === 0) return;

    // Process attached files
    const filesToProcess = [...attachedFiles];
    attachedFiles = [];
    renderAttachmentPreviews();

    // Disable input and button
    input.value = '';
    input.style.height = 'auto';
    checkInputState();

    onFirstMessageSent();

    // Build chat display content & LLM prompt payload
    let displayMessage = userText ? escapeHtml(userText) : '';
    let fullPrompt = userText;

    if (filesToProcess.length > 0) {
        const fileBadges = filesToProcess.map(f => `📎 **${escapeHtml(f.name)}**`).join(' ');
        displayMessage = displayMessage 
            ? `${displayMessage}<br><br>${fileBadges}`
            : fileBadges;

        let filesPayload = '\n\n[Attached Files Content]:\n';
        filesToProcess.forEach(f => {
            if (f.isImage) {
                filesPayload += `\n--- Attached Image: ${f.name} ---\n[Image Data: ${f.dataUrl.slice(0, 100)}...]\n`;
            } else {
                filesPayload += `\n--- Attached File: ${f.name} ---\n\`\`\`\n${f.text}\n\`\`\`\n`;
            }
        });
        fullPrompt += filesPayload;
    }

    // Get history before adding the new message
    const currentConv = getOrCreateActiveConversation();
    const history = (currentConv && currentConv.messages) ? currentConv.messages.slice(-10) : [];

    // Add user message to conversation and display
    addMessageToConversation('user', fullPrompt);
    createMessageBubble({ 
        message: displayMessage, 
        from: 'user', 
        isHtml: true 
    });
    showTypingIndicator();

    try {
        let response;
        if (window.newtonCore && window.newtonCore.isReady) {
            response = await window.newtonCore.generateResponse(fullPrompt, history);
        } else {
            await new Promise(r => setTimeout(r, 500));
            if (window.newtonCore && window.newtonCore.isReady) {
                response = await window.newtonCore.generateResponse(fullPrompt, history);
            } else {
                response = "Newton is initializing. Please try again in a moment.";
            }
        }

        hideTypingIndicator();

        if (response === '[Generation stopped]') {
            return;
        }

        if (response && !response.startsWith('⚠️')) {
            addMessageToConversation('assistant', response);
        }
        
        // Progressive Typewriter Streaming
        await streamMessageBubble({ text: response, from: 'newton' });

        const activeConv = getOrCreateActiveConversation();
        if (activeConv && activeConv.messages.length <= 3 && !activeConv.titleGeneratedByAI) {
            generateAITitleForConversation(activeConv.id, userText || 'File Analysis');
        }

    } catch (error) {
        hideTypingIndicator();
        console.error('Error:', error);
        const errMsg = `⚠️ **API Error**: ${error.message || 'Call failed. Please check your API key in Settings.'}`;
        createMessageBubble({
            message: renderMarkdown(errMsg),
            from: 'newton',
            isHtml: true
        });
    }
}

function checkInputState() {
    const input = document.getElementById('chat-input');
    const sendBtn = document.getElementById('send');
    if (!input || !sendBtn) return;

    const hasText = input.value.trim() !== '';
    const hasFiles = typeof attachedFiles !== 'undefined' && attachedFiles.length > 0;

    if (!hasText && !hasFiles) {
        sendBtn.disabled = true;
        if (!hasSentFirstMessage) revertEffect();
    } else {
        sendBtn.disabled = false;
        onUserStartedTyping();
    }
}

// ========== Stop Generation ==========
function stopGeneration() {
    if (window.newtonCore) {
        window.newtonCore.cancelGeneration();
        hideTypingIndicator();
    }
}

// ========== UI Helpers ==========
function onFirstMessageSent() {
    if (hasSentFirstMessage) return;
    hasSentFirstMessage = true;
    hideNoChat();
}

function onUserStartedTyping() {
    if (hasSentFirstMessage) return;
    if (noChatImg && !noChatImg.classList.contains('hidden')) {
        noChatImg.classList.add('hidden');
        if (noChatH1) {
            noChatH1.style.transform = 'translateY(-50px)';
            noChatH1.style.transition = 'transform 0.3s ease';
        }
    }
}

function revertEffect() {
    if (hasSentFirstMessage) return;
    if (noChatImg && noChatImg.classList.contains('hidden')) {
        noChatImg.classList.remove('hidden');
        if (noChatH1) {
            noChatH1.style.transform = '';
            noChatH1.style.transition = '';
        }
    }
}

function checkInputState() {
    const input = document.getElementById('chat-input');
    const sendBtn = document.getElementById('send');
    const stopBtn = document.getElementById('stop-generating');

    if (input.value.trim() === '') {
        sendBtn.disabled = true;
        if (!hasSentFirstMessage) revertEffect();
    } else {
        sendBtn.disabled = false;
        onUserStartedTyping();
    }
}

// ========== Event Listeners ==========
(() => {
    const input = document.getElementById('chat-input');
    const sendBtn = document.getElementById('send');
    const stopBtn = document.getElementById('stop-generating');
    const random = Math.floor(Math.random() * _placeholders.length);
    const placeholderEl = document.getElementById('no-chat-placeholder');

    if (placeholderEl) {
        placeholderEl.innerText = _placeholders[random];
    }

    checkInputState();

    if (input) {
        input.addEventListener('input', () => {
            checkInputState();
            input.style.height = 'auto';
            input.style.overflowY = input.scrollHeight >= 200 ? 'auto' : 'hidden';
            input.style.height = Math.min(input.scrollHeight, 200) + 'px';
        });

        input.addEventListener('keydown', (e) => {
            checkInputState();
            if (e.key === 'Enter' && !e.shiftKey && !sendBtn.disabled) {
                e.preventDefault();
                sendMessage();
            }
        });
    }

    if (sendBtn) {
        sendBtn.addEventListener('click', () => {
            checkInputState();
            sendMessage();
        });
    }

    if (stopBtn) {
        stopBtn.addEventListener('click', stopGeneration);
    }

    // Suggestion Cards click handler
    document.querySelectorAll('.suggestion-card').forEach(card => {
        card.addEventListener('click', () => {
            const prompt = card.dataset.prompt;
            const input = document.getElementById('chat-input');
            if (input && prompt) {
                input.value = prompt;
                checkInputState();
                input.focus();
                sendMessage();
            }
        });
    });

    // Model Status Pill click handler
    const statusPill = document.getElementById('chat-status-pill');
    if (statusPill) {
        statusPill.addEventListener('click', () => {
            if (typeof Moke !== 'undefined') {
                Moke.navigate('/configs');
            }
        });
    }

    // ===== File Management UI =====

function renderFileList(files) {
    const container = document.getElementById('file-list');
    if (!container) return;

    if (!files || files.length === 0) {
        container.innerHTML = '<div class="file-empty">No files uploaded</div>';
        return;
    }

    container.innerHTML = files.map(file => `
        <div class="file-item" data-file="${file.name}">
            <span class="file-icon">${getFileIcon(file.name)}</span>
            <span class="file-name" title="${file.name}">${file.name}</span>
            <span class="file-size">${formatFileSize(file.size)}</span>
            <button class="file-download" data-file="${file.name}" title="Download">⬇</button>
            <button class="file-delete" data-file="${file.name}" title="Delete">✕</button>
        </div>
    `).join('');

    // Event listeners
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
                    // File list will be refreshed via listener
                } else {
                    Moke.alert(`Failed to delete: ${result.error}`);
                }
            }
        });
    });

    container.querySelectorAll('.file-download').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const filename = btn.dataset.file;
            if (filename) {
                const url = window.newtonCore.getFileDownloadUrl(filename);
                window.open(url, '_blank');
            }
        });
    });
}

function getFileIcon(filename) {
    const ext = filename.split('.').pop().toLowerCase();
    const icons = {
        'pdf': '📄',
        'txt': '📝',
        'md': '📝',
        'json': '📋',
        'csv': '📊',
        'png': '🖼️',
        'jpg': '🖼️',
        'jpeg': '🖼️',
        'gif': '🖼️',
        'svg': '🖼️',
        'py': '🐍',
        'js': '📜',
        'html': '🌐',
        'css': '🎨',
        'zip': '📦',
        'rar': '📦',
        'exe': '⚙️',
        'dmg': '💿',
    };
    return icons[ext] || '📎';
}

function formatFileSize(bytes) {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / 1048576).toFixed(1) + ' MB';
}

// ===== File Attachment & Upload Engine =====

function setupFileUpload() {
    const fileInput = document.getElementById('file-input');
    const attachBtn = document.getElementById('attach-file-btn');
    const uploadBtn = document.getElementById('upload-file-btn');

    function triggerUpload() {
        if (fileInput) fileInput.click();
    }

    if (attachBtn) attachBtn.addEventListener('click', triggerUpload);
    if (uploadBtn) uploadBtn.addEventListener('click', triggerUpload);

    if (fileInput) {
        fileInput.addEventListener('change', async (e) => {
            const files = Array.from(e.target.files);
            if (files.length === 0) return;

            for (const file of files) {
                const fileId = Date.now() + '_' + Math.random().toString(36).substr(2, 5);
                const isImage = file.type.startsWith('image/');
                
                const fileObj = {
                    id: fileId,
                    name: file.name,
                    size: file.size,
                    type: file.type,
                    isImage: isImage,
                    text: '',
                    dataUrl: ''
                };

                const reader = new FileReader();
                if (isImage) {
                    reader.onload = (evt) => {
                        fileObj.dataUrl = evt.target.result;
                        attachedFiles.push(fileObj);
                        renderAttachmentPreviews();
                    };
                    reader.readAsDataURL(file);
                } else {
                    reader.onload = (evt) => {
                        fileObj.text = evt.target.result || '';
                        attachedFiles.push(fileObj);
                        renderAttachmentPreviews();
                    };
                    reader.readAsText(file);
                }

                // Asynchronously attempt backend workspace upload if server active
                if (window.newtonCore && typeof window.newtonCore.uploadFile === 'function') {
                    window.newtonCore.uploadFile(file).catch(() => {});
                }
            }

            fileInput.value = '';
        });
    }
}

function toggleDarkMode() {
    const html = document.documentElement;
    const isDark = html.getAttribute('data-theme') === 'dark';
    html.setAttribute('data-theme', isDark ? 'light' : 'dark');
    localStorage.setItem('newton-theme', isDark ? 'light' : 'dark');
}

window.toggleDarkMode = toggleDarkMode;

// Cargar tema guardado
const savedTheme = localStorage.getItem('newton-theme');
if (savedTheme) {
    document.documentElement.setAttribute('data-theme', savedTheme);
} else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
    document.documentElement.setAttribute('data-theme', 'dark');
}

// Register file listener in NewtonCore
if (window.newtonCore) {
    window.newtonCore.addFileListener((files) => {
        renderFileList(files);
    });
}

// Setup file upload on load
Moke.on('load', () => {
    setupFileUpload();
    // Also render initial file list
    if (window.newtonCore) {
        renderFileList(window.newtonCore.uploadedFiles);
    }
});

// Re-render file list when navigating back to app
window.addEventListener('Moke_PageLoaded', (e) => {
    if (e.detail === '/app' && window.newtonCore) {
        renderFileList(window.newtonCore.uploadedFiles);
    }
});
})();

const NewtonCode = {
    async init(){
        await Moke.navigate('/app');
        alert('Welcome to Newton Code.');

        Moke.element('.chat').fade('out');
    }
}

// 3D Thinking Orbs Engine Lifecycle & Layout Integrations
function initThinkingOrbsSystem() {
    if (typeof window.createThinkingOrb !== 'function') return;

    // 1. Header Status Bar Orb
    const statusOrbContainer = document.getElementById('status-orb-container');
    if (statusOrbContainer && !statusOrbContainer.dataset.initialized) {
        statusOrbContainer.dataset.initialized = 'true';
        try {
            window.statusOrb = window.createThinkingOrb(statusOrbContainer, { state: 'globe', size: 18, isDark: false });
        } catch (e) {}
    }

    // 2. Hero 3D Orb (in welcome screen)
    const heroOrbContainer = document.getElementById('hero-thinking-orb-container');
    if (heroOrbContainer && !heroOrbContainer.dataset.initialized) {
        heroOrbContainer.dataset.initialized = 'true';
        try {
            window.heroOrb = window.createThinkingOrb(heroOrbContainer, { state: 'orbits', size: 90, isDark: false });
        } catch (e) {}
    }

    // 3. Inline Reasoning Orbs in Think Blocks
    const thinkContainers = document.querySelectorAll('.think-orb-inline-container:not([data-initialized])');
    thinkContainers.forEach(container => {
        container.dataset.initialized = 'true';
        const orbState = container.dataset.orbState || 'orbits';
        try {
            window.createThinkingOrb(container, { state: orbState, size: 20, isDark: false });
        } catch (e) {}
    });
}
window.initThinkingOrbsSystem = initThinkingOrbsSystem;

// Interactive Hero Orb Morph on Suggestion Card Hover
document.addEventListener('mouseover', (e) => {
    const card = e.target.closest('.suggestion-card');
    if (card && window.heroOrb) {
        const states = ['globe', 'rubik', 'wave', 'morph'];
        const randomState = states[Math.floor(Math.random() * states.length)];
        window.heroOrb.setState(randomState);
    }
});

// Load active conversation on page load
Moke.on('load', async () => {
    await Moke.sleep(100);
    document.body.classList.add('ready');

    // Load active conversation
    const activeConv = getOrCreateActiveConversation();
    renderMessages(activeConv.messages);
    renderConversationList();
    initThinkingOrbsSystem();
});

// Also re-render when navigating back from configs or other pages
window.addEventListener('Moke_PageLoaded', (e) => {
    if (e.detail === '/app') {
        const activeConv = getOrCreateActiveConversation();
        renderMessages(activeConv.messages);
        renderConversationList();
        initThinkingOrbsSystem();
    }
});
