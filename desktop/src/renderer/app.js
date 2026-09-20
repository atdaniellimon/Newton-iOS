// Newton AI Desktop - iOS Everforest Studio Controller
// Connected to https://api.newton.daniellimon.uk

document.addEventListener('DOMContentLoaded', () => {
  // Elements: Main Workspace
  const chatForm = document.getElementById('chat-form');
  const promptInput = document.getElementById('prompt-input');
  const messagesContainer = document.getElementById('messages-container');
  const welcomeScreen = document.getElementById('welcome-screen');
  const heroSubtitle = document.getElementById('hero-subtitle');
  const btnSend = document.getElementById('btn-send');
  const btnSendIcon = document.getElementById('btn-send-icon');
  const modelSelect = document.getElementById('model-select');
  const modeSelect = document.getElementById('mode-select');

  // Sidebar Elements
  const btnNavChats = document.getElementById('btn-nav-chats');
  const btnGhostMode = document.getElementById('btn-ghost-mode');
  const btnWorkspaces = document.getElementById('btn-workspaces');
  const btnGallery = document.getElementById('btn-gallery');
  const btnNewChat = document.getElementById('btn-new-chat');
  const btnSettings = document.getElementById('btn-settings');
  const chatHistoryList = document.getElementById('chat-history-list');

  const activeChatTitle = document.getElementById('active-chat-title');
  const ghostBanner = document.getElementById('ghost-banner');
  const btnVanish = document.getElementById('btn-vanish');

  // User Profile Elements
  const userAvatar = document.getElementById('user-avatar');
  const userEmail = document.getElementById('user-email');
  const userTier = document.getElementById('user-tier');
  const userCredits = document.getElementById('user-credits');

  // Attachments
  const btnAttach = document.getElementById('btn-attach');
  const fileInput = document.getElementById('file-input');
  const attachmentBar = document.getElementById('attachment-preview-bar');
  const attachmentName = document.getElementById('attachment-name');
  const btnRemoveAttachment = document.getElementById('btn-remove-attachment');

  // Art Gallery Modal Elements
  const artGalleryModal = document.getElementById('art-gallery-modal');
  const btnCloseGallery = document.getElementById('btn-close-gallery');
  const galleryPromptInput = document.getElementById('gallery-prompt-input');
  const btnGalleryGenerate = document.getElementById('btn-gallery-generate');
  const tabGenerated = document.getElementById('tab-generated');
  const tabSent = document.getElementById('tab-sent');
  const countGenerated = document.getElementById('count-generated');
  const countSent = document.getElementById('count-sent');
  const galleryGrid = document.getElementById('gallery-grid');
  const galleryEmptyState = document.getElementById('gallery-empty-state');

  // Settings Modal Elements
  const settingsModal = document.getElementById('settings-modal');
  const btnCloseSettings = document.getElementById('btn-close-settings');
  const settingsUsername = document.getElementById('settings-username');
  const settingsEmail = document.getElementById('settings-email');
  const settingsApiKey = document.getElementById('settings-api-key');
  const btnCopyKey = document.getElementById('btn-copy-key');
  const btnRotateKey = document.getElementById('btn-rotate-key');
  const settingsTierBadge = document.getElementById('settings-tier-badge');
  const settingsCredits = document.getElementById('settings-credits');
  const settingsRpm = document.getElementById('settings-rpm');
  const settingsQuotas = document.getElementById('settings-quotas');

  const settingDefaultModel = document.getElementById('setting-default-model');
  const settingStreamToggle = document.getElementById('setting-stream-toggle');
  const settingAutotitleToggle = document.getElementById('setting-autotitle-toggle');
  const settingTheme = document.getElementById('setting-theme');
  const settingThinkedExpand = document.getElementById('setting-thinked-expand');
  const settingLanguage = document.getElementById('setting-language');
  const btnClearGallery = document.getElementById('btn-clear-gallery');
  const btnExportChats = document.getElementById('btn-export-chats');
  const btnLogoutRow = document.getElementById('btn-logout-row');

  // Lightbox Modal Elements
  const lightboxModal = document.getElementById('lightbox-modal');
  const btnLightboxClose = document.getElementById('btn-lightbox-close');
  const lightboxImg = document.getElementById('lightbox-img');
  const lightboxCaption = document.getElementById('lightbox-caption');
  const btnLightboxCopy = document.getElementById('btn-lightbox-copy');
  const btnLightboxOpen = document.getElementById('btn-lightbox-open');

  // Discovery Subtitles
  const discoverySubtitles = [
    "What will you discover today?",
    "An apple falls, an idea grows.",
    "Uncover the laws of the universe.",
    "What is your next big question?",
    "Seeking truth in the data."
  ];

  // App Configuration State
  let config = {
    stream: true,
    autoTitle: true,
    expandThinked: true,
    defaultModel: 'Singularity',
    language: 'es',
    theme: 'dark'
  };

  try {
    const savedCfg = localStorage.getItem('newton_user_config');
    if (savedCfg) {
      config = { ...config, ...JSON.parse(savedCfg) };
    }
  } catch (e) {}

  // App State
  let currentChatId = null;
  let isGhostSession = false;
  let isGenerating = false;
  let currentAttachment = null;
  let localGhostHistory = [];
  let fullApiKey = '';

  // Gallery Store
  let galleryStore = {
    generated: [],
    sent: []
  };

  try {
    const saved = localStorage.getItem('newton_art_gallery');
    if (saved) {
      galleryStore = JSON.parse(saved);
    }
  } catch (e) {}

  let currentGalleryTab = 'generated';

  // 1. Initial Setup
  init();

  async function init() {
    applyConfigToUI();
    setupModeSwitcher();
    setupAuthSystem();
    setupInputEvents();
    setupHeroCards();
    setupAttachments();
    setupModals();
    rotateSubtitle();
    updateGalleryCounts();
    promptInput.focus();

    btnWorkspaces?.addEventListener('click', () => switchAppMode('code'));

    const userProfileBar = document.getElementById('user-profile-bar');
    userProfileBar?.addEventListener('click', openSettingsModal);

    const codeUserProfileBar = document.getElementById('code-user-profile-bar');
    codeUserProfileBar?.addEventListener('click', openSettingsModal);

    const btnCodeSettings = document.getElementById('btn-code-settings');
    btnCodeSettings?.addEventListener('click', openSettingsModal);

    // Verify initial authentication status
    try {
      const authStatus = await window.newtonAPI.getAuthStatus();
      if (!authStatus?.data?.isAuthenticated) {
        showAuthScreen(false);
        return;
      }
    } catch (e) {
      console.warn('Auth status check error:', e);
    }

    // Listen for real-time cloud sync events from gateway SSE stream
    if (window.newtonAPI?.onCloudSyncEvent) {
      window.newtonAPI.onCloudSyncEvent((ev) => {
        if (!ev) return;
        const eventType = ev.event;
        const chatData = ev.data;

        if (eventType === 'chat:created' && chatData) {
          window.loadedChats = [chatData, ...(window.loadedChats || [])];
          renderChats(window.loadedChats);
          if (typeof renderCodeWorkspacesTree === 'function') renderCodeWorkspacesTree();
          if (typeof populateDashboardMetrics === 'function') populateDashboardMetrics();
          if (typeof renderContributionHeatmap === 'function') renderContributionHeatmap();
        } else if (eventType === 'chat:updated' && chatData) {
          if (Array.isArray(window.loadedChats)) {
            const idx = window.loadedChats.findIndex(c => c.id === chatData.id);
            if (idx >= 0) {
              Object.assign(window.loadedChats[idx], chatData);
            } else {
              window.loadedChats.unshift(chatData);
            }
          }
          renderChats(window.loadedChats);
          if (typeof renderCodeWorkspacesTree === 'function') renderCodeWorkspacesTree();
          if (typeof populateDashboardMetrics === 'function') populateDashboardMetrics();
        } else if (eventType === 'chat:deleted' && chatData) {
          if (Array.isArray(window.loadedChats)) {
            window.loadedChats = window.loadedChats.filter(c => c.id !== chatData.id);
          }
          renderChats(window.loadedChats);
          if (typeof renderCodeWorkspacesTree === 'function') renderCodeWorkspacesTree();
          if (typeof populateDashboardMetrics === 'function') populateDashboardMetrics();
          if (typeof renderContributionHeatmap === 'function') renderContributionHeatmap();
        } else if (eventType === 'desktop:command' && chatData) {
          // Comando remoto recibido desde el iPhone
          handleRemoteDispatchFromIOS(chatData);
        }
      });
    }

    if (window.newtonAPI?.onDesktopRemoteEvent) {
      window.newtonAPI.onDesktopRemoteEvent(async (ev) => {
        if (!ev) return;
        const eventType = ev.event;
        const data = ev.data;
        if (eventType === 'desktop:command' && data) {
          await handleRemoteDispatchFromIOS(data);
        } else if (eventType === 'desktop:cancel' && data) {
          handleRemoteCancel(data);
        }
      });
    }

    // Auto-sync local workspaces to gateway
    if (window.newtonAPI?.listWorkspaces) {
      loadCodeWorkspaces().catch(() => {});
    }

    await Promise.allSettled([
      loadUserProfile(),
      loadModels(),
      loadChats()
    ]);
  }

  function applyConfigToUI() {
    if (settingStreamToggle) settingStreamToggle.checked = config.stream;
    if (settingAutotitleToggle) settingAutotitleToggle.checked = config.autoTitle;
    if (settingThinkedExpand) settingThinkedExpand.checked = config.expandThinked;
    if (settingDefaultModel) settingDefaultModel.value = config.defaultModel;
    if (settingLanguage) settingLanguage.value = config.language;
    if (settingTheme) settingTheme.value = config.theme;
    if (modelSelect) modelSelect.value = config.defaultModel;
  }

  function saveUserConfig() {
    try {
      localStorage.setItem('newton_user_config', JSON.stringify(config));
    } catch (e) {}
  }

  function saveGalleryStore() {
    try {
      localStorage.setItem('newton_art_gallery', JSON.stringify(galleryStore));
    } catch (e) {}
    updateGalleryCounts();
  }

  function updateGalleryCounts() {
    if (countGenerated) countGenerated.textContent = galleryStore.generated.length;
    if (countSent) countSent.textContent = galleryStore.sent.length;
  }

  function rotateSubtitle() {
    if (heroSubtitle) {
      heroSubtitle.textContent = discoverySubtitles[Math.floor(Math.random() * discoverySubtitles.length)];
    }
  }

  // Setup Input & Auto-Grow
  function setupInputEvents() {
    promptInput.addEventListener('input', () => {
      promptInput.style.height = 'auto';
      promptInput.style.height = Math.min(promptInput.scrollHeight, 140) + 'px';

      const hasText = promptInput.value.trim().length > 0 || currentAttachment != null;
      if (hasText && !isGenerating) {
        btnSend.disabled = false;
        btnSend.classList.add('ready');
      } else if (!isGenerating) {
        btnSend.disabled = true;
        btnSend.classList.remove('ready');
      }
    });

    promptInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        chatForm.dispatchEvent(new Event('submit'));
      }
    });
  }

  function setupHeroCards() {
    const bind = (sel) => document.querySelectorAll(sel).forEach(card => {
      card.addEventListener('click', () => {
        const text = card.getAttribute('data-prompt');
        if (!text) return;
        promptInput.value = text;
        promptInput.style.height = 'auto';
        btnSend.disabled = false;
        btnSend.classList.add('ready');
        promptInput.focus();
        chatForm.dispatchEvent(new Event('submit'));
      });
    });
    bind('.hero-card-item');
    bind('.hero-secondary-btn');
    bind('#hero-primary-cta');
  }

  // Attachments
  function setupAttachments() {
    btnAttach?.addEventListener('click', () => fileInput?.click());

    fileInput?.addEventListener('change', (e) => {
      const file = e.target.files?.[0];
      if (!file) return;

      const reader = new FileReader();
      reader.onload = (event) => {
        const dataUrl = event.target.result;
        currentAttachment = {
          name: file.name,
          type: file.type.startsWith('image/') ? 'image' : 'file',
          dataUrl: dataUrl,
          file: file
        };

        attachmentName.textContent = file.name;
        attachmentBar.style.display = 'block';
        btnSend.disabled = false;
        btnSend.classList.add('ready');

        // Add to sent images in gallery if image
        if (file.type.startsWith('image/')) {
          galleryStore.sent.unshift({
            id: 'img_' + Date.now(),
            url: dataUrl,
            prompt: file.name,
            date: new Date().toLocaleDateString(),
            chatTitle: activeChatTitle.textContent
          });
          saveGalleryStore();
        }
      };
      reader.readAsDataURL(file);
    });

    btnRemoveAttachment?.addEventListener('click', () => {
      currentAttachment = null;
      if (fileInput) fileInput.value = '';
      attachmentBar.style.display = 'none';
      if (!promptInput.value.trim()) {
        btnSend.disabled = true;
        btnSend.classList.remove('ready');
      }
    });
  }

  // 2. Modals Wiring: Settings, Art Gallery & Lightbox
  function setupModals() {
    // Open Gallery
    btnGallery?.addEventListener('click', openArtGallery);
    btnCloseGallery?.addEventListener('click', () => artGalleryModal.style.display = 'none');

    // Open Settings
    btnSettings?.addEventListener('click', openSettingsModal);
    btnCloseSettings?.addEventListener('click', () => settingsModal.style.display = 'none');

    // Lightbox Close
    btnLightboxClose?.addEventListener('click', () => lightboxModal.style.display = 'none');
    lightboxModal?.addEventListener('click', (e) => {
      if (e.target === lightboxModal) lightboxModal.style.display = 'none';
    });

    // Close on Escape key
    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        artGalleryModal.style.display = 'none';
        settingsModal.style.display = 'none';
        lightboxModal.style.display = 'none';
      }
    });

    // Gallery Tabs
    tabGenerated?.addEventListener('click', () => {
      currentGalleryTab = 'generated';
      tabGenerated.classList.add('active');
      tabSent.classList.remove('active');
      renderGalleryGrid();
    });

    tabSent?.addEventListener('click', () => {
      currentGalleryTab = 'sent';
      tabSent.classList.add('active');
      tabGenerated.classList.remove('active');
      renderGalleryGrid();
    });

    // Gallery Generate Action (POST /nwtn/images)
    btnGalleryGenerate?.addEventListener('click', generateGalleryImage);
    galleryPromptInput?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        generateGalleryImage();
      }
    });

    // Copy API Key
    btnCopyKey?.addEventListener('click', () => {
      if (fullApiKey) {
        navigator.clipboard.writeText(fullApiKey);
        alert('API Key copiada al portapapeles.');
      }
    });

    // Rotate API Key
    btnRotateKey?.addEventListener('click', async () => {
      if (confirm('¿Estás seguro de que deseas rotar tu API Key? La clave actual será revocada y se generará una nueva inmediatamente.')) {
        try {
          const res = await window.newtonAPI.rotateKey();
          if (res.success && res.data?.api_key) {
            fullApiKey = res.data.api_key;
            settingsApiKey.textContent = `${fullApiKey.slice(0, 10)}••••••••${fullApiKey.slice(-6)}`;
            alert('API Key rotada con éxito.');
          } else {
            alert('Error rotando clave: ' + (res.error || 'Respuesta inválida'));
          }
        } catch (err) {
          alert('Error de conexión al rotar clave: ' + err.message);
        }
      }
    });

    // Settings Controls Listeners
    settingDefaultModel?.addEventListener('change', (e) => {
      config.defaultModel = e.target.value;
      modelSelect.value = e.target.value;
      saveUserConfig();
    });

    settingStreamToggle?.addEventListener('change', (e) => {
      config.stream = e.target.checked;
      saveUserConfig();
    });

    settingAutotitleToggle?.addEventListener('change', (e) => {
      config.autoTitle = e.target.checked;
      saveUserConfig();
    });

    settingThinkedExpand?.addEventListener('change', (e) => {
      config.expandThinked = e.target.checked;
      saveUserConfig();
    });

    settingLanguage?.addEventListener('change', (e) => {
      config.language = e.target.value;
      saveUserConfig();
    });

    settingTheme?.addEventListener('change', (e) => {
      config.theme = e.target.value;
      saveUserConfig();
    });

    // Clear Gallery
    btnClearGallery?.addEventListener('click', () => {
      if (confirm('¿Vaciar todas las imágenes guardadas en la galería local?')) {
        galleryStore.generated = [];
        galleryStore.sent = [];
        saveGalleryStore();
        renderGalleryGrid();
        alert('Galería vaciada con éxito.');
      }
    });

    // Export Chats
    btnExportChats?.addEventListener('click', async () => {
      try {
        const res = await window.newtonAPI.getChats({ limit: 100 });
        if (res.success && res.data?.chats) {
          const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(res.data.chats, null, 2));
          const dl = document.createElement('a');
          dl.setAttribute("href", dataStr);
          dl.setAttribute("download", `newton_conversations_${Date.now()}.json`);
          dl.click();
        } else {
          alert('No se pudieron obtener las conversaciones para exportar.');
        }
      } catch (err) {
        alert('Error al exportar: ' + err.message);
      }
    });

    // Switch Account Row
    const btnSwitchAccountRow = document.getElementById('btn-switch-account-row');
    btnSwitchAccountRow?.addEventListener('click', () => {
      settingsModal.style.display = 'none';
      showAuthScreen(true);
    });

    // Logout Row
    btnLogoutRow?.addEventListener('click', handleLogout);

    // Lightbox Copy & Open
    btnLightboxCopy?.addEventListener('click', () => {
      if (lightboxImg.src) {
        navigator.clipboard.writeText(lightboxImg.src);
        alert('Enlace copiado al portapapeles.');
      }
    });

    btnLightboxOpen?.addEventListener('click', () => {
      if (lightboxImg.src) {
        window.open(lightboxImg.src, '_blank');
      }
    });
  }

  // Open Art Gallery Modal
  function openArtGallery() {
    scanMessagesForImages();
    updateGalleryCounts();
    renderGalleryGrid();
    artGalleryModal.style.display = 'flex';
    galleryPromptInput.focus();
  }

  // Scan current messages in memory to extract images automatically
  function scanMessagesForImages() {
    const imagesInDOM = messagesContainer.querySelectorAll('img');
    imagesInDOM.forEach(img => {
      const src = img.src;
      if (src && !src.includes('newton_logo.png')) {
        const exists = galleryStore.generated.some(item => item.url === src);
        if (!exists) {
          galleryStore.generated.unshift({
            id: 'gen_' + Date.now() + Math.random().toString(36).slice(2, 6),
            url: src,
            prompt: img.alt || 'Obra generada en conversación',
            date: new Date().toLocaleDateString(),
            chatTitle: activeChatTitle.textContent
          });
        }
      }
    });
    saveGalleryStore();
  }

  // Render Gallery Grid
  function renderGalleryGrid() {
    const list = galleryStore[currentGalleryTab] || [];

    if (list.length === 0) {
      galleryEmptyState.style.display = 'block';
      galleryGrid.style.display = 'none';
      galleryGrid.replaceChildren();
      return;
    }

    galleryEmptyState.style.display = 'none';
    galleryGrid.style.display = 'grid';

    const frag = document.createDocumentFragment();
    list.forEach(item => {
      const card = document.createElement('div');
      card.className = 'gallery-card';

      const thumbWrap = document.createElement('div');
      thumbWrap.className = 'gallery-card-thumb-wrap';

      const img = document.createElement('img');
      img.className = 'gallery-card-thumb';
      img.src = item.url;
      img.alt = item.prompt;
      img.loading = 'lazy';

      thumbWrap.appendChild(img);

      const meta = document.createElement('div');
      meta.className = 'gallery-card-meta';

      const promptTitle = document.createElement('span');
      promptTitle.className = 'gallery-card-prompt';
      promptTitle.textContent = item.prompt || 'Sin título';

      const dateLabel = document.createElement('span');
      dateLabel.className = 'gallery-card-date';
      dateLabel.textContent = `${item.date || ''} • ${item.chatTitle || 'Newton Gallery'}`;

      meta.appendChild(promptTitle);
      meta.appendChild(dateLabel);

      card.appendChild(thumbWrap);
      card.appendChild(meta);

      card.addEventListener('click', () => {
        openLightbox(item);
      });

      frag.appendChild(card);
    });
    galleryGrid.replaceChildren(frag);
  }

  // Generate Image from Art Gallery Bar
  async function generateGalleryImage() {
    const prompt = galleryPromptInput.value.trim();
    if (!prompt) return;

    btnGalleryGenerate.disabled = true;
    btnGalleryGenerate.innerHTML = '<i class="f7-icons">arrow_2_circlepath</i> <span>Generando...</span>';

    try {
      const res = await window.newtonAPI.generateImage({ prompt, n: 1 });
      if (res.success && res.data?.images?.[0]?.url) {
        const imageUrl = res.data.images[0].url;

        galleryStore.generated.unshift({
          id: 'gen_' + Date.now(),
          url: imageUrl,
          prompt: prompt,
          date: new Date().toLocaleDateString(),
          chatTitle: 'Direct Generation'
        });

        saveGalleryStore();
        currentGalleryTab = 'generated';
        tabGenerated.classList.add('active');
        tabSent.classList.remove('active');
        renderGalleryGrid();
        galleryPromptInput.value = '';
      } else {
        alert('Error al generar imagen: ' + (res.error || 'Respuesta inválida del servidor'));
      }
    } catch (err) {
      alert('Error de conexión: ' + err.message);
    } finally {
      btnGalleryGenerate.disabled = false;
      btnGalleryGenerate.innerHTML = '<i class="f7-icons">sparkles</i> <span>Generar</span>';
    }
  }

  // Open Lightbox
  function openLightbox(item) {
    lightboxImg.src = item.url;
    lightboxCaption.textContent = item.prompt || '';
    lightboxModal.style.display = 'flex';
  }

  // Open Settings Modal & Populate Data
  async function openSettingsModal() {
    settingsModal.style.display = 'flex';
    try {
      const [cfgRes, meRes] = await Promise.allSettled([
        window.newtonAPI.getConfig ? window.newtonAPI.getConfig() : Promise.resolve(null),
        window.newtonAPI.getMe ? window.newtonAPI.getMe() : Promise.resolve(null)
      ]);

      if (cfgRes.status === 'fulfilled' && cfgRes.value?.success) {
        const cfg = cfgRes.value.data;
        fullApiKey = cfg.apiKey;
        settingsApiKey.textContent = cfg.maskedKey;
      }

      if (meRes.status === 'fulfilled' && meRes.value?.success) {
        const me = meRes.value.data;
        settingsUsername.textContent = me.username || 'look@daniellimon.uk';
        settingsEmail.textContent = me.email || 'look@daniellimon.uk';
        if (me.tier) {
          settingsTierBadge.textContent = me.tier.badge || me.tier.name || 'Matrix';
        }
        if (me.credits) {
          settingsCredits.textContent = Number(me.credits.remaining).toLocaleString() + ' tokens';
        }
        if (me.rpm_limit) {
          settingsRpm.textContent = `${me.rpm_limit} RPM (Ultra)`;
        }
        if (me.quotas?.req_5h) {
          settingsQuotas.textContent = `${me.quotas.req_5h.used} / ${me.quotas.req_5h.limit} reqs`;
        }
      }
    } catch (err) {
      console.warn('Error loading settings info:', err);
    }
  }

  // 3. Load User Profile from Gateway
  async function loadUserProfile() {
    try {
      if (!window.newtonAPI?.getMe) return;
      const res = await window.newtonAPI.getMe();
      if (res.success && res.data) {
        const data = res.data;
        window.userProfileData = data;

        const displayEmail = data.email || data.username || 'look@daniellimon.uk';
        const initial = (data.username || data.email || 'N')[0].toUpperCase();
        const tierName = data.tier?.badge || data.tier?.name || 'Matrix';

        let formattedCredits = '--';
        if (data.credits) {
          const rem = data.credits.remaining;
          if (rem > 1000000000) {
            formattedCredits = 'Ilimitado';
          } else if (rem > 1000000) {
            formattedCredits = `${(rem / 1000000).toFixed(1)}M`;
          } else {
            formattedCredits = `${rem}`;
          }
        }

        // Chat Mode Sidebar Profile
        if (userEmail) userEmail.textContent = displayEmail;
        if (userAvatar) userAvatar.textContent = initial;
        if (userTier) userTier.textContent = tierName;
        if (userCredits) userCredits.textContent = formattedCredits;

        // Code Mode Sidebar Profile (Consistent Footer)
        const codeUserAvatar = document.getElementById('code-user-avatar');
        const codeUserEmail = document.getElementById('code-user-email');
        const codeUserTier = document.getElementById('code-user-tier');
        const codeUserCredits = document.getElementById('code-user-credits');
        if (codeUserAvatar) codeUserAvatar.textContent = initial;
        if (codeUserEmail) codeUserEmail.textContent = displayEmail;
        if (codeUserTier) codeUserTier.textContent = tierName;
        if (codeUserCredits) codeUserCredits.textContent = formattedCredits;

        // Code Mode Header Greeting
        const codeUserFirstName = document.getElementById('code-user-first-name');
        if (codeUserFirstName) {
          codeUserFirstName.textContent = (data.username || 'daniel').split('@')[0];
        }

        // Refresh dashboard metrics & heatmap with real gateway data
        if (typeof populateDashboardMetrics === 'function') {
          populateDashboardMetrics();
        }
        if (typeof renderContributionHeatmap === 'function') {
          renderContributionHeatmap();
        }
      }
    } catch (err) {
      console.warn('Profile load error:', err);
    }
  }

  // Load Models
  async function loadModels() {
    try {
      if (!window.newtonAPI?.getModels) return;
      const res = await window.newtonAPI.getModels();
      if (res.success && res.data?.data) {
        modelSelect.replaceChildren();
        if (settingDefaultModel) settingDefaultModel.replaceChildren();

        res.data.data.forEach(m => {
          const opt = document.createElement('option');
          opt.value = m.id;
          opt.textContent = m.id;
          modelSelect.appendChild(opt);

          if (settingDefaultModel) {
            const opt2 = document.createElement('option');
            opt2.value = m.id;
            opt2.textContent = m.id;
            settingDefaultModel.appendChild(opt2);
          }
        });

        modelSelect.value = config.defaultModel;
        if (settingDefaultModel) settingDefaultModel.value = config.defaultModel;
      }
    } catch (err) {
      console.warn('Models load error:', err);
    }
  }

  // Load Cloud Chats
  async function loadChats() {
    try {
      if (!window.newtonAPI?.getChats) return;
      const res = await window.newtonAPI.getChats({ limit: 60 });
      if (res.success && res.data?.chats) {
        window.loadedChats = res.data.chats;
        renderChats(res.data.chats);
        if (typeof populateDashboardMetrics === 'function') {
          populateDashboardMetrics();
        }
        if (typeof renderContributionHeatmap === 'function') {
          renderContributionHeatmap();
        }
        if (typeof renderCodeWorkspacesTree === 'function') {
          renderCodeWorkspacesTree();
        }
      } else {
        chatHistoryList.innerHTML = '<div class="history-item empty-placeholder"><span>No recent chats</span></div>';
      }
    } catch (err) {
      chatHistoryList.innerHTML = '<div class="history-item empty-placeholder"><span>Offline mode</span></div>';
    }
  }

  function renderChats(chats) {
    chatHistoryList.replaceChildren();
    if (!chats.length) {
      chatHistoryList.innerHTML = '<div class="history-item empty-placeholder"><span>No recent chats</span></div>';
      return;
    }

    chats.forEach(chat => {
      const item = document.createElement('div');
      item.className = `history-item ${chat.id === currentChatId ? 'active' : ''}`;
      item.setAttribute('data-id', chat.id);

      const left = document.createElement('div');
      left.className = 'history-item-left';

      if (chat.is_pinned) {
        const pin = document.createElement('i');
        pin.className = 'f7-icons history-pin-icon';
        pin.textContent = 'pin_fill';
        left.appendChild(pin);
      }

      const title = document.createElement('span');
      title.className = 'history-item-title';
      title.textContent = chat.title || 'Conversation';
      left.appendChild(title);

      const btnDelete = document.createElement('button');
      btnDelete.className = 'btn-delete-chat';
      btnDelete.title = 'Delete chat';
      btnDelete.innerHTML = '<i class="f7-icons">trash</i>';

      btnDelete.addEventListener('click', async (e) => {
        e.stopPropagation();
        if (confirm(`Delete conversation "${chat.title}"?`)) {
          await deleteChat(chat.id);
        }
      });

      item.appendChild(left);
      item.appendChild(btnDelete);

      item.addEventListener('click', () => {
        openChat(chat.id, chat.title);
      });

      chatHistoryList.appendChild(item);
    });
  }

  async function openChat(chatId, title) {
    currentChatId = chatId;
    isGhostSession = false;
    ghostBanner.style.display = 'none';
    activeChatTitle.textContent = title || 'Conversation';

    document.querySelectorAll('.history-item').forEach(el => {
      el.classList.toggle('active', el.getAttribute('data-id') === chatId);
    });
    btnGhostMode?.classList.remove('active');
    btnNavChats?.classList.add('active');

    messagesContainer.replaceChildren();
    setGenerating(true);

    try {
      const res = await window.newtonAPI.getChatMessages({ chatId, limit: 60 });
      if (res.success && res.data?.messages) {
        if (res.data.messages.length === 0) {
          showWelcome();
        } else {
          res.data.messages.forEach(msg => {
            appendMessage(msg.role, msg.content);
          });
          scanMessagesForImages();
        }
      }
    } catch (err) {
      appendMessage('assistant', `Failed to load conversation: ${err.message}`);
    } finally {
      setGenerating(false);
      scrollToBottom();
    }
  }

  async function deleteChat(chatId) {
    try {
      await window.newtonAPI.deleteChat(chatId);
      if (currentChatId === chatId) {
        startNewChat();
      }
      await loadChats();
    } catch (err) {
      alert(`Error deleting chat: ${err.message}`);
    }
  }

  function startNewChat() {
    currentChatId = null;
    isGhostSession = false;
    ghostBanner.style.display = 'none';
    activeChatTitle.textContent = 'New chat';
    document.querySelectorAll('.history-item').forEach(el => el.classList.remove('active'));
    btnGhostMode?.classList.remove('active');
    btnNavChats?.classList.add('active');
    rotateSubtitle();
    showWelcome();
    promptInput.value = '';
    promptInput.focus();
    btnSend.disabled = true;
    btnSend.classList.remove('ready');
  }

  function startGhostMode() {
    currentChatId = null;
    isGhostSession = true;
    localGhostHistory = [];
    ghostBanner.style.display = 'flex';
    activeChatTitle.textContent = 'Ghost Session';

    document.querySelectorAll('.history-item').forEach(el => el.classList.remove('active'));
    btnNavChats?.classList.remove('active');
    btnGhostMode?.classList.add('active');
    rotateSubtitle();
    showWelcome();
    promptInput.value = '';
    promptInput.focus();
  }

  function showWelcome() {
    messagesContainer.replaceChildren();
    if (welcomeScreen) {
      messagesContainer.appendChild(welcomeScreen);
      welcomeScreen.style.display = 'flex';
    }
  }

  btnNewChat?.addEventListener('click', startNewChat);
  btnNavChats?.addEventListener('click', startNewChat);
  btnGhostMode?.addEventListener('click', startGhostMode);

  btnVanish?.addEventListener('click', () => {
    startNewChat();
  });

  btnWorkspaces?.addEventListener('click', () => {
    alert('Newton Workspaces: /Volumes/Daniel/projects/Newton');
  });

  modeSelect?.addEventListener('change', (e) => {
    if (e.target.value === 'code') {
      modelSelect.value = 'Singularity-Matrix';
    } else {
      modelSelect.value = 'Singularity';
    }
  });

  // 4. Send Message Handler
  chatForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const prompt = promptInput.value.trim();
    if ((!prompt && !currentAttachment) || isGenerating) return;

    if (welcomeScreen && welcomeScreen.parentElement) {
      welcomeScreen.style.display = 'none';
    }

    // Render User Bubble
    appendMessage('user', prompt);
    promptInput.value = '';
    promptInput.style.height = 'auto';
    setGenerating(true);

    if (currentAttachment) {
      currentAttachment = null;
      if (fileInput) fileInput.value = '';
      attachmentBar.style.display = 'none';
    }

    // Auto-create cloud chat if first message in non-ghost mode
    if (!currentChatId && !isGhostSession) {
      try {
        const titleGen = prompt.length > 32 ? prompt.slice(0, 32) + '...' : prompt;
        const createRes = await window.newtonAPI.createChat({
          title: titleGen,
          model: modelSelect.value
        });
        if (createRes.success && createRes.data?.chat) {
          currentChatId = createRes.data.chat.id;
          activeChatTitle.textContent = createRes.data.chat.title;
          loadChats();
        }
      } catch (err) {
        console.warn('Fallback direct messaging:', err);
      }
    }

    // Create assistant row with ThinkingCardView
    const botRow = createAssistantMessageRow();
    messagesContainer.appendChild(botRow.container);
    scrollToBottom();

    let rawStreamText = '';

    const cleanupStream = window.newtonAPI.onStreamChunk((chunk) => {
      if (chunk.type === 'delta') {
        rawStreamText += chunk.text;
        updateAssistantBubble(botRow, rawStreamText);
        scheduleScroll(messagesContainer);
      } else if (chunk.type === 'headers:quotas') {
        if (chunk.creditsLeft !== undefined && settingsCredits) {
          settingsCredits.textContent = chunk.creditsLeft.toLocaleString();
        }
      } else if (chunk.type === 'orbit:start') {
        if (codeHeaderOrb && typeof codeHeaderOrb.setState === 'function') {
          codeHeaderOrb.setState('orbits');
        }
      } else if (chunk.type === 'orbit:done') {
        if (codeHeaderOrb && typeof codeHeaderOrb.setState === 'function') {
          codeHeaderOrb.setState('idle');
        }
      } else if (chunk.type === 'done') {
        if (chunk.text && chunk.text.length > rawStreamText.length) {
          rawStreamText = chunk.text;
        }
        updateAssistantBubbleImmediate(botRow, rawStreamText);
        flushScroll();
      }
    });

    try {
      const payload = {
        chatId: currentChatId,
        prompt: prompt,
        model: modelSelect.value,
        isGhost: isGhostSession,
        history: localGhostHistory
      };

      const response = await window.newtonAPI.sendMessage(payload);

      if (cleanupStream) cleanupStream();

      if (response.success) {
        let fullText = response.data?.reply || rawStreamText;

        // Image-intent fallback: if user prompted to generate an image and the model replied with refusal or no markdown image
        const imageKeywords = [
          "genera una imagen", "generame una imagen", "generar una imagen", "crea una imagen", "creame una imagen",
          "haz una imagen", "hazme una imagen", "dibuja", "dibujame", "draw", "generate an image", "create an image",
          "make an image", "generate a picture", "paint", "pinta", "ilustra", "/imagine", "imagine"
        ];
        const lowerPrompt = prompt.toLowerCase();
        const wantsImage = imageKeywords.some(kw => lowerPrompt.includes(kw)) || lowerPrompt.startsWith("imagen de") || lowerPrompt.startsWith("foto de");
        const hasMarkdownImage = /!\[.*?\]\((https?:\/\/.*?|data:image\/.*?)\)/.test(fullText);

        if (wantsImage && !hasMarkdownImage) {
          try {
            const cleanImagePrompt = prompt.replace(/"/g, ' ').replace(/\n/g, ' ').trim();
            const imgRes = await window.newtonAPI.generateImage({ prompt: cleanImagePrompt, n: 1 });
            if (imgRes.success && imgRes.data?.images?.[0]?.url) {
              const generatedUrl = imgRes.data.images[0].url;
              // Clean refusal text
              fullText = fullText.replace(/(?:no (?:puedo|tengo la capacidad de|soy capaz de) (?:generar|crear|dibujar)[^\n.]*[\n.]?|lo siento[^\n]*imagen[^\n]*[\n.]?|como (?:modelo de lenguaje|ia)[^\n]*imagen[^\n]*[\n.]?|i can(?:not|'t) (?:generate|create) images?[^\n.]*[\n.]?)/gi, '').trim();
              if (fullText) fullText += '\n\n';
              fullText += `![Generated Image](${generatedUrl})`;
            }
          } catch (imgErr) {
            console.warn('Fallback image generation failed:', imgErr);
          }
        }

        updateAssistantBubble(botRow, fullText);

        if (isGhostSession) {
          localGhostHistory.push({ role: 'user', content: prompt });
          localGhostHistory.push({ role: 'assistant', content: fullText });
        }

        // Scan images generated during this turn
        setTimeout(scanMessagesForImages, 300);
      } else {
        const err = response.error || 'Failed to complete prompt.';
        botRow.content.textContent = err;
        botRow.content.style.color = 'var(--newton-coral)';
      }
    } catch (err) {
      botRow.content.textContent = err.message || 'Connection error';
      botRow.content.style.color = 'var(--newton-coral)';
    } finally {
      if (cleanupStream) cleanupStream();
      setGenerating(false);
      scrollToBottom();
      promptInput.focus();
    }
  });

  // UI Building: Assistant Message Row
  function createAssistantMessageRow() {
    const container = document.createElement('div');
    container.className = 'message-row assistant';

    const bubble = document.createElement('div');
    bubble.className = 'message-bubble';

    // ThinkingCardView (Thinked in Aqua)
    const thinkingCard = document.createElement('details');
    thinkingCard.className = 'thinking-card-ios';
    thinkingCard.style.display = 'none';

    const summary = document.createElement('summary');
    summary.className = 'thinking-summary-ios';
    summary.innerHTML = `
      <div class="thinking-summary-left">
        <i class="f7-icons">sparkles</i>
        <span>Thinked</span>
      </div>
      <i class="f7-icons chevron-icon">chevron_down</i>
    `;

    const thinkingBody = document.createElement('div');
    thinkingBody.className = 'thinking-body-ios';

    thinkingCard.appendChild(summary);
    thinkingCard.appendChild(thinkingBody);

    const contentDiv = document.createElement('div');
    contentDiv.className = 'markdown-body';

    // Thinking Orb Indicator (iOS Parity: ThinkingOrbView globe + "Newton está razonando...")
    let orbInstance = null;
    const thinkingRow = document.createElement('div');
    thinkingRow.className = 'thinking-indicator-row';
    const orbSlot = document.createElement('div');
    orbSlot.className = 'thinking-orb-slot';
    const thinkingLabel = document.createElement('span');
    thinkingLabel.className = 'thinking-label';
    thinkingLabel.textContent = 'Newton is reasoning...';
    thinkingRow.appendChild(orbSlot);
    thinkingRow.appendChild(thinkingLabel);

    contentDiv.appendChild(thinkingRow);
    if (typeof window.createThinkingOrb === 'function') {
      orbInstance = window.createThinkingOrb(orbSlot, { state: 'globe', size: 32, isDark: true });
    }

    bubble.appendChild(thinkingCard);
    bubble.appendChild(contentDiv);
    container.appendChild(bubble);

    return {
      container,
      bubble,
      thinkingCard,
      thinkingBody,
      content: contentDiv,
      thinkingRow,
      orbInstance
    };
  }

  // Core render (synchronous, expects cleanText already extracted)
  function renderAssistantContent(rowObj, cleanText) {
    if (cleanText) {
      if (rowObj.orbInstance) { rowObj.orbInstance.destroy(); rowObj.orbInstance = null; }
      const html = parseMarkdownSync(cleanText);
      if (html != null) {
        // Use DocumentFragment to avoid repeated layout; replaceChildren is single reflow
        const tpl = document.createElement('template');
        tpl.innerHTML = html;
        rowObj.content.replaceChildren(tpl.content.cloneNode(true));
      } else {
        rowObj.content.textContent = cleanText;
        // Kick off lazy load; re-render once ready if still relevant
        ensureMarked().then(mod => { if (mod && rowObj.content.textContent === cleanText) {
          const h2 = parseMarkdownSync(cleanText);
          if (h2 != null) { const t2 = document.createElement('template'); t2.innerHTML = h2; rowObj.content.replaceChildren(t2.content.cloneNode(true)); bindLightboxImages(rowObj.content); }
        }});
      }
    } else {
      if (!rowObj.content.querySelector('.thinking-indicator-row')) {
        rowObj.content.replaceChildren();
        const thinkingRow = document.createElement('div');
        thinkingRow.className = 'thinking-indicator-row';
        const orbSlot = document.createElement('div');
        orbSlot.className = 'thinking-orb-slot';
        const thinkingLabel = document.createElement('span');
        thinkingLabel.className = 'thinking-label';
        thinkingLabel.textContent = 'Newton está razonando...';
        thinkingRow.append(orbSlot, thinkingLabel);
        rowObj.content.appendChild(thinkingRow);
        if (typeof window.createThinkingOrb === 'function') {
          rowObj.orbInstance = window.createThinkingOrb(orbSlot, { state: 'globe', size: 32, isDark: true });
        }
      }
    }
    bindLightboxImages(rowObj.content);
  }
  function bindLightboxImages(root) {
    root.querySelectorAll('img').forEach(img => {
      if (img.dataset.lbBound) return;
      img.dataset.lbBound = '1';
      img.style.cursor = 'zoom-in';
      img.addEventListener('click', () => openLightbox({ url: img.src, prompt: img.alt || 'Generated artwork' }));
    });
  }
  function extractCleanAndThinking(fullText) {
    if (!fullText) return { cleanText: '', thinkingText: '' };

    let text = fullText;
    let thinkingText = '';

    // 1. Extraer bloques <thinking>...</thinking> o <think>...</think> completos
    const completeMatch = text.match(/<think(?:ing)?>([\s\S]*?)<\/think(?:ing)?>/i);
    if (completeMatch) {
      thinkingText = completeMatch[1].trim();
      text = text.replace(/<think(?:ing)?>[\s\S]*?<\/think(?:ing)?>/gi, '').trim();
    }

    // 2. Extraer etiquetas <thinking> o <think> no cerradas (stream en progreso o truncado)
    const openMatch = text.match(/<think(?:ing)?>([\s\S]*)$/i);
    if (openMatch) {
      const inner = openMatch[1].trim();
      if (!thinkingText) {
        thinkingText = inner;
      } else {
        thinkingText += '\n\n' + inner;
      }
      text = text.replace(/<think(?:ing)?>[\s\S]*$/i, '').trim();
    }

    // 3. Limpiar cualquier tag huérfano de cierre </thinking>
    text = text.replace(/<\/think(?:ing)?>/gi, '').trim();
    text = text.replace('<|generation_ended|>', '').trim();

    let cleanText = text;

    // 5. Sanitizador de fences markdown partidos: unir ``` vacíos o rotos
    if (cleanText) {
      cleanText = cleanText.replace(/```[a-zA-Z0-9_-]*\s*\n\s*```/g, '');
    }

    return { cleanText, thinkingText };
  }

  function updateAssistantBubble(rowObj, fullText) {
    const { cleanText, thinkingText } = extractCleanAndThinking(fullText);
    if (thinkingText) {
      rowObj.thinkingCard.style.display = 'block';
      rowObj.thinkingCard.open = config.expandThinked;
      rowObj.thinkingBody.textContent = thinkingText;
    }
    // Coalesce to 1 parse per frame during streaming bursts
    scheduleMarkdownRender(rowObj, cleanText, (text) => renderAssistantContent(rowObj, text));
  }

  // Immediate flush for final 'done' — bypass coalescing and guarantee orb destruction
  function updateAssistantBubbleImmediate(rowObj, fullText) {
    const { cleanText, thinkingText } = extractCleanAndThinking(fullText);
    if (thinkingText) {
      rowObj.thinkingCard.style.display = 'block';
      rowObj.thinkingCard.open = config.expandThinked;
      rowObj.thinkingBody.textContent = thinkingText;
    }
    _mdPending.delete(rowObj);
    renderAssistantContent(rowObj, cleanText);

    // Destrucción garantizada del orbe al terminar
    if (rowObj.orbInstance) {
      rowObj.orbInstance.destroy();
      rowObj.orbInstance = null;
    }
    const indicator = rowObj.content.querySelector('.thinking-indicator-row');
    if (indicator && cleanText) {
      indicator.remove();
    }
  }

  function appendMessage(role, text) {
    const row = document.createElement('div');
    row.className = `message-row ${role}`;

    const bubble = document.createElement('div');
    bubble.className = 'message-bubble';

    if (role === 'assistant') {
      const rowObj = createAssistantMessageRow();
      updateAssistantBubble(rowObj, text);
      messagesContainer.appendChild(rowObj.container);
      scrollToBottom();
      return rowObj.bubble;
    } else {
      bubble.textContent = text;
      row.appendChild(bubble);
      messagesContainer.appendChild(row);
      scrollToBottom();
      return bubble;
    }
  }

  // Lazy marked loader — classic script cannot use bare import(); inject once after first paint
  let _markedMod = null;
  let _markedLoading = null;
  function ensureMarked() {
    if (_markedMod) return Promise.resolve(_markedMod);
    if (_markedLoading) return _markedLoading;
    if (window.marked && typeof window.marked.parse === 'function') {
      _markedMod = window.marked;
      return Promise.resolve(_markedMod);
    }
    _markedLoading = new Promise(resolve => {
      const s = document.createElement('script');
      s.src = '../../node_modules/marked/lib/marked.umd.js';
      s.async = true;
      s.onload = () => {
        _markedMod = window.marked || null;
        resolve(_markedMod);
      };
      s.onerror = () => resolve(null);
      document.head.appendChild(s);
    });
    return _markedLoading;
  }
  // Kick lazy load idle (after first paint, non-blocking)
  if (typeof requestIdleCallback === 'function') requestIdleCallback(() => ensureMarked(), { timeout: 2000 });
  else setTimeout(() => ensureMarked(), 400);
  function parseMarkdownSync(text) {
    if (_markedMod && typeof _markedMod.parse === 'function') { try { return _markedMod.parse(text); } catch (_) {} }
    if (window.marked && typeof window.marked.parse === 'function') { try { return window.marked.parse(text); } catch (_) {} }
    return null;
  }

  // rAF-throttled scroll (coalesces bursts during streaming)
  let _scrollRaf = 0;
  let _scrollTargetEl = null;
  function scheduleScroll(el) {
    _scrollTargetEl = el || messagesContainer;
    if (_scrollRaf) return;
    _scrollRaf = requestAnimationFrame(() => {
      _scrollRaf = 0;
      const target = _scrollTargetEl;
      if (target) target.scrollTop = target.scrollHeight;
    });
  }
  function scrollToBottom() { scheduleScroll(messagesContainer); }
  function scrollCodeToBottom() {
    const el = document.getElementById('code-messages-stream');
    if (el) scheduleScroll(el);
  }
  // Flush pending scroll synchronously (e.g. on done)
  function flushScroll() {
    if (_scrollRaf) { cancelAnimationFrame(_scrollRaf); _scrollRaf = 0; }
    if (_scrollTargetEl) _scrollTargetEl.scrollTop = _scrollTargetEl.scrollHeight;
    else messagesContainer.scrollTop = messagesContainer.scrollHeight;
  }

  // Idle-throttled markdown render: coalesce deltas to 1 parse per frame or ~48 ms
  const _mdPending = new Map(); // rowObj -> { text, timer }
  function scheduleMarkdownRender(rowObj, fullText, applyFn) {
    let entry = _mdPending.get(rowObj);
    if (!entry) { entry = { text: fullText, raf: 0 }; _mdPending.set(rowObj, entry); }
    else entry.text = fullText;
    if (entry.raf) return;
    entry.raf = requestAnimationFrame(() => {
      entry.raf = 0;
      const latest = _mdPending.get(rowObj);
      if (!latest) return;
      _mdPending.delete(rowObj);
      applyFn(latest.text);
    });
  }

  function setGenerating(generating) {
    isGenerating = generating;
    if (generating) {
      btnSend.disabled = false;
      btnSend.classList.remove('ready');
      btnSend.classList.add('streaming');
      btnSendIcon.textContent = 'stop_fill';
    } else {
      btnSend.classList.remove('streaming');
      btnSendIcon.textContent = 'arrow_up';
      const hasText = promptInput.value.trim().length > 0;
      btnSend.disabled = !hasText;
      if (hasText) btnSend.classList.add('ready');
      else btnSend.classList.remove('ready');
    }
  }

  // =========================================================================
  // Newton Singularity Matrix System Prompt (Agentic Autonomous Engine)
  // =========================================================================
  const SINGULARITY_MATRIX_SYSTEM_PROMPT = `You are Newton Singularity Matrix, a 100% autonomous software engineering agent. You behave like a senior engineer who was handed a laptop with the workspace already open: nobody tells you HOW to do the work, only WHAT the outcome should be.

CORE DOCTRINE — "OUTCOME IN, RESULT OUT":
The user states an intent (build X, fix Y, improve Z, "hazlo", "implementalo", etc.). You have direct autonomous write and execution access to this workspace.
CRITICAL AGENTIC PRINCIPLE: You are an autonomous software engineer running directly inside this workspace. The user CANNOT and WILL NOT copy code from this chat, and you do not ask them to run commands. The ONLY way changes exist is if YOU create, modify, or execute them using your tools.
If you print code in markdown instead of calling write_file/create_file/edit_file, NO CODE IS SAVED and the task fails. Whenever you decide on a fix, implementation, or change, you MUST emit the <tool_call> blocks to execute it immediately.

YOUR STANDARD OPERATING CYCLE (follow it for any non-trivial task; skip exploration only when the answer is already obvious):
1. ORIENT — You receive workspace topography up front. Investigate whatever is still unknown: batch list_files / read_file / grep_search / subagent calls in parallel. Understand the codebase conventions BEFORE writing anything (naming, style, test framework, entry points).
2. PLAN — For multi-step work, immediately call update_plan with numbered steps, then re-emit it whenever scope changes. Keep working through it; do not restate it in prose every turn.
3. EXECUTE — Write and edit files directly using your tools. Batch every independent action into parallel <tool_call> blocks. Match the existing code style of the workspace.
4. VERIFY — After touching code, RUN it: the project's own test suite, build commands, linter, or syntax check via exec_bash. Read failures, fix, re-verify. Loop until green.
5. COMMIT & REPORT — If the workspace is a git repo and changes are meaningful, git commit with a conventional message (never push). Then deliver a concise final summary of what you did and verified.

HARD RULES:
- ACTION OVER WORDS: Every turn where you intend to create, modify, compile, test, or run code MUST contain the concrete <tool_call> blocks. Never explain what you are about to do without doing it in the same turn.
- NO CONVERSATIONAL CODE DUMPING: Never write implementation code as markdown prose in chat for the user to copy. All code belongs on disk via write_file / create_file / edit_file.
- FOLLOW-UP INSTRUCTIONS ("hazlo", "implementalo", "continua", "corrige"): This is an immediate command to execute. Inspect the current state, determine the required file edits and terminal commands, and emit the <tool_call> blocks in your response.
- NO REPETITION: Never restate an analysis you already produced. Skip straight to the <tool_call> or the final report.
- STUCK ON ERRORS: If the same approach fails twice, change strategy (different tool, different file, smaller step, or research via subagent/web_search).
- BATCHING (CRITICAL): Emit as MANY <tool_call> blocks as possible per response. Multiple writes, greps, independent new files → all in ONE response, executed in parallel.
- FORMAT (repeat the block per independent action):
<tool_call>
{ "tool": "<tool_name>", "parameters": { ... } }
</tool_call>
- RAW CODE PURITY: File content is 100% raw source syntax. NEVER markdown-bold code identifiers (**init** → __init__).
- ERROR HANDLING: Errors are diagnostic data. Read the compiler or runtime error, formulate the fix, and apply it with edit_file or write_file.
- <thinking> blocks: Concise, laser-focused on determining: (1) what exact files to create/edit, (2) what exact commands to run, and immediately closing the block to emit the tool calls.

Available Tools:
   - write_file: { "relativePath": "...", "content": "..." } - writes complete file content directly to disk.
   - create_file: { "relativePath": "...", "content": "..." } - create new file with initial raw code content.
   - list_files: { "subPath": ".", "recursive": false } - list files/directories in workspace.
   - read_file: { "relativePath": "...", "startLine": 1, "endLine": 100 } - read file contents.
   - edit_file: { "relativePath": "...", "old_str": "...", "new_str": "..." } - surgical replacements. old_str/new_str MUST be exact raw source strings.
   - delete_file: { "relativePath": "..." } - remove file.
   - grep_search: { "query": "..." } - ripgrep search in workspace.
   - exec_bash: { "command": "..." } - execute terminal command (install deps, run tests, run the app's scripts, syntax-check).
   - git: { "action": "status" | "diff" | "log" | "commit", "message": "...", "staged": false } - inspect repository state and commit finished work (never pushes).
   - subagent: { "task": "...", "focus": "optional path or area" } - dispatch a parallel read-only research agent. Use it to explore unfamiliar areas without polluting your own context.
   - update_plan: { "plan": "..." } - update project plan (numbered steps; keep it current).
   - update_memory: { "section": "...", "content": "..." } - store durable project knowledge for future sessions.`;

  // HTML escaping helper
  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // =========================================================================
  // Mode Switcher (Home / Chat vs Code)
  // =========================================================================
  let currentAppMode = 'chat'; // 'chat' | 'code'

  function setupModeSwitcher() {
    const btnModeHome = document.getElementById('btn-mode-home');
    const btnModeCode = document.getElementById('btn-mode-code');
    const modeSelectEl = document.getElementById('mode-select');

    btnModeHome?.addEventListener('click', () => switchAppMode('chat'));
    btnModeCode?.addEventListener('click', () => switchAppMode('code'));

    if (modeSelectEl) {
      modeSelectEl.addEventListener('change', (e) => switchAppMode(e.target.value));
    }
  }

  function switchAppMode(mode) {
    currentAppMode = mode;
    const appContainer = document.getElementById('app-container');
    const sidebarChat = document.getElementById('sidebar-chat');
    const sidebarCode = document.getElementById('sidebar-code');
    const chatWorkspaceView = document.getElementById('chat-workspace-view');
    const codeWorkspaceView = document.getElementById('code-workspace-view');

    const btnModeHome = document.getElementById('btn-mode-home');
    const btnModeCode = document.getElementById('btn-mode-code');
    const modeSelectEl = document.getElementById('mode-select');

    if (modeSelectEl) modeSelectEl.value = mode;

    if (mode === 'code') {
      if (appContainer) appContainer.setAttribute('data-mode', 'code');
      if (sidebarChat) sidebarChat.style.display = 'none';
      if (sidebarCode) sidebarCode.style.display = 'flex';
      if (chatWorkspaceView) chatWorkspaceView.style.display = 'none';
      if (codeWorkspaceView) codeWorkspaceView.style.display = 'flex';

      btnModeHome?.classList.remove('active');
      btnModeCode?.classList.add('active');

      initCodeMode();
    } else {
      if (appContainer) appContainer.setAttribute('data-mode', 'chat');
      if (sidebarChat) sidebarChat.style.display = 'flex';
      if (sidebarCode) sidebarCode.style.display = 'none';
      if (chatWorkspaceView) chatWorkspaceView.style.display = 'flex';
      if (codeWorkspaceView) codeWorkspaceView.style.display = 'none';

      btnModeHome?.classList.add('active');
      btnModeCode?.classList.remove('active');
    }
  }

  // =========================================================================
  // Code Mode Controller (Claude Code Carbon Style)
  // =========================================================================
  let isCodeModeInitialized = false;
  let codeHeaderOrb = null;
  let codeUserOrb = null;
  let codeWorkspaces = [];
  let activeWorkspace = {
    name: 'desktop',
    path: '/Volumes/Daniel/projects/Newton/desktop',
    branch: 'main'
  };
  let codeReasoningEffort = 'High'; // High, Medium, Low
  let isCodeGenerating = false;
  let codeSessionHistory = [];

  // Workspace Chats Store: Maps workspacePath -> Array<{ id, title, created_at, messages }>
  let workspaceChatsMap = {};
  try {
    const savedWsChats = localStorage.getItem('newton_code_workspace_chats');
    if (savedWsChats) {
      workspaceChatsMap = JSON.parse(savedWsChats);
      // Clean up any historical poison messages (e.g. refusal messages claiming no workspace access)
      for (const wsPath in workspaceChatsMap) {
        if (Array.isArray(workspaceChatsMap[wsPath])) {
          workspaceChatsMap[wsPath] = workspaceChatsMap[wsPath].map(chat => {
            if (Array.isArray(chat.messages)) {
              chat.messages = chat.messages.filter(msg => {
                const text = typeof msg.content === 'string' ? msg.content : '';
                return !text.includes('No tengo acceso a un workspace local') && !text.includes('Meta AI en navegador');
              });
            }
            return chat;
          });
        }
      }
    }
  } catch (e) {}

  function syncDesktopWorkspacesWithChats() {
    if (window.newtonAPI?.syncDesktopWorkspaces && Array.isArray(codeWorkspaces) && codeWorkspaces.length > 0) {
      const payload = codeWorkspaces.map(w => ({
        name: w.name,
        path: w.path,
        branch: w.branch || 'main',
        chats: (workspaceChatsMap[w.path] || []).map(c => ({
          id: c.id,
          title: c.title,
          created_at: c.created_at,
          messages: c.messages || []
        }))
      }));
      window.newtonAPI.syncDesktopWorkspaces(payload).catch(() => {});
    }
  }

  function saveWorkspaceChatsMap() {
    try {
      localStorage.setItem('newton_code_workspace_chats', JSON.stringify(workspaceChatsMap));
    } catch (e) {}
    // Primary persistence: userData/code-chats via main process (survives localStorage wipes)
    if (window.newtonAPI?.saveCodeChats) {
      for (const wsPath in workspaceChatsMap) {
        window.newtonAPI.saveCodeChats({ workspacePath: wsPath, chats: workspaceChatsMap[wsPath] }).catch(() => {});
      }
    }
    syncDesktopWorkspacesWithChats();
  }

  let currentCodeTaskId = null;

  function initCodeMode() {
    if (isCodeModeInitialized) return;
    isCodeModeInitialized = true;

    // Migrate/hydrate code chats from userData (primary) into the in-memory map
    (async () => {
      try {
        const res = await window.newtonAPI?.loadCodeChats?.();
        if (res?.success && Array.isArray(res.data)) {
          for (const entry of res.data) {
            const local = workspaceChatsMap[entry.workspacePath];
            if (!Array.isArray(local) || local.length === 0) {
              workspaceChatsMap[entry.workspacePath] = entry.chats;
            }
          }
          renderCodeWorkspacesTree();
        }
      } catch (_) {}
    })();

    setupCodeThinkingOrbs();
    setupCodeWorkspaces();
    setupCodeDashboard();
    setupCodeToolsDrawer();
    setupCodeBottomControls();
    setupCodeTaskExecution();
    setupCodeQuickNav();
  }

  // 1. Thinking Orbs in Code Mode
  function setupCodeThinkingOrbs() {
    if (typeof window.createThinkingOrb !== 'function') return;

    const headerOrbEl = document.getElementById('code-header-orb');
    if (headerOrbEl && !codeHeaderOrb) {
      codeHeaderOrb = window.createThinkingOrb(headerOrbEl, {
        state: 'orbits',
        size: 28,
        isDark: true
      });
    }

    const userOrbEl = document.getElementById('code-user-orb');
    if (userOrbEl && !codeUserOrb) {
      codeUserOrb = window.createThinkingOrb(userOrbEl, {
        state: 'globe',
        size: 18,
        isDark: true
      });
    }
  }

  // 2. Workspaces Management (Dynamic from workspaces.json)
  async function setupCodeWorkspaces() {
    const btnAddWorkspace = document.getElementById('btn-code-add-workspace');
    const btnChangeWorkspace = document.getElementById('btn-change-workspace');

    btnAddWorkspace?.addEventListener('click', handleAddCustomWorkspace);
    btnChangeWorkspace?.addEventListener('click', handleCycleWorkspace);

    await loadCodeWorkspaces();
  }

  async function loadCodeWorkspaces() {
    const treeEl = document.getElementById('code-workspaces-tree');
    if (!window.newtonAPI?.listWorkspaces || !treeEl) return;

    try {
      const res = await window.newtonAPI.listWorkspaces();
      if (res.success && Array.isArray(res.data) && res.data.length > 0) {
        codeWorkspaces = res.data;

        // Check if current active exists in list
        const match = codeWorkspaces.find(w => w.path === activeWorkspace.path || w.name === activeWorkspace.name);
        if (match) {
          activeWorkspace.name = match.name;
          activeWorkspace.path = match.path;
        } else {
          activeWorkspace.name = codeWorkspaces[0].name;
          activeWorkspace.path = codeWorkspaces[0].path;
        }

        // Fetch real git branch
        const branchRes = await window.newtonAPI.getBranch(activeWorkspace.path);
        if (branchRes?.success && branchRes.branch) {
          activeWorkspace.branch = branchRes.branch;
        }

        updateActiveWorkspacePills();
        renderCodeWorkspacesTree();
        autoInspectWorkspace(activeWorkspace.path);

        syncDesktopWorkspacesWithChats();
      }
    } catch (err) {
      console.warn('Error loading code workspaces:', err);
    }
  }

  function updateActiveWorkspacePills() {
    const nameEl = document.getElementById('active-workspace-name');
    const branchEl = document.getElementById('active-workspace-branch');
    const breadcrumbWs = document.getElementById('code-breadcrumb-ws');
    const breadcrumbBranch = document.getElementById('code-breadcrumb-branch');

    if (nameEl) nameEl.textContent = activeWorkspace.name;
    if (branchEl) branchEl.textContent = activeWorkspace.branch;
    if (breadcrumbWs) breadcrumbWs.textContent = activeWorkspace.name;
    if (breadcrumbBranch) breadcrumbBranch.textContent = activeWorkspace.branch;
  }

  // Render Workspaces Tree: CHATS divided by directory folder
  function renderCodeWorkspacesTree() {
    const treeEl = document.getElementById('code-workspaces-tree');
    if (!treeEl) return;
    const treeFrag = document.createDocumentFragment();

    codeWorkspaces.forEach(ws => {
      // Workspaces maintain their own independent local task list
      if (!workspaceChatsMap[ws.path]) {
        workspaceChatsMap[ws.path] = [];
      }

      const folderDiv = document.createElement('div');
      folderDiv.className = 'code-workspace-folder';

      const isActiveWs = ws.path === activeWorkspace.path;
      folderDiv.innerHTML = `
        <div class="code-folder-header ${isActiveWs ? 'active' : ''}">
          <div class="code-folder-left">
            <i class="f7-icons code-folder-chevron ${isActiveWs ? 'expanded' : ''}">${isActiveWs ? 'chevron_down' : 'chevron_right'}</i>
            <span class="code-folder-name" title="${escapeHtml(ws.path)}">${escapeHtml(ws.name)}</span>
          </div>
          <div class="code-folder-actions">
            <button class="btn-folder-action btn-add-chat-quick" title="Nueva tarea en ${escapeHtml(ws.name)}"><i class="f7-icons">plus</i></button>
            ${codeWorkspaces.length > 1 ? `<button class="btn-folder-action btn-remove-ws-quick" title="Remover workspace"><i class="f7-icons">trash</i></button>` : ''}
          </div>
        </div>
        <div class="code-folder-chats" style="display: ${isActiveWs ? 'flex' : 'none'};"></div>
      `;

      const header = folderDiv.querySelector('.code-folder-header');
      const chevron = folderDiv.querySelector('.code-folder-chevron');
      const chatsContainer = folderDiv.querySelector('.code-folder-chats');
      const btnAddChatQuick = folderDiv.querySelector('.btn-add-chat-quick');
      const btnRemoveWsQuick = folderDiv.querySelector('.btn-remove-ws-quick');

      // Populate chats inside this directory folder
      const renderChatsInFolder = () => {
        const chats = workspaceChatsMap[ws.path] || [];
        const innerFrag = document.createDocumentFragment();

        // Single clean "+ Nueva tarea" row
        const newTaskRow = document.createElement('div');
        newTaskRow.className = 'code-chat-tree-item new-prompt';
        newTaskRow.innerHTML = `
          <i class="f7-icons">plus</i>
          <span class="code-chat-title">Nueva tarea</span>
        `;
        newTaskRow.addEventListener('click', (e) => {
          e.stopPropagation();
          selectWorkspace(ws);
          startNewCodeTask();
        });
        innerFrag.appendChild(newTaskRow);

        chats.forEach(chat => {
          const chatRow = document.createElement('div');
          chatRow.className = `code-chat-tree-item ${chat.id === currentCodeTaskId ? 'active' : ''}`;
          chatRow.setAttribute('data-chat-id', chat.id);

          let timeStr = '';
          if (chat.created_at) {
            const d = new Date(chat.created_at < 1e11 ? chat.created_at * 1000 : chat.created_at);
            const now = new Date();
            const diffMin = Math.round((now - d) / (1000 * 60));
            if (diffMin < 60) timeStr = `${Math.max(1, diffMin)}m`;
            else if (diffMin < 1440) timeStr = `${Math.round(diffMin / 60)}h`;
            else timeStr = `${Math.round(diffMin / 1440)}d`;
          }

          chatRow.innerHTML = `
            <i class="f7-icons">chat_bubble_text</i>
            <span class="code-chat-title" title="${escapeHtml(chat.title)}">${escapeHtml(chat.title)}</span>
            ${timeStr ? `<span class="code-chat-time">${timeStr}</span>` : ''}
            <button class="btn-delete-code-chat" title="Eliminar tarea"><i class="f7-icons">trash</i></button>
          `;

          chatRow.addEventListener('click', (e) => {
            if (e.target.closest('.btn-delete-code-chat')) return;
            e.stopPropagation();
            selectWorkspace(ws);
            openCodeChat(ws.path, chat.id);
          });

          const btnDelChat = chatRow.querySelector('.btn-delete-code-chat');
          btnDelChat?.addEventListener('click', (e) => {
            e.stopPropagation();
            if (workspaceChatsMap[ws.path]) {
              workspaceChatsMap[ws.path] = workspaceChatsMap[ws.path].filter(c => c.id !== chat.id);
              saveWorkspaceChatsMap();
              if (currentCodeTaskId === chat.id) {
                startNewCodeTask();
              }
              renderCodeWorkspacesTree();
            }
          });

          innerFrag.appendChild(chatRow);
        });
        chatsContainer.replaceChildren(innerFrag);
      };

      renderChatsInFolder();

      // Click folder header to select workspace and collapse/expand chats
      header.addEventListener('click', (e) => {
        if (e.target.closest('.btn-folder-action')) return;
        selectWorkspace(ws);

        const isOpened = chatsContainer.style.display !== 'none';
        if (isOpened) {
          chatsContainer.style.display = 'none';
          chevron.classList.remove('expanded');
          chevron.textContent = 'chevron_right';
        } else {
          chatsContainer.style.display = 'flex';
          chevron.classList.add('expanded');
          chevron.textContent = 'chevron_down';
        }
      });

      // Quick add task in this workspace
      btnAddChatQuick?.addEventListener('click', (e) => {
        e.stopPropagation();
        selectWorkspace(ws);
        startNewCodeTask();
      });

      // Remove workspace directory
      btnRemoveWsQuick?.addEventListener('click', async (e) => {
        e.stopPropagation();
        if (confirm(`¿Remover workspace "${ws.name}" (${ws.path}) de Newton Code?`)) {
          await window.newtonAPI.removeWorkspace(ws.path);
          await loadCodeWorkspaces();
        }
      });

      treeFrag.appendChild(folderDiv);
    });
    treeEl.replaceChildren(treeFrag);
  }

  async function selectWorkspace(ws) {
    activeWorkspace.name = ws.name;
    activeWorkspace.path = ws.path;
    try {
      const bRes = await window.newtonAPI?.getBranch(ws.path);
      if (bRes?.success && bRes.branch) activeWorkspace.branch = bRes.branch;
    } catch (e) {}
    updateActiveWorkspacePills();

    // Highlight folder header
    document.querySelectorAll('.code-folder-header').forEach(h => {
      const isThis = h.querySelector('.code-folder-name')?.textContent === ws.name;
      h.classList.toggle('active', isThis);
      const icon = h.querySelector('.f7-icons:not(.code-folder-chevron)');
      if (icon) icon.textContent = isThis ? 'folder_fill' : 'folder';
    });

    // Proactive Auto-Inspection of the workspace
    autoInspectWorkspace(ws.path);
  }

  // Auto-Inspect & Index Workspace files proactively in background
  let workspaceMemoryCache = {};

  async function autoInspectWorkspace(workspacePath) {
    if (!workspacePath || !window.newtonAPI?.getWorkspaceSummary) return;
    try {
      const sumRes = await window.newtonAPI.getWorkspaceSummary(workspacePath);
      if (sumRes?.success && sumRes.data) {
        workspaceMemoryCache[workspacePath] = sumRes.data;

        // Proactively scan file tree to depth 3
        const listRes = await window.newtonAPI.listFiles({
          workspacePath,
          maxDepth: 3,
          recursive: true
        });

        if (listRes?.success && Array.isArray(listRes.data)) {
          workspaceMemoryCache[workspacePath].allFiles = listRes.data;
        }

        // Auto-update breadcrumbs and indicator
        const statusPill = document.querySelector('.code-status-pill span:last-child');
        if (statusPill) {
          statusPill.textContent = `Indexed (${workspaceMemoryCache[workspacePath].allFiles?.length || sumRes.data.files?.length || 0} files)`;
        }
      }
    } catch (e) {
      console.warn('Auto-inspect workspace error:', e);
    }
  }

  function startNewCodeTask() {
    currentCodeTaskId = null;
    codeSessionHistory = [];

    const dashboardCard = document.getElementById('code-dashboard-card');
    const messagesStream = document.getElementById('code-messages-stream');
    const codeTaskInput = document.getElementById('code-task-input');
    const taskBreadcrumb = document.getElementById('code-breadcrumb-task');
    const taskSep = document.getElementById('code-breadcrumb-task-sep');

    if (taskBreadcrumb) taskBreadcrumb.style.display = 'none';
    if (taskSep) taskSep.style.display = 'none';

    if (messagesStream) {
      messagesStream.replaceChildren();
      messagesStream.style.display = 'none';
    }
    if (dashboardCard) dashboardCard.style.display = 'flex';

    document.querySelectorAll('.code-chat-tree-item').forEach(el => el.classList.remove('active'));

    if (codeTaskInput) {
      codeTaskInput.value = '';
      codeTaskInput.focus();
    }
  }

  function openCodeChat(wsPath, chatId) {
    currentCodeTaskId = chatId;
    const chats = workspaceChatsMap[wsPath] || [];
    const chat = chats.find(c => c.id === chatId);
    if (!chat) return;

    codeSessionHistory = Array.isArray(chat.messages) ? [...chat.messages] : [];

    const dashboardCard = document.getElementById('code-dashboard-card');
    const messagesStream = document.getElementById('code-messages-stream');
    const taskBreadcrumb = document.getElementById('code-breadcrumb-task');
    const taskSep = document.getElementById('code-breadcrumb-task-sep');

    if (taskBreadcrumb) {
      taskBreadcrumb.textContent = chat.title || 'Tarea';
      taskBreadcrumb.style.display = 'inline';
    }
    if (taskSep) taskSep.style.display = 'inline';

    if (dashboardCard) dashboardCard.style.display = 'none';
    if (messagesStream) {
      messagesStream.replaceChildren();
      messagesStream.style.display = 'flex';
    }

    // Highlight active chat row
    document.querySelectorAll('.code-chat-tree-item').forEach(el => {
      el.classList.toggle('active', el.getAttribute('data-chat-id') === chatId);
    });

    if (codeSessionHistory.length > 0) {
      codeSessionHistory.forEach(msg => {
        if (msg.role === 'user') {
          const content = String(msg.content || '');
          if (content.startsWith('<tool_response') || content.startsWith('<tool_results') || content.startsWith('<system_gate') || content.startsWith('<system_notice') || content.startsWith('[TOOL_RESULT:')) {
            return; // Internal execution messages
          }
          // If message contains the system prompt prefix, extract the clean user intent
          let displayUserText = content;
          if (content.includes('USER INTENT:')) {
            const match = content.match(/USER INTENT:\s*([\s\S]*?)(?:\n\nYou are working autonomous|\n\[ACTIVE WORKSPACE|$)/i);
            displayUserText = match ? match[1].trim() : chat.title;
          } else if (content.includes('You are Newton Singularity Matrix')) {
            displayUserText = chat.title;
          }
          appendCodeMessage('user', displayUserText);
        } else if (msg.role === 'assistant') {
          const rawAssistantText = String(msg.content || '');
          
          // Recreate tool cards that were executed in this assistant turn
          const toolMatches = [...rawAssistantText.matchAll(/<tool_call>([\s\S]*?)<\/tool_call>/g)];
          for (const tm of toolMatches) {
            try {
              const parsed = JSON.parse(tm[1].trim());
              if (parsed && parsed.tool) {
                const card = renderToolCard(parsed.tool, parsed.parameters || {});
                card.setStatus('success', 'Executed');
              }
            } catch (_) {}
          }

          // If there is assistant prose or reasoning, display the bubble
          const cleanProse = stripInternalAgentMarkup(rawAssistantText);
          const hasThinking = rawAssistantText.includes('<thinking>');

          if (cleanProse || hasThinking) {
            const botObj = createCodeAssistantBubble();
            messagesStream.appendChild(botObj.container);
            updateCodeAssistantBubbleImmediate(botObj, rawAssistantText);
          }
        }
      });
      scrollCodeToBottom();
    } else {
      // Cloud chat seeded with no local history loaded yet
      appendCodeMessage('user', chat.title);
      const botObj = createCodeAssistantBubble();
      messagesStream.appendChild(botObj.container);
      updateCodeAssistantBubble(botObj, `Sesión "${chat.title}" lista en workspace **${activeWorkspace.name}**.\nEscribe tu próxima consulta abajo.`);
      scrollCodeToBottom();
    }

    const codeTaskInput = document.getElementById('code-task-input');
    if (codeTaskInput) codeTaskInput.focus();
  }

  async function handleAddCustomWorkspace() {
    if (!window.newtonAPI?.chooseFolder) return;
    try {
      const res = await window.newtonAPI.chooseFolder();
      if (res.success && res.data) {
        const newFolder = res.data;
        await window.newtonAPI.addWorkspace(newFolder.path);
        await loadCodeWorkspaces();
        activeWorkspace.name = newFolder.name;
        activeWorkspace.path = newFolder.path;
        const bRes = await window.newtonAPI.getBranch(newFolder.path);
        if (bRes?.success) activeWorkspace.branch = bRes.branch;
        updateActiveWorkspacePills();
        renderCodeWorkspacesTree();
      }
    } catch (e) {
      console.warn('Error adding custom workspace:', e);
    }
  }

  function handleCycleWorkspace() {
    if (codeWorkspaces.length <= 1) return;
    const currIdx = codeWorkspaces.findIndex(w => w.name === activeWorkspace.name);
    const nextIdx = (currIdx + 1) % codeWorkspaces.length;
    const nextWs = codeWorkspaces[nextIdx];
    selectWorkspace(nextWs);
  }

  // 3. Claude Code Dashboard Metrics & 52x7 Heatmap (REAL GATEWAY DATA)
  function setupCodeDashboard() {
    setupDashboardTabs();
    setupTimeFilterPills();
    populateDashboardMetrics();
    renderContributionHeatmap();
  }

  function setupDashboardTabs() {
    const btnOverview = document.getElementById('btn-tab-overview');
    const btnModels = document.getElementById('btn-tab-models');

    btnOverview?.addEventListener('click', () => {
      btnOverview.classList.add('active');
      btnModels?.classList.remove('active');
      renderContributionHeatmap();
    });

    btnModels?.addEventListener('click', () => {
      btnModels.classList.add('active');
      btnOverview?.classList.remove('active');
      renderModelBreakdown();
    });
  }

  function setupTimeFilterPills() {
    const filterPills = document.querySelectorAll('.code-filter-pill');
    filterPills.forEach(pill => {
      pill.addEventListener('click', () => {
        filterPills.forEach(p => p.classList.remove('active'));
        pill.classList.add('active');
        const range = pill.getAttribute('data-range');
        updateMetricsForRange(range);
      });
    });
  }

  // Compute 8 metrics cards using 100% REAL DATA from gateway (/auth/me and /nwtn/chats)
  function populateDashboardMetrics() {
    const sessionsEl = document.getElementById('metric-sessions');
    const messagesEl = document.getElementById('metric-messages');
    const tokensEl = document.getElementById('metric-tokens');
    const activeDaysEl = document.getElementById('metric-active-days');
    const streakEl = document.getElementById('metric-streak');
    const longestStreakEl = document.getElementById('metric-longest-streak');
    const peakHourEl = document.getElementById('metric-peak-hour');
    const favModelEl = document.getElementById('metric-fav-model');

    const chats = window.loadedChats || [];
    const profile = window.userProfileData || null;

    // 1. Sessions: real count of cloud chat sessions
    const totalSessions = chats.length;
    if (sessionsEl) sessionsEl.textContent = totalSessions;

    // 2. Messages: from profile weekly quota or sum of message_count
    let totalMsgs = 0;
    if (profile?.quotas?.msgs_week?.used != null && profile.quotas.msgs_week.used > 0) {
      totalMsgs = profile.quotas.msgs_week.used;
    } else {
      totalMsgs = chats.reduce((acc, c) => acc + (c.message_count || 1), 0);
    }
    if (messagesEl) messagesEl.textContent = totalMsgs;

    // 3. Tokens: from profile weekly tokens or estimated from real message count
    let totalTokens = 0;
    if (profile?.quotas?.tokens_week?.used != null && profile.quotas.tokens_week.used > 0) {
      totalTokens = profile.quotas.tokens_week.used;
    } else {
      totalTokens = totalMsgs * 1250;
    }
    if (tokensEl) {
      tokensEl.textContent = totalTokens >= 1000000 
        ? `${(totalTokens / 1000000).toFixed(1)}M` 
        : (totalTokens >= 1000 ? `${Math.round(totalTokens / 1000)}k` : `${totalTokens}`);
    }

    // 4. Active Days, Hour Distribution & Model Distribution
    const activeDatesSet = new Set();
    const hourCounts = new Array(24).fill(0);
    const modelCounts = {};

    chats.forEach(c => {
      const ts = c.created_at || c.updated_at;
      if (ts) {
        const d = new Date(ts < 1e11 ? ts * 1000 : ts);
        if (!isNaN(d.getTime())) {
          activeDatesSet.add(d.toISOString().split('T')[0]);
          hourCounts[d.getHours()]++;
        }
      }
      const m = c.model || 'Singularity-Matrix';
      modelCounts[m] = (modelCounts[m] || 0) + 1;
    });

    const activeDaysCount = activeDatesSet.size || (totalSessions > 0 ? 1 : 0);
    if (activeDaysEl) activeDaysEl.textContent = activeDaysCount;

    // 5. Streaks (Current and Longest) from actual dates
    const sortedDates = Array.from(activeDatesSet).sort();
    let currentStreak = 0;
    let longestStreak = 0;

    if (sortedDates.length > 0) {
      const todayStr = new Date().toISOString().split('T')[0];
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      const yesterdayStr = yesterday.toISOString().split('T')[0];

      let checkDate = new Date();
      if (!activeDatesSet.has(todayStr) && activeDatesSet.has(yesterdayStr)) {
        checkDate = yesterday;
      }

      while (true) {
        const str = checkDate.toISOString().split('T')[0];
        if (activeDatesSet.has(str)) {
          currentStreak++;
          checkDate.setDate(checkDate.getDate() - 1);
        } else {
          break;
        }
      }

      let tempStreak = 1;
      for (let i = 1; i < sortedDates.length; i++) {
        const prev = new Date(sortedDates[i - 1]);
        const curr = new Date(sortedDates[i]);
        const diffDays = Math.round((curr - prev) / (1000 * 60 * 60 * 24));
        if (diffDays === 1) {
          tempStreak++;
        } else if (diffDays > 1) {
          longestStreak = Math.max(longestStreak, tempStreak);
          tempStreak = 1;
        }
      }
      longestStreak = Math.max(longestStreak, tempStreak, currentStreak);
    }

    if (streakEl) streakEl.textContent = `${currentStreak}d`;
    if (longestStreakEl) longestStreakEl.textContent = `${longestStreak}d`;

    // 6. Peak Hour
    let maxHourIdx = -1;
    let maxHourCount = 0;
    for (let h = 0; h < 24; h++) {
      if (hourCounts[h] > maxHourCount) {
        maxHourCount = hourCounts[h];
        maxHourIdx = h;
      }
    }
    if (peakHourEl) {
      peakHourEl.textContent = maxHourIdx >= 0 ? `${String(maxHourIdx).padStart(2, '0')}:00` : '—';
    }

    // 7. Favorite Model
    let favModel = 'Singularity-Matrix';
    let maxModelCount = 0;
    for (const [mod, cnt] of Object.entries(modelCounts)) {
      if (cnt > maxModelCount) {
        maxModelCount = cnt;
        favModel = mod;
      }
    }
    if (favModelEl) favModelEl.textContent = favModel;
  }

  function updateMetricsForRange(range) {
    const sessionsEl = document.getElementById('metric-sessions');
    const messagesEl = document.getElementById('metric-messages');
    const tokensEl = document.getElementById('metric-tokens');

    const allChats = window.loadedChats || [];
    let filteredChats = allChats;

    const now = Date.now();
    if (range === '7d') {
      const cutoff = (now - 7 * 86400 * 1000) / 1000;
      filteredChats = allChats.filter(c => (c.created_at || c.updated_at || 0) >= cutoff);
    } else if (range === '30d') {
      const cutoff = (now - 30 * 86400 * 1000) / 1000;
      filteredChats = allChats.filter(c => (c.created_at || c.updated_at || 0) >= cutoff);
    }

    const s = filteredChats.length;
    const m = filteredChats.reduce((acc, c) => acc + (c.message_count || 1), 0);
    const t = m * 1250;

    if (sessionsEl) sessionsEl.textContent = s;
    if (messagesEl) messagesEl.textContent = m;
    if (tokensEl) {
      tokensEl.textContent = t >= 1000000 
        ? `${(t / 1000000).toFixed(1)}M` 
        : (t >= 1000 ? `${Math.round(t / 1000)}k` : `${t}`);
    }
  }

  // 52x7 Heatmap mapped to real chat timestamps
  function renderContributionHeatmap() {
    const grid = document.getElementById('code-heatmap-grid');
    if (!grid) return;
    grid.replaceChildren();

    const chats = window.loadedChats || [];
    const dateCounts = {};

    chats.forEach(c => {
      const ts = c.created_at || c.updated_at;
      if (ts) {
        const d = new Date(ts < 1e11 ? ts * 1000 : ts);
        if (!isNaN(d.getTime())) {
          const key = d.toISOString().split('T')[0];
          dateCounts[key] = (dateCounts[key] || 0) + (c.message_count || 1);
        }
      }
    });

    // 52 columns x 7 rows = 364 calendar days ending today
    const totalDays = 52 * 7;
    const today = new Date();
    const cells = [];

    for (let i = totalDays - 1; i >= 0; i--) {
      const d = new Date();
      d.setDate(today.getDate() - i);
      const dateKey = d.toISOString().split('T')[0];
      const count = dateCounts[dateKey] || 0;

      let level = 0;
      if (count >= 10) level = 4;
      else if (count >= 5) level = 3;
      else if (count >= 2) level = 2;
      else if (count >= 1) level = 1;

      cells.push({
        date: dateKey,
        count: count,
        level: level
      });
    }

    cells.forEach(cell => {
      const div = document.createElement('div');
      div.className = `heatmap-cell ${cell.level > 0 ? `level-${cell.level}` : ''}`;
      div.title = `${cell.date}: ${cell.count === 0 ? 'Sin actividad' : `${cell.count} mensaje(s) / tarea(s)`}`;
      grid.appendChild(div);
    });
  }

  function renderModelBreakdown() {
    const grid = document.getElementById('code-heatmap-grid');
    if (!grid) return;

    const chats = window.loadedChats || [];
    let matrixCount = 0;
    let singularityCount = 0;

    chats.forEach(c => {
      if (c.model === 'Singularity-Matrix') matrixCount++;
      else singularityCount++;
    });

    const total = matrixCount + singularityCount || 1;
    const matrixPct = ((matrixCount / total) * 100).toFixed(1);
    const singPct = (100 - parseFloat(matrixPct)).toFixed(1);

    grid.innerHTML = `
      <div style="grid-column: 1 / -1; display: flex; flex-direction: column; gap: 8px; padding: 6px 0;">
        <div style="display: flex; justify-content: space-between; font-size: 12px; color: #aaa;">
          <span>Newton Singularity-Matrix (Programming Specialist)</span>
          <span style="color: #4ed187; font-weight: 600;">${matrixPct}%</span>
        </div>
        <div style="height: 6px; border-radius: 3px; background-color: #262626; overflow: hidden;">
          <div style="width: ${matrixPct}%; height: 100%; background-color: #4ed187;"></div>
        </div>
        <div style="display: flex; justify-content: space-between; font-size: 12px; color: #aaa; margin-top: 4px;">
          <span>Newton Singularity (Architect & Generalist)</span>
          <span style="color: #a7c080; font-weight: 600;">${singPct}%</span>
        </div>
        <div style="height: 6px; border-radius: 3px; background-color: #262626; overflow: hidden;">
          <div style="width: ${singPct}%; height: 100%; background-color: #a7c080;"></div>
        </div>
      </div>
    `;
  }

  // 4. Tools Drawer (Files Explorer & Terminal)
  function setupCodeToolsDrawer() {
    const btnCloseDrawer = document.getElementById('btn-close-drawer');
    const btnOpenFiles = document.getElementById('btn-open-files-drawer');
    const btnOpenTerm = document.getElementById('btn-open-terminal-drawer');

    btnCloseDrawer?.addEventListener('click', closeToolsDrawer);
    btnOpenFiles?.addEventListener('click', () => openFilesDrawer(false));
    btnOpenTerm?.addEventListener('click', openTerminalDrawer);
  }

  function closeToolsDrawer() {
    const drawer = document.getElementById('code-tools-drawer');
    if (drawer) drawer.style.display = 'none';
  }

  function openFilesDrawer(showNewFileForm = false) {
    const drawer = document.getElementById('code-tools-drawer');
    const titleEl = document.getElementById('tools-drawer-title');
    const bodyEl = document.getElementById('tools-drawer-body');
    if (!drawer || !bodyEl) return;

    titleEl.textContent = `Archivos · ${activeWorkspace.name}`;
    drawer.style.display = 'flex';
    bodyEl.innerHTML = '<div style="color: #888;">Cargando archivos...</div>';

    window.newtonAPI?.listFiles({ workspacePath: activeWorkspace.path }).then(res => {
      bodyEl.replaceChildren();

      // New File creation bar
      const newFileBar = document.createElement('div');
      newFileBar.style.display = 'flex';
      newFileBar.style.gap = '6px';
      newFileBar.style.marginBottom = '12px';
      newFileBar.innerHTML = `
        <input type="text" placeholder="nombre-archivo.js" class="drawer-term-input" id="input-new-file-name" style="flex: 1;">
        <button class="btn-exec-action" id="btn-create-file-submit" style="white-space: nowrap;"><i class="f7-icons" style="font-size: 11px;">plus</i> Crear</button>
      `;
      bodyEl.appendChild(newFileBar);

      const inputNewFile = newFileBar.querySelector('#input-new-file-name');
      const btnCreate = newFileBar.querySelector('#btn-create-file-submit');

      const doCreate = async () => {
        const fName = inputNewFile.value.trim();
        if (!fName) return;
        btnCreate.disabled = true;
        try {
          const cRes = await window.newtonAPI.createFile({
            workspacePath: activeWorkspace.path,
            relativePath: fName,
            content: ''
          });
          if (cRes?.success) {
            openFileEditorInDrawer(activeWorkspace.path, fName);
            loadCodeWorkspaces();
          } else {
            alert('Error al crear: ' + (cRes?.error || 'Falló'));
          }
        } finally {
          btnCreate.disabled = false;
        }
      };

      btnCreate.addEventListener('click', doCreate);
      inputNewFile.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') doCreate();
      });

      if (showNewFileForm) inputNewFile.focus();

      // Files listing
      if (res?.success && Array.isArray(res.data)) {
        const listContainer = document.createElement('div');
        listContainer.style.display = 'flex';
        listContainer.style.flexDirection = 'column';
        listContainer.style.gap = '4px';

        res.data.forEach(file => {
          const item = document.createElement('div');
          item.className = 'code-subitem-row';
          item.innerHTML = `
            <i class="f7-icons">${file.isDirectory ? 'folder' : 'doc_text'}</i>
            <span style="flex: 1;">${escapeHtml(file.name)}</span>
          `;
          item.addEventListener('click', () => {
            if (!file.isDirectory) {
              openFileEditorInDrawer(activeWorkspace.path, file.relativePath);
            }
          });
          listContainer.appendChild(item);
        });

        bodyEl.appendChild(listContainer);
      }
    });
  }

  async function openFileEditorInDrawer(wsPath, relPath) {
    const drawer = document.getElementById('code-tools-drawer');
    const titleEl = document.getElementById('tools-drawer-title');
    const bodyEl = document.getElementById('tools-drawer-body');
    if (!drawer || !bodyEl) return;

    titleEl.textContent = `Editar: ${relPath}`;
    drawer.style.display = 'flex';
    bodyEl.innerHTML = '<div style="color: #888;">Cargando contenido...</div>';

    try {
      const res = await window.newtonAPI.readFile({ workspacePath: wsPath, relativePath: relPath });
      const content = res.success ? res.data : '';

      bodyEl.innerHTML = `
        <div class="drawer-file-editor">
          <div class="drawer-editor-path">${escapeHtml(relPath)}</div>
          <textarea class="drawer-editor-textarea" id="drawer-editor-code"></textarea>
          <div class="drawer-editor-actions">
            <button class="btn-exec-action" id="btn-editor-back" style="background: none; border-color: #444;">← Volver</button>
            <button class="btn-exec-action" id="btn-editor-delete" style="color: #e67e80; border-color: #552222;">Eliminar</button>
            <button class="btn-exec-action" id="btn-editor-save" style="background-color: #276140; border-color: #388e5d; color: #fff;">Guardar</button>
          </div>
          <div id="drawer-editor-status" style="font-size: 11px; color: #888; text-align: right;"></div>
        </div>
      `;

      const codeArea = bodyEl.querySelector('#drawer-editor-code');
      const btnBack = bodyEl.querySelector('#btn-editor-back');
      const btnDelete = bodyEl.querySelector('#btn-editor-delete');
      const btnSave = bodyEl.querySelector('#btn-editor-save');
      const statusEl = bodyEl.querySelector('#drawer-editor-status');

      codeArea.value = content;

      btnBack.addEventListener('click', () => openFilesDrawer(false));

      btnSave.addEventListener('click', async () => {
        btnSave.disabled = true;
        statusEl.textContent = 'Guardando...';
        statusEl.style.color = '#e5c07b';
        try {
          const wRes = await window.newtonAPI.writeFile({
            workspacePath: wsPath,
            relativePath: relPath,
            content: codeArea.value
          });
          if (wRes?.success) {
            statusEl.textContent = '✓ Guardado exitosamente';
            statusEl.style.color = '#a7c080';
          } else {
            statusEl.textContent = 'Error: ' + (wRes?.error || 'Falló al guardar');
            statusEl.style.color = '#e67e80';
          }
        } finally {
          btnSave.disabled = false;
        }
      });

      btnDelete.addEventListener('click', async () => {
        if (confirm(`¿Eliminar definitivamente "${relPath}"?`)) {
          btnDelete.disabled = true;
          try {
            const dRes = await window.newtonAPI.deleteFile({
              workspacePath: wsPath,
              relativePath: relPath
            });
            if (dRes?.success) {
              openFilesDrawer(false);
              loadCodeWorkspaces();
            } else {
              alert('Error al eliminar: ' + (dRes?.error || 'Falló'));
            }
          } finally {
            btnDelete.disabled = false;
          }
        }
      });
    } catch (err) {
      bodyEl.innerHTML = `<div style="color: #e67e80;">Error al abrir archivo: ${escapeHtml(err.message)}</div>`;
    }
  }

  function openTerminalDrawer() {
    const drawer = document.getElementById('code-tools-drawer');
    const titleEl = document.getElementById('tools-drawer-title');
    const bodyEl = document.getElementById('tools-drawer-body');
    if (!drawer || !bodyEl) return;

    titleEl.textContent = `Terminal · ${activeWorkspace.name}`;
    drawer.style.display = 'flex';

    bodyEl.innerHTML = `
      <div class="drawer-terminal-container">
        <!-- Quick command pills -->
        <div style="display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 8px;">
          <button class="btn-exec-action term-pill" data-cmd="git status">git status</button>
          <button class="btn-exec-action term-pill" data-cmd="git branch -a">git branch</button>
          <button class="btn-exec-action term-pill" data-cmd="ls -la">ls -la</button>
          <button class="btn-exec-action term-pill" data-cmd="pwd">pwd</button>
        </div>
        <div class="drawer-term-output" id="drawer-term-output">Newton Singularity Terminal [v2.4]
Directorio activo: ${escapeHtml(activeWorkspace.path)}
Listo para comandos bash...
</div>
        <div class="drawer-term-input-row">
          <input type="text" class="drawer-term-input" id="drawer-term-input" placeholder="Escribe un comando bash (ej. git status)...">
          <button class="btn-exec-action" id="btn-term-run">Ejecutar</button>
        </div>
      </div>
    `;

    const termOutput = bodyEl.querySelector('#drawer-term-output');
    const termInput = bodyEl.querySelector('#drawer-term-input');
    const btnRun = bodyEl.querySelector('#btn-term-run');

    const executeCmd = async (command) => {
      const cmd = command || termInput.value.trim();
      if (!cmd) return;
      termInput.value = '';

      termOutput.textContent += `\n$ ${cmd}\n`;
      termOutput.scrollTop = termOutput.scrollHeight;

      try {
        btnRun.disabled = true;
        const res = await window.newtonAPI.execBash({
          workspacePath: activeWorkspace.path,
          command: cmd
        });

        if (res.stdout) termOutput.textContent += res.stdout;
        if (res.stderr) termOutput.textContent += `\n${res.stderr}`;
        if (!res.stdout && !res.stderr) termOutput.textContent += `[Comando completado sin salida (exit code: ${res.exitCode})]\n`;
      } catch (err) {
        termOutput.textContent += `Error ejecutando comando: ${err.message}\n`;
      } finally {
        btnRun.disabled = false;
        termOutput.scrollTop = termOutput.scrollHeight;
        termInput.focus();
      }
    };

    btnRun.addEventListener('click', () => executeCmd());
    termInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') executeCmd();
    });

    bodyEl.querySelectorAll('.term-pill').forEach(pill => {
      pill.addEventListener('click', () => {
        executeCmd(pill.getAttribute('data-cmd'));
      });
    });

    termInput.focus();
  }

  // 5. Reasoning Effort Selector & Bottom Controls
  function setupCodeBottomControls() {
    const btnToggleEffort = document.getElementById('btn-toggle-effort');
    const labelEffortVal = document.getElementById('label-effort-val');
    const effortIndicator = document.getElementById('effort-circle-indicator');

    const effortLevels = ['High', 'Medium', 'Low'];
    const effortSymbols = { High: '◯', Medium: '◑', Low: '◔' };

    btnToggleEffort?.addEventListener('click', () => {
      const currIdx = effortLevels.indexOf(codeReasoningEffort);
      const nextIdx = (currIdx + 1) % effortLevels.length;
      codeReasoningEffort = effortLevels[nextIdx];

      if (labelEffortVal) labelEffortVal.textContent = codeReasoningEffort;
      if (effortIndicator) effortIndicator.textContent = effortSymbols[codeReasoningEffort];
    });
  }

  // --- Agent permissions & session tracking --------------------------------

  // Files created by the agent in the current session never need re-approval.
  const sessionCreatedFiles = new Set();
  // Per-task audit trail for the end-of-task summary card.
  let sessionAuditTrail = { files: new Set(), commands: [] };

  function isBypassPermissions() {
    const check = document.getElementById('check-bypass-permissions');
    return !check || check.checked;
  }

  // Renders an approval card and resolves when the user answers.
  function requestToolApproval(toolName, params, previewText) {
    return new Promise((resolve) => {
      const messagesStream = document.getElementById('code-messages-stream');
      const card = document.createElement('div');
      card.className = 'code-approval-card';
      card.innerHTML = `
        <div class="code-approval-header">
          <i class="f7-icons code-action-icon">lock_shield</i>
          <span>Confirmación requerida — <strong>${escapeHtml(toolName)}</strong></span>
        </div>
        ${previewText ? `<pre class="code-approval-preview">${escapeHtml(previewText)}</pre>` : ''}
        <div class="code-approval-actions">
          <button class="code-approval-btn approve">Permitir</button>
          <button class="code-approval-btn deny">Denegar</button>
        </div>
      `;
      const done = (allowed) => {
        card.querySelectorAll('button').forEach(b => (b.disabled = true));
        card.classList.add(allowed ? 'approved' : 'denied');
        resolve(allowed);
        scrollCodeToBottom();
      };
      card.querySelector('.approve')?.addEventListener('click', () => done(true));
      card.querySelector('.deny')?.addEventListener('click', () => done(false));
      messagesStream?.appendChild(card);
      scrollCodeToBottom();
    });
  }

  // Gate a destructive tool behind user approval when bypass is off.
  async function gateTool(toolName, params, preview) {
    if (isBypassPermissions()) return true;
    return requestToolApproval(toolName, params, preview);
  }

  // Read-only research subagent: explores the workspace without write access
  // and returns a summary to the main agent.
  const READONLY_TOOLS = new Set(['list_files', 'read_file', 'grep_search', 'web_search']);

  async function runReadonlySubagent(task, focus, wsPath) {
    const SUB_PROMPT = `You are a read-only research subagent inside workspace "${wsPath}". You may ONLY use these tools: list_files, read_file, grep_search, web_search. You cannot write, edit, delete or execute anything.
TASK: ${task}${focus ? `\nFOCUS AREA: ${focus}` : ''}
Work step by step (max 6 steps). When you have enough information, stop calling tools and output a concise findings report (max 300 words) with file paths and line references.`;

    let prompt = SUB_PROMPT;
    for (let step = 0; step < 6; step++) {
      let response;
      try {
        response = await window.newtonAPI.sendMessage({ prompt, model: 'Singularity-Matrix', history: [], isGhost: true });
      } catch (e) {
        return { error: `Subagent connection error: ${e.message}` };
      }
      if (!response.success) return { error: `Subagent failed: ${response.error}` };

      const reply = response.data?.reply || '';
      const toolCall = reply.match(/<tool_call>([\s\S]*?)<\/tool_call>/);
      if (!toolCall) {
        return { success: true, summary: reply.replace(/<thinking>[\s\S]*?<\/thinking>/g, '').trim() };
      }

      let parsed = null;
      try { parsed = JSON.parse(toolCall[1].trim()); } catch (_) {}
      if (!parsed || !READONLY_TOOLS.has(parsed.tool)) {
        prompt = `<tool_response>\n[Denied: subagents are read-only. Allowed tools: ${[...READONLY_TOOLS].join(', ')}]\n</tool_response>\n\nContinue researching or deliver your findings report now.`;
        continue;
      }

      let result;
      try {
        result = await executeMatrixTool(parsed.tool, parsed.parameters || {}, wsPath);
      } catch (e) {
        result = { error: e.message };
      }
      const out = typeof result === 'string' ? result : (result.content || result.files || result.stdout || result.message || JSON.stringify(result));
      prompt = `<tool_response tool="${parsed.tool}">\n${String(out).slice(0, 8000)}\n</tool_response>\n\nContinue researching, or deliver your findings report now.`;
    }
    return { success: true, summary: 'Subagent reached its step limit. Findings may be incomplete — inspect the workspace directly if needed.' };
  }

  // Helper: execute local tool call requested by Singularity Matrix
  const executeMatrixTool = async (toolName, params, targetWsPath) => {
    const wsPath = targetWsPath || activeWorkspace.path;
    switch (toolName) {
      case 'update_plan': {
        if (!params.plan) return { error: 'plan is required' };
        const res = await window.newtonAPI.writeFile({
          workspacePath: wsPath,
          relativePath: '.newton/plan.md',
          content: params.plan
        });
        if (!res.success) return { error: res.error || 'Failed to update plan' };
        if (!workspaceMemoryCache[wsPath]) workspaceMemoryCache[wsPath] = {};
        if (!workspaceMemoryCache[wsPath].projectMemory) workspaceMemoryCache[wsPath].projectMemory = {};
        workspaceMemoryCache[wsPath].projectMemory.plan = params.plan;
        return { success: true, message: 'Updated .newton/plan.md successfully' };
      }

      case 'update_memory': {
        const sec = params.section || 'General Knowledge';
        const text = params.content || '';
        const mode = params.mode || 'append';
        let currentMem = '';
        try {
          const rRes = await window.newtonAPI.readFile({ workspacePath: wsPath, relativePath: '.newton/memory.md' });
          if (rRes.success && rRes.data) currentMem = typeof rRes.data === 'string' ? rRes.data : (rRes.data.content || '');
        } catch (_) {}
        let newMem = '';
        if (mode === 'replace' || !currentMem.trim()) {
          newMem = `# Project Memory\n\n## ${sec}\n${text}\n`;
        } else {
          newMem = `${currentMem.trim()}\n\n## ${sec}\n${text}\n`;
        }
        const wRes = await window.newtonAPI.writeFile({ workspacePath: wsPath, relativePath: '.newton/memory.md', content: newMem });
        if (!wRes.success) return { error: wRes.error || 'Failed to update memory' };
        if (!workspaceMemoryCache[wsPath]) workspaceMemoryCache[wsPath] = {};
        if (!workspaceMemoryCache[wsPath].projectMemory) workspaceMemoryCache[wsPath].projectMemory = {};
        workspaceMemoryCache[wsPath].projectMemory.knowledge = newMem;
        return { success: true, message: `Updated .newton/memory.md (${sec}) successfully` };
      }

      case 'list_files': {
        const res = await window.newtonAPI.listFiles({
          workspacePath: wsPath,
          subPath: params.subPath || '',
          maxDepth: params.maxDepth || 4,
          recursive: params.recursive !== false
        });
        if (!res.success) return { error: res.error || 'Failed to list files' };
        const summary = (res.data || []).map(f => `${f.isDirectory ? '[DIR] ' : '      '}${f.relativePath}`).join('\n');
        return { success: true, count: res.data?.length || 0, files: summary || '(Empty directory)' };
      }

      case 'read_file': {
        if (!params.relativePath) return { error: 'relativePath is required' };
        const res = await window.newtonAPI.readFile({
          workspacePath: wsPath,
          relativePath: params.relativePath,
          startLine: params.startLine != null ? Number(params.startLine) : null,
          endLine: params.endLine != null ? Number(params.endLine) : null
        });
        if (!res.success) return { error: res.error || 'Failed to read file' };
        if (res.data?.isPartial) {
          return {
            success: true,
            file: params.relativePath,
            lines: `${res.data.startLine}-${res.data.endLine} of ${res.data.totalLines}`,
            content: res.data.numberedContent
          };
        }
        return {
          success: true,
          file: params.relativePath,
          totalLines: res.data?.totalLines || 0,
          content: res.data?.content != null ? res.data.content : res.data
        };
      }

      case 'edit_file': {
        if (!params.relativePath) return { error: 'relativePath is required' };
        if (params.old_str == null || params.new_str == null) return { error: 'Both old_str and new_str are required' };

        // Clean accidental LLM markdown bold leaks (e.g. **init** -> __init__, **name** -> __name__)
        let oldStr = typeof params.old_str === 'string' ? params.old_str : String(params.old_str);
        let newStr = typeof params.new_str === 'string' ? params.new_str : String(params.new_str);

        if (!sessionCreatedFiles.has(params.relativePath)) {
          const allowed = await gateTool('edit_file', params, `- ${oldStr.slice(0, 400)}\n+ ${newStr.slice(0, 400)}`);
          if (!allowed) return { error: 'User denied this edit operation.' };
        }

        const res = await window.newtonAPI.editFile({
          workspacePath: wsPath,
          relativePath: params.relativePath,
          old_str: oldStr,
          new_str: newStr
        });
        if (!res.success) {
          // If replacement failed, attempt with de-markdowned old_str
          const sanitizedOld = oldStr.replace(/\*\*([a-zA-Z0-9_]+)\*\*/g, '__$1__');
          const sanitizedNew = newStr.replace(/\*\*([a-zA-Z0-9_]+)\*\*/g, '__$1__');
          if (sanitizedOld !== oldStr || sanitizedNew !== newStr) {
            const retryRes = await window.newtonAPI.editFile({
              workspacePath: wsPath,
              relativePath: params.relativePath,
              old_str: sanitizedOld,
              new_str: sanitizedNew
            });
            if (retryRes.success) {
              sessionAuditTrail.files.add(params.relativePath);
              return { success: true, message: retryRes.message || `Successfully updated ${params.relativePath}`, diff: retryRes.diff };
            }
          }
          return { error: res.error || 'Failed to edit file' };
        }
        sessionAuditTrail.files.add(params.relativePath);
        return { success: true, message: res.message || `Successfully updated ${params.relativePath}`, diff: res.diff };
      }

      case 'grep_search': {
        if (!params.query) return { error: 'query is required' };
        const res = await window.newtonAPI.grepSearch({
          workspacePath: wsPath,
          query: params.query,
          subPath: params.subPath || ''
        });
        if (!res.success) return { error: res.error || 'Failed to grep search' };
        return { success: true, count: res.count || 0, matches: res.matches || [] };
      }

      case 'web_search': {
        const q = params.query || '';
        try {
          const res = await fetch(`https://html.duckduckgo.com/html/?q=${encodeURIComponent(q)}`, {
            headers: { 'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)' }
          });
          const html = await res.text();
          const matches = html.match(/<a class="result__snippet[^>]*>(.*?)<\/a>/g) || [];
          const clean = matches.slice(0, 3).map(m => m.replace(/<[^>]+>/g, '').trim());
          return { query: q, findings: clean.length ? clean : ['Search indexed.'] };
        } catch (e) {
          return { query: q, findings: ['Documentation reference indexed.'] };
        }
      }

      case 'write_file': {
        if (!params.relativePath) return { error: 'relativePath is required' };
        let content = params.content || '';
        // Guard against LLM markdown artifacts in source files (e.g. def **init** -> def __init__)
        if (typeof content === 'string' && /\*\*[a-zA-Z0-9_]+\*\*/.test(content)) {
          content = content.replace(/\*\*([a-zA-Z0-9_]+)\*\*/g, '__$1__');
        }
        if (!sessionCreatedFiles.has(params.relativePath)) {
          const allowed = await gateTool('write_file', params, content.split('\n').slice(0, 40).join('\n'));
          if (!allowed) return { error: 'User denied this write operation.' };
        }
        const res = await window.newtonAPI.writeFile({
          workspacePath: wsPath,
          relativePath: params.relativePath,
          content
        });
        if (!res.success) return { error: res.error || 'Failed to write file' };
        sessionCreatedFiles.add(params.relativePath);
        sessionAuditTrail.files.add(params.relativePath);
        return { success: true, message: `Successfully wrote ${params.relativePath}`, diff: res.diff };
      }

      case 'create_file': {
        if (!params.relativePath) return { error: 'relativePath is required' };
        let content = params.content || '';
        if (typeof content === 'string' && /\*\*[a-zA-Z0-9_]+\*\*/.test(content)) {
          content = content.replace(/\*\*([a-zA-Z0-9_]+)\*\*/g, '__$1__');
        }
        const allowed = await gateTool('create_file', params, content.split('\n').slice(0, 40).join('\n'));
        if (!allowed) return { error: 'User denied this file creation.' };
        const res = await window.newtonAPI.createFile({
          workspacePath: wsPath,
          relativePath: params.relativePath,
          content
        });
        if (!res.success) return { error: res.error || 'Failed to create file' };
        sessionCreatedFiles.add(params.relativePath);
        sessionAuditTrail.files.add(params.relativePath);
        return { success: true, message: `Successfully created ${params.relativePath}` };
      }

      case 'delete_file': {
        if (!params.relativePath) return { error: 'relativePath is required' };
        const allowed = await gateTool('delete_file', params, `rm ${params.relativePath}`);
        if (!allowed) return { error: 'User denied this deletion.' };
        const res = await window.newtonAPI.deleteFile({
          workspacePath: wsPath,
          relativePath: params.relativePath
        });
        if (!res.success) return { error: res.error || 'Failed to delete file' };
        sessionAuditTrail.files.add(`(deleted) ${params.relativePath}`);
        return { success: true, message: `Successfully deleted ${params.relativePath}` };
      }

      case 'exec_bash': {
        if (!params.command) return { error: 'command is required' };
        const allowed = await gateTool('exec_bash', params, params.command);
        if (!allowed) return { error: 'User denied this command execution.' };
        sessionAuditTrail.commands.push(params.command);
        const res = await window.newtonAPI.execBash({
          workspacePath: wsPath,
          command: params.command
        });
        // A successful test/lint/compile-style run counts as task verification
        if (res.success && /(^|[^a-z])(test|tests|lint|tsc|py_compile|pylint|ruff|eslint|vitest|jest|pytest|cargo test|go test|mvn|gradle)([^a-z]|$)/i.test(params.command)) {
          sessionAuditTrail.verified = true;
          sessionAuditTrail.lastVerification = { command: params.command, ok: true, output: ((res.stdout || '') + '\n' + (res.stderr || '')).slice(0, 3000) };
        }
        return {
          success: res.success,
          exitCode: res.exitCode,
          stdout: (res.stdout || '').slice(0, 4000),
          stderr: (res.stderr || '').slice(0, 2000)
        };
      }

      case 'git': {
        const action = params.action || 'status';
        const res = await window.newtonAPI.git({
          workspacePath: wsPath,
          action,
          args: { message: params.message, staged: !!params.staged, limit: params.limit }
        });
        return {
          success: res.success,
          action,
          stdout: (res.stdout || '').slice(0, 6000),
          stderr: (res.stderr || '').slice(0, 2000)
        };
      }

      case 'subagent': {
        if (!params.task) return { error: 'task is required' };
        const sub = await runReadonlySubagent(params.task, params.focus || '', wsPath);
        return sub;
      }

      default:
        return { error: `Unknown tool: ${toolName}` };
    }
  };

  // Helper: render visual tool action card inside message feed
  const renderToolCard = (toolName, params) => {
    const messagesStream = document.getElementById('code-messages-stream');
    const card = document.createElement('div');
    card.className = `code-action-card tool-${toolName}`;
    card.setAttribute('data-tool', toolName);

    const iconMap = {
      update_plan: 'checkmark_alt',
      update_memory: 'lightbulb',
      list_files: 'square_list',
      read_file: 'doc_text_search',
      edit_file: 'scissors',
      grep_search: 'search',
      web_search: 'globe',
      write_file: 'square_pencil',
      create_file: 'plus_square',
      delete_file: 'trash',
      exec_bash: 'terminal',
      git: 'logo_ios', // branch/network metaphor
      subagent: 'person_crop_circle_badge_checkmark'
    };
    const iconName = iconMap[toolName] || 'gear';
    let plan_escaped_name = null;

    switch (toolName) {
      case "update_plan":
        plan_escaped_name = 'Update Newton\'s plan';
        break;
      case "update_memory":
        plan_escaped_name = 'Update memory';
        break;
      case "list_files":
        plan_escaped_name = `Listed files from ${params.subPath || 'this workspace.'}`;
        break;
      case "edit_file":
        plan_escaped_name = `Edited ${params.relativePath}`;
        break;
      case "read_file":
        plan_escaped_name = `Read ${params.relativePath}`;
        break;
      case "grep_search":
        plan_escaped_name = `Looked for ${params.query || 'empty'}.`;
        break;
      case "web_search":
        plan_escaped_name = `Looked online for ${params.query || 'empty'}.`;
        break;
      case "write_file":
      case "create_file":
      case "delete_file":
        plan_escaped_name = params.relativePath;
        break;
      case "exec_bash":
        plan_escaped_name = `Executed bash: ${params.command}`;
        break;
      case "git":
        plan_escaped_name = `Git ${params.action || 'status'}`;
        break;
      case "subagent":
        plan_escaped_name = `Subagent: ${params.task || 'research'}`;
        break;
    }

    card.innerHTML = `
      <div class="code-action-summary">
        <div class="code-action-left">
          <i class="f7-icons code-action-icon">${iconName}</i>
          <span class="code-action-toolname">${plan_escaped_name}</span>
        </div>
        <div class="code-action-right">
          <span class="tool-status-pill running" style="display: none;">Executing</span>
          <i class="f7-icons code-action-chevron">chevron_right</i>
        </div>
      </div>
      <div class="code-action-body" style="display: none;">
        <div class="code-action-output" style="display: none;"></div>
      </div>
    `;

    const summaryEl = card.querySelector('.code-action-summary');
    const bodyEl = card.querySelector('.code-action-body');
    const chevronEl = card.querySelector('.code-action-chevron');

    summaryEl?.addEventListener('click', () => {
      const isVisible = bodyEl.style.display !== 'none';
      bodyEl.style.display = isVisible ? 'none' : 'flex';
      chevronEl.textContent = isVisible ? 'chevron_right' : 'chevron_down';
    });

    if (messagesStream) {
      messagesStream.appendChild(card);
      scrollCodeToBottom();
    }

    return {
      card,
      setStatus: (status, label) => {
        const pill = card.querySelector('.tool-status-pill');
        if (pill) {
          pill.className = `tool-status-pill ${status}`;
          pill.textContent = label || status;
        }
      },
      setOutput: (text) => {
        const out = card.querySelector('.code-action-output');
        if (out) {
          out.textContent = text;
          out.style.display = 'block';
        }
      },
      setDiff: (diff) => {
        if (!diff || !Array.isArray(diff.hunks) || diff.hunks.length === 0) return;
        const body = card.querySelector('.code-action-body');
        if (!body) return;
        let existing = body.querySelector('.code-action-diff');
        if (!existing) {
          existing = document.createElement('div');
          existing.className = 'code-action-diff';
          body.insertBefore(existing, body.firstChild);
        }
        const head = document.createElement('div');
        head.className = 'code-diff-stats';
        head.innerHTML = `<span class="add">+${diff.added}</span> <span class="del">−${diff.removed}</span>${diff.truncated ? ' <span class="muted">(diff truncado)</span>' : ''}`;
        existing.innerHTML = '';
        existing.appendChild(head);
        for (const hunk of diff.hunks) {
          const pre = document.createElement('pre');
          pre.className = 'code-diff-hunk';
          for (const line of hunk.lines) {
            const row = document.createElement('div');
            row.className = `diff-line ${line.type}`;
            row.textContent = (line.type === 'add' ? '+' : '−') + ' ' + line.text;
            pre.appendChild(row);
          }
          existing.appendChild(pre);
        }
        body.style.display = 'flex';
        const chevron = card.querySelector('.code-action-chevron');
        if (chevron) chevron.textContent = 'chevron_down';
      }
    };
  };

  // 6. Singularity Matrix Task Execution & Streaming Stream
  function setupCodeTaskExecution() {
    const codeTaskForm = document.getElementById('code-task-form');
    const codeTaskInput = document.getElementById('code-task-input');
    const btnCodeSubmit = document.getElementById('btn-code-submit');
    const bypassCheck = document.getElementById('check-bypass-permissions');

    codeTaskInput?.addEventListener('input', () => {
      codeTaskInput.style.height = 'auto';
      codeTaskInput.style.height = Math.min(codeTaskInput.scrollHeight, 140) + 'px';
    });

    codeTaskInput?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        codeTaskForm?.dispatchEvent(new Event('submit'));
      }
    });

    let isAgentCancelled = false;

    // Handle Stop / Cancel click on the submit button while running
    btnCodeSubmit?.addEventListener('click', (e) => {
      if (isCodeGenerating) {
        e.preventDefault();
        e.stopPropagation();
        isAgentCancelled = true;
        btnCodeSubmit.disabled = true;
        btnCodeSubmit.innerHTML = '<i class="f7-icons" style="font-size: 14px;">hourglass</i>';
      }
    });

    codeTaskForm?.addEventListener('submit', async (e) => {
      e.preventDefault();
      if (isCodeGenerating) {
        // User clicked submit while running -> treat as stop
        isAgentCancelled = true;
        return;
      }

      const prompt = codeTaskInput.value.trim();
      if (!prompt) return;

      isAgentCancelled = false;
      codeTaskInput.value = '';
      codeTaskInput.style.height = 'auto';

      // Switch view from dashboard to messages stream
      const dashboardCard = document.getElementById('code-dashboard-card');
      const messagesStream = document.getElementById('code-messages-stream');
      if (dashboardCard) dashboardCard.style.display = 'none';
      if (messagesStream) messagesStream.style.display = 'flex';

      // Append user bubble
      appendCodeMessage('user', prompt);

      // Append bot bubble placeholder with Thinking Orb and Thinking Card
      const botObj = createCodeAssistantBubble();
      messagesStream.appendChild(botObj.container);
      scrollCodeToBottom();

      // Animate header thinking orb to 'wave' during generation
      if (codeHeaderOrb) codeHeaderOrb.setState('wave');
      isCodeGenerating = true;

      // Switch submit button to Stop button
      if (btnCodeSubmit) {
        btnCodeSubmit.disabled = false;
        btnCodeSubmit.classList.add('is-running');
        btnCodeSubmit.title = 'Detener ejecución autónoma';
        btnCodeSubmit.innerHTML = '<i class="f7-icons" style="font-size: 14px;">stop_fill</i>';
      }

      let turnRawText = '';
      let activeBotBubble = botObj;
      const cleanupStream = window.newtonAPI?.onStreamChunk((chunk) => {
        if (chunk.type === 'delta') {
          turnRawText += chunk.text;
          if (activeBotBubble) {
            updateCodeAssistantBubble(activeBotBubble, turnRawText);
            scheduleScroll(document.getElementById('code-messages-stream') || document.getElementById('code-center-scroll'));
          }
        } else if (chunk.type === 'done') {
          if (chunk.text && chunk.text.length > turnRawText.length) turnRawText = chunk.text;
          if (activeBotBubble) updateCodeAssistantBubbleImmediate(activeBotBubble, turnRawText);
          flushScroll();
        }
      });

      try {
        const branchStr = activeWorkspace.branch && activeWorkspace.branch !== 'undefined' ? activeWorkspace.branch : 'main';
        let inspectionPrefix = `[ACTIVE WORKSPACE: ${activeWorkspace.name} (${activeWorkspace.path}) | Branch: ${branchStr} | Reasoning Effort: ${codeReasoningEffort}]\n`;

        // Check if we have proactively cached data for this workspace
        let d = workspaceMemoryCache[activeWorkspace.path];
        if (!d) {
          try {
            const sumRes = await window.newtonAPI?.getWorkspaceSummary(activeWorkspace.path);
            if (sumRes?.success && sumRes.data) {
              d = sumRes.data;
              workspaceMemoryCache[activeWorkspace.path] = d;
            }
          } catch (_) {}
        }

        if (d) {
          const fileList = d.files || [];
          const fileCount = fileList.length;
          const fileNamesPreview = fileList.slice(0, 30).map(f => (f.isDirectory ? `${f.name}/` : f.name)).join(', ');
          inspectionPrefix += `Workspace Topography: ${fileCount} files/folders: [${fileNamesPreview}${fileCount > 30 ? ', ...' : ''}].\n`;

          if (d.mainEntrypoint) {
            inspectionPrefix += `Primary Entrypoint Detected: ${d.mainEntrypoint.relativePath} (${d.mainEntrypoint.totalLines} lines):\n\`\`\`\n${d.mainEntrypoint.content.slice(0, 1200)}\n\`\`\`\n`;
          }

          if (d.packageInfo) {
            if (d.packageInfo.name) {
              inspectionPrefix += `Package Manifest (${d.packageInfo.name}@${d.packageInfo.version || '0.0.0'}):\n- Dependencies: ${(d.packageInfo.dependencies || []).slice(0, 25).join(', ')}\n- Scripts: ${Object.keys(d.packageInfo.scripts || {}).join(', ')}\n`;
            } else if (d.packageInfo.snippet) {
              inspectionPrefix += `Project Config (${d.packageInfo.type}):\n${d.packageInfo.snippet.slice(0, 400)}\n`;
            }
          }

          if (d.readme) {
            inspectionPrefix += `README Snippet:\n${d.readme.slice(0, 800)}\n`;
          }

          if (d.projectMemory) {
            if (d.projectMemory.plan) {
              inspectionPrefix += `\n[Active Project Plan (.newton/plan.md)]:\n${d.projectMemory.plan}\n`;
            }
            if (d.projectMemory.knowledge) {
              inspectionPrefix += `\n[Project Memory & Invariants (.newton/memory.md)]:\n${d.projectMemory.knowledge}\n`;
            }
          }
        }
        inspectionPrefix += '\n';

        const isFollowUpTurn = Array.isArray(codeSessionHistory) && codeSessionHistory.length > 0;
        const fullPrompt = isFollowUpTurn
          ? `USER DIRECTIVE: ${prompt}\n\nYou are the autonomous engineer on workspace "${activeWorkspace.name}". Continue executing the objective directly using your tools (write_file, edit_file, exec_bash). The user will not copy code or run commands. Emit your concrete <tool_call> block(s) to apply changes and verify.`
          : `${SINGULARITY_MATRIX_SYSTEM_PROMPT}\n\n${inspectionPrefix}USER INTENT: ${prompt}\n\nYou are working autonomously in "${activeWorkspace.name}". From this intent alone, run your full operating cycle (orient → plan → execute → verify → commit & report) using batched parallel tool calls. Do not ask how; just deliver the working result.`;

        // Ensure chat entry exists under active workspace directory
        if (!currentCodeTaskId) {
          currentCodeTaskId = 'task_' + Date.now().toString(36);
          if (!workspaceChatsMap[activeWorkspace.path]) {
            workspaceChatsMap[activeWorkspace.path] = [];
          }
          workspaceChatsMap[activeWorkspace.path].unshift({
            id: currentCodeTaskId,
            title: prompt.slice(0, 45),
            created_at: Math.floor(Date.now() / 1000),
            messages: []
          });
          saveWorkspaceChatsMap();
          renderCodeWorkspacesTree();
        }

        // Autonomous Agentic Execution Loop (bounded by MAX_AGENT_STEPS)
        const MAX_AGENT_STEPS = 40;
        const MAX_HISTORY_CHARS = 90000;
        let stepCount = 0;
        let currentPrompt = fullPrompt;
        activeBotBubble = botObj;
        const recentToolCalls = [];
        sessionCreatedFiles.clear();
        sessionAuditTrail = { files: new Set(), commands: [], verified: false, lastVerification: null };
        let forcedVerificationPushes = 0;
        let lastReplyNorm = '';
        let stallCount = 0;
        let lastFailedTool = null;
        let consecutiveFailures = 0;

        // Context compaction: keep the protocol coherent while trimming old tool chatter
        const compactHistory = () => {
          let total = codeSessionHistory.reduce((n, m) => n + (m.content?.length || 0), 0);
          while (total > MAX_HISTORY_CHARS && codeSessionHistory.length > 6) {
            const removed = codeSessionHistory.splice(0, 2);
            total -= removed.reduce((n, m) => n + (m.content?.length || 0), 0);
            codeSessionHistory.unshift({ role: 'user', content: '[Earlier steps compacted: older tool exchanges were summarized away to fit the context window.]' });
          }
        };

        // End-of-task verification: run the project's own checks if it modified files
        const runTaskVerification = async () => {
          if (sessionAuditTrail.files.size === 0) return null;
          const d = workspaceMemoryCache[activeWorkspace.path] || {};
          const scripts = d.packageInfo?.scripts || {};
          const testCmd = scripts.test && !/^echo/.test(scripts.test)
            ? 'npm test'
            : (scripts.lint ? 'npm run lint' : null);
          if (!testCmd) return null;
          try {
            const res = await window.newtonAPI.execBash({ workspacePath: activeWorkspace.path, command: testCmd });
            return { command: testCmd, ok: !!res.success, output: ((res.stdout || '') + (res.stderr || '')).slice(0, 3000) };
          } catch (e) {
            return { command: testCmd, ok: false, output: e.message };
          }
        };

        const renderSessionSummary = (verification) => {
          const messagesStream = document.getElementById('code-messages-stream');
          if (!messagesStream) return;
          const card = document.createElement('div');
          card.className = 'code-session-summary';
          const filesHtml = [...sessionAuditTrail.files].map(f => `<li>${escapeHtml(f)}</li>`).join('');
          const cmdsHtml = sessionAuditTrail.commands.slice(-8).map(c => `<li><code>${escapeHtml(c)}</code></li>`).join('');
          const verifyHtml = verification
            ? `<div class="summary-verify ${verification.ok ? 'ok' : 'fail'}">${verification.ok ? '✔' : '✘'} Verificación (${escapeHtml(verification.command)})</div><pre class="summary-verify-output">${escapeHtml(verification.output.slice(0, 1200))}</pre>`
            : '';
          card.innerHTML = `
            <div class="summary-header"><i class="f7-icons">doc_checkmark</i> Resumen de la tarea</div>
            ${filesHtml ? `<div class="summary-section">Archivos modificados</div><ul>${filesHtml}</ul>` : ''}
            ${cmdsHtml ? `<div class="summary-section">Comandos ejecutados</div><ul>${cmdsHtml}</ul>` : ''}
            ${verifyHtml}
          `;
          messagesStream.appendChild(card);
          scrollCodeToBottom();
        };

        while (true) {
          if (isAgentCancelled) {
            activeBotBubble.content.style.display = 'block';
            activeBotBubble.content.textContent += '\n\n*(Ejecución detenida por el usuario)*';
            renderSessionSummary(null);
            break;
          }

          if (stepCount >= MAX_AGENT_STEPS) {
            currentPrompt = `<system_notice>\nYou reached the maximum of ${MAX_AGENT_STEPS} steps for this task. Stop calling tools now and deliver a final report of what you accomplished and what remains.\n</system_notice>`;
          }
          if (stepCount >= MAX_AGENT_STEPS + 3) {
            activeBotBubble.content.style.display = 'block';
            activeBotBubble.content.textContent += '\n\n*(Límite de pasos alcanzado — ejecución finalizada)*';
            renderSessionSummary(null);
            break;
          }

          stepCount++;

          const payload = {
            prompt: currentPrompt,
            model: 'Singularity-Matrix',
            history: codeSessionHistory,
            isGhost: true
          };

          let response = null;
          let retryCount = 0;
          const maxRetries = 2;

          while (retryCount <= maxRetries) {
            response = await window.newtonAPI.sendMessage(payload);
            if (response.success) break;

            const isTransient = /(?:502|520|524|503|gateway|timeout|fetch failed)/i.test(response.error || '');
            if (isTransient && retryCount < maxRetries && !isAgentCancelled) {
              retryCount++;
              activeBotBubble.content.style.display = 'block';
              activeBotBubble.content.textContent = `*(Reconectando con Singularity Matrix: reintento ${retryCount}/${maxRetries}...)*`;
              await new Promise(r => setTimeout(r, 2500 * retryCount));
              continue;
            }
            break;
          }

          if (isAgentCancelled) {
            activeBotBubble.content.style.display = 'block';
            activeBotBubble.content.textContent += '\n\n*(Ejecución detenida por el usuario)*';
            break;
          }

          if (!response || !response.success) {
            activeBotBubble.content.style.display = 'block';
            activeBotBubble.content.textContent = `Error: ${response?.error || 'Failed to complete code task.'}`;
            activeBotBubble.content.style.color = '#e67e80';
            break;
          }

          const replyText = response.data?.reply || turnRawText;
          updateCodeAssistantBubble(activeBotBubble, replyText);

          // Parse ALL tool calls in the reply: multiple <tool_call>{...}</tool_call> blocks
          const toolCallMatches = [...replyText.matchAll(/<tool_call>([\s\S]*?)<\/tool_call>/g)];
          if (toolCallMatches.length === 0) {
            // Stall detector: an action-less reply that repeats the previous
            // action-less reply means the agent is narrating instead of working.
            const replyNorm = replyText
              .replace(/<thinking>[\s\S]*?<\/thinking>/g, '')
              .replace(/\s+/g, ' ')
              .trim()
              .toLowerCase()
              .slice(0, 600);
            const isRepeat = replyNorm.length > 60 && replyNorm === lastReplyNorm;
            lastReplyNorm = replyNorm;

            // Only flag identical repetitive text responses if the agent is stalling without tools
            if (isRepeat) {
              stallCount = stallCount + 1;
              if (stallCount >= 3) {
                activeBotBubble.content.style.display = 'block';
                activeBotBubble.content.textContent = '*(El agente quedó atascado repitiendo análisis sin actuar — ejecución detenida. Reformula la tarea o dale más contexto.)*';
                activeBotBubble.content.style.color = '#e5989b';
                renderSessionSummary(null);
                break;
              }
              codeSessionHistory.push({ role: 'user', content: currentPrompt });
              codeSessionHistory.push({ role: 'assistant', content: replyText });
              compactHistory();
              currentPrompt = `<system_gate>\nYour last two responses were nearly identical and contained NO <tool_call>. If the task is finished, output your final summary. Otherwise, emit the necessary <tool_call> block(s) to continue.\n</system_gate>`;
              turnRawText = '';
              activeBotBubble = createCodeAssistantBubble();
              messagesStream.appendChild(activeBotBubble.container);
              scrollCodeToBottom();
              continue;
            }

            codeSessionHistory.push({ role: 'user', content: prompt });
            codeSessionHistory.push({ role: 'assistant', content: replyText });
            compactHistory();

            const chatEntry = workspaceChatsMap[activeWorkspace.path]?.find(c => c.id === currentCodeTaskId);
            if (chatEntry) {
              chatEntry.messages = [...codeSessionHistory];
              saveWorkspaceChatsMap();
              renderCodeWorkspacesTree();
            }
            const verification = sessionAuditTrail.lastVerification || await runTaskVerification();
            renderSessionSummary(verification);
            populateDashboardMetrics();
            break;
          }

          const parsedCalls = [];
          let parseFailed = false;
          for (const m of toolCallMatches) {
            let parsed = null;
            try {
              parsed = JSON.parse(m[1].trim());
            } catch (jsonErr) {
              console.warn('Tool call JSON parse error:', jsonErr);
            }
            if (!parsed || !parsed.tool) { parseFailed = true; break; }
            parsedCalls.push({ toolName: parsed.tool, toolParams: parsed.parameters || {} });
          }

          if (parseFailed || parsedCalls.length === 0) {
            currentPrompt = `<tool_response>\n[Parse error: one of your <tool_call> blocks contained invalid JSON or a missing "tool" field. Re-emit the call(s) with valid JSON.]\n</tool_response>`;
            turnRawText = '';
            activeBotBubble = createCodeAssistantBubble();
            messagesStream.appendChild(activeBotBubble.container);
            scrollCodeToBottom();
            continue;
          }

          // Stuck-loop detector: Only prevent repetitive identical READ-ONLY calls with no state changes.
          // Never block exec_bash, write_file, edit_file, delete_file, or git commands since compiling, testing,
          // and modifying code naturally re-runs the same commands across iterations.
          const UNRESTRICTED_TOOLS = new Set(['exec_bash', 'write_file', 'edit_file', 'delete_file', 'create_file', 'git', 'update_plan', 'update_memory']);
          const signatureOf = (c) => `${c.toolName}:${JSON.stringify(c.toolParams)}`;
          const loopedCall = parsedCalls.find((c) => {
            if (UNRESTRICTED_TOOLS.has(c.toolName)) return false;
            const sig = signatureOf(c);
            const pastCount = recentToolCalls.filter(s => s === sig).length;
            return pastCount >= 2 || parsedCalls.filter(o => signatureOf(o) === sig).length > 1;
          });
          if (loopedCall) {
            recentToolCalls.push(signatureOf(loopedCall));
            const warnCard = renderToolCard(loopedCall.toolName, loopedCall.toolParams);
            warnCard.setStatus('error', 'Loop Prevented');
            warnCard.setOutput(`Notice: Read-only tool "${loopedCall.toolName}" was already executed with identical arguments.`);
            currentPrompt = `<tool_response tool="${loopedCall.toolName}">\n[Notice: You already read this data with identical parameters. Proceed to edit files or conclude.]\n</tool_response>`;
            turnRawText = '';
            activeBotBubble = createCodeAssistantBubble();
            messagesStream.appendChild(activeBotBubble.container);
            scrollCodeToBottom();
            continue;
          }
          for (const c of parsedCalls) {
            recentToolCalls.push(signatureOf(c));
          }
          if (recentToolCalls.length > 12) recentToolCalls.splice(0, recentToolCalls.length - 12);

          // Parallel-batch execution: read-only calls run concurrently; any
          // mutating/executing call runs sequentially in emission order.
          const READONLY_PARALLEL = new Set(['list_files', 'read_file', 'grep_search', 'web_search', 'update_plan', 'update_memory']);
          const allReadonly = parsedCalls.every(c => READONLY_PARALLEL.has(c.toolName));

          const runSingleCall = async (call) => {
            const toolUI = renderToolCard(call.toolName, call.toolParams);
            let result = null;
            try {
              result = await executeMatrixTool(call.toolName, call.toolParams);
              if (result.error) {
                toolUI.setStatus('error', 'Failed');
                toolUI.setOutput(`Error: ${result.error}`);
              } else {
                toolUI.setStatus('success', 'Completed');
                if (result.diff) toolUI.setDiff(result.diff);
                const outPreview = typeof result === 'string'
                  ? result
                  : (result.content || result.files || result.stdout || result.message || result.summary || JSON.stringify(result, null, 2));
                toolUI.setOutput(outPreview);
              }
            } catch (tErr) {
              result = { error: tErr.message };
              toolUI.setStatus('error', 'Exception');
              toolUI.setOutput(`Exception: ${tErr.message}`);
            }
            let out = typeof result === 'string'
              ? result
              : (result.content || result.files || result.stdout || result.message || result.summary || JSON.stringify(result, null, 2));
            const MAX_TOOL_OUTPUT_CHARS = 12000;
            if (typeof out === 'string' && out.length > MAX_TOOL_OUTPUT_CHARS) {
              out = out.slice(0, MAX_TOOL_OUTPUT_CHARS) + `\n\n[Output truncated: ${out.length - MAX_TOOL_OUTPUT_CHARS} characters omitted for brevity. Specify line ranges or narrower queries if more details are needed.]`;
            }
            return { call, out, failed: !!(result && result.error) };
          };

          let results;
          if (allReadonly && parsedCalls.length > 1) {
            // Independent reads: execute concurrently, render cards in order
            results = await Promise.all(parsedCalls.map(runSingleCall));
          } else {
            results = [];
            for (const call of parsedCalls) results.push(await runSingleCall(call));
          }

          // Record turn in history
          codeSessionHistory.push({ role: 'user', content: currentPrompt });
          codeSessionHistory.push({ role: 'assistant', content: replyText });
          compactHistory();

          // Next agent step: combined <tool_response> for every executed call
          const responseBlocks = results.map(r => `<result tool="${r.call.toolName}">\n${r.out}\n</result>`).join('\n');
          const batchNote = results.length > 1
            ? `\n[System: ${results.length} tools executed in this batch. All results are below.]`
            : '';

          // Failure escalation: same tool failing 3 turns in a row → demand a new strategy
          const anyFailed = results.some(r => r.failed);
          const failedToolNames = [...new Set(results.filter(r => r.failed).map(r => r.call.toolName))];
          if (anyFailed && failedToolNames.length === 1 && failedToolNames[0] === lastFailedTool) {
            consecutiveFailures++;
          } else {
            lastFailedTool = anyFailed ? failedToolNames[0] : null;
            consecutiveFailures = anyFailed ? 1 : 0;
          }
          const failNote = consecutiveFailures >= 3
            ? `\n[System: "${lastFailedTool}" has failed ${consecutiveFailures} turns in a row. STOP retrying the same approach. Change strategy: read the failing file first, try a different tool, break the step into smaller pieces, research the correct usage with subagent or web_search, or if the goal is unachievable, say precisely why.]`
            : '';

          currentPrompt = `<tool_results>\n${responseBlocks}\n</tool_results>${batchNote}${failNote}\n\nReview the tool results. If further changes, commands, or tests are needed, emit your next <tool_call> block(s). If the objective is complete and verified, provide your final response to the user without any tool calls.`;

          // Prepare new bubble for next iteration
          turnRawText = '';
          activeBotBubble = createCodeAssistantBubble();
          messagesStream.appendChild(activeBotBubble.container);
          scrollCodeToBottom();
        }
      } catch (err) {
        botObj.content.textContent = `Connection error: ${err.message}`;
        botObj.content.style.color = '#e67e80';
      } finally {
        if (cleanupStream) cleanupStream();
        isCodeGenerating = false;
        if (btnCodeSubmit) {
          btnCodeSubmit.disabled = false;
          btnCodeSubmit.classList.remove('is-running');
          btnCodeSubmit.title = 'Ejecutar tarea';
          btnCodeSubmit.innerHTML = '<i class="f7-icons" style="font-size: 14px;">arrow_up</i>';
        }
        if (codeHeaderOrb) codeHeaderOrb.setState('orbits');
        scrollCodeToBottom();
        codeTaskInput?.focus();
      }
    });
  }

  let activeRemoteSessionId = null;
  let isRemoteCancelled = false;

  function handleRemoteCancel(data) {
    if (!activeRemoteSessionId || (data?.sessionId && data.sessionId !== activeRemoteSessionId)) return;
    isRemoteCancelled = true;
    console.log('Remote execution cancelled by iOS:', data?.sessionId);
  }

  async function handleRemoteDispatchFromIOS(data) {
    if (!data || !data.task) return;
    const sessionId = data.sessionId || `codesess_${Date.now()}`;
    activeRemoteSessionId = sessionId;
    isRemoteCancelled = false;

    // Switch to Code Mode
    switchAppMode('code');

    // Switch workspace if provided
    const targetWsPath = data.workspacePath || activeWorkspace.path;
    if (data.workspacePath) {
      const match = codeWorkspaces.find(w => w.path === data.workspacePath || w.name === data.workspaceName);
      if (match) {
        activeWorkspace.name = match.name;
        activeWorkspace.path = match.path;
      } else {
        activeWorkspace.name = data.workspaceName || data.workspacePath.split('/').pop();
        activeWorkspace.path = data.workspacePath;
      }
      try {
        const branchRes = await window.newtonAPI.getBranch(activeWorkspace.path);
        if (branchRes?.success && branchRes.branch) activeWorkspace.branch = branchRes.branch;
      } catch (_) {}
      updateActiveWorkspacePills();
      renderCodeWorkspacesTree();
    }

    // Ensure chats array exists for this workspace
    if (!workspaceChatsMap[activeWorkspace.path]) {
      workspaceChatsMap[activeWorkspace.path] = [];
    }

    // Locate or create specific code chat in this workspace
    let targetChat = null;
    if (data.chatId) {
      targetChat = workspaceChatsMap[activeWorkspace.path].find(c => c.id === data.chatId);
    }

    if (!targetChat) {
      const newChatId = data.chatId || ('task_' + Date.now().toString(36));
      targetChat = {
        id: newChatId,
        title: data.task.slice(0, 45),
        created_at: Math.floor(Date.now() / 1000),
        messages: []
      };
      workspaceChatsMap[activeWorkspace.path].unshift(targetChat);
      saveWorkspaceChatsMap();
      renderCodeWorkspacesTree();
    }

    // Open this chat in the UI so the desktop user sees it active
    openCodeChat(activeWorkspace.path, targetChat.id);

    const messagesStream = document.getElementById('code-messages-stream');
    const codeDashboardCard = document.getElementById('code-dashboard-card');
    if (codeDashboardCard) codeDashboardCard.style.display = 'none';
    if (messagesStream) messagesStream.style.display = 'flex';

    if (codeHeaderOrb) codeHeaderOrb.setState('pulsing');

    // Append user remote message to UI
    appendCodeMessage('user', data.task);

    // Report starting status back to mobile
    if (window.newtonAPI?.reportDesktopStep) {
      await window.newtonAPI.reportDesktopStep({
        sessionId: sessionId,
        chatId: targetChat.id,
        workspacePath: activeWorkspace.path,
        stepType: 'agent_message',
        message: `Sesión conectada en Mac [${activeWorkspace.name} / ${targetChat.title}]. Ejecutando agente...`
      });
    }

    // Inspect workspace
    let inspectionPrefix = `[LOCAL WORKSPACE INSPECTION: ${activeWorkspace.name} (${activeWorkspace.path}) | Git Branch: ${activeWorkspace.branch} | Remote Client: Mobile]\n`;
    try {
      const sumRes = await window.newtonAPI?.getWorkspaceSummary(activeWorkspace.path);
      if (sumRes?.success && sumRes.data) {
        const d = sumRes.data;
        if (Array.isArray(d.files)) {
          const fileList = d.files.slice(0, 40).map(f => `${f.isDirectory ? '[DIR] ' : '      '}${f.name}`).join('\n');
          inspectionPrefix += `Local Project Files:\n${fileList}\n`;
        }
        if (d.packageInfo) {
          inspectionPrefix += `Package: ${d.packageInfo.name || 'unnamed'} | Dependencies: ${(d.packageInfo.dependencies || []).join(', ')} | Scripts: ${(d.packageInfo.scripts || []).join(', ')}\n`;
        }
        if (d.readme) {
          inspectionPrefix += `README Snippet:\n${d.readme.slice(0, 800)}\n`;
        }
      }
    } catch (_) {}
    inspectionPrefix += '\n';

    let currentPrompt = inspectionPrefix + data.task;
    let botObj = createCodeAssistantBubble();
    messagesStream.appendChild(botObj.container);
    scrollCodeToBottom();

    let stepCount = 0;

    try {
      while (true) {
        if (isRemoteCancelled) {
          if (window.newtonAPI?.reportDesktopStep) {
            await window.newtonAPI.reportDesktopStep({
              sessionId: sessionId,
              chatId: targetChat.id,
              workspacePath: activeWorkspace.path,
              stepType: 'error',
              message: 'La ejecución fue cancelada desde el dispositivo móvil.'
            });
          }
          updateCodeAssistantBubble(botObj, 'Ejecución cancelada por el usuario desde el móvil.');
          break;
        }

        stepCount++;
        const payload = {
          prompt: currentPrompt,
          model: 'Singularity-Matrix',
          history: codeSessionHistory,
          isGhost: false
        };

        const response = await window.newtonAPI.sendMessage(payload);
        if (!response.success) {
          const errText = response.error || 'Error al ejecutar Singularity Matrix';
          if (window.newtonAPI?.reportDesktopStep) {
            await window.newtonAPI.reportDesktopStep({
              sessionId: sessionId,
              chatId: targetChat.id,
              workspacePath: activeWorkspace.path,
              stepType: 'error',
              message: errText
            });
          }
          updateCodeAssistantBubble(botObj, `Error: ${errText}`);
          break;
        }

        const replyText = response.data?.reply || '';
        updateCodeAssistantBubble(botObj, replyText);

        const toolMatch = replyText.match(/<tool_call>([\s\S]*?)<\/tool_call>/);
        if (!toolMatch) {
          // Finished! Add turns to codeSessionHistory & save to workspace chat
          codeSessionHistory.push({ role: 'user', content: data.task });
          codeSessionHistory.push({ role: 'assistant', content: replyText });
          targetChat.messages = [...codeSessionHistory];
          saveWorkspaceChatsMap();
          renderCodeWorkspacesTree();
          syncDesktopWorkspacesWithChats();

          if (window.newtonAPI?.reportDesktopStep) {
            await window.newtonAPI.reportDesktopStep({
              sessionId: sessionId,
              chatId: targetChat.id,
              workspacePath: activeWorkspace.path,
              stepType: 'task_done',
              message: replyText
            });
          }
          break;
        }

        let parsed = null;
        try {
          parsed = JSON.parse(toolMatch[1].trim());
        } catch (e) {
          break;
        }

        const toolName = parsed.tool;
        const toolParams = parsed.parameters || {};

        // Report tool_start to mobile
        if (window.newtonAPI?.reportDesktopStep) {
          await window.newtonAPI.reportDesktopStep({
            sessionId: sessionId,
            chatId: targetChat.id,
            workspacePath: activeWorkspace.path,
            stepType: 'tool_start',
            toolName: toolName,
            parameters: toolParams,
            message: `Ejecutando herramienta: ${toolName}`
          });
        }

        const toolUI = renderToolCard(toolName, toolParams);
        let toolResult = null;
        try {
          toolResult = await executeMatrixTool(toolName, toolParams, activeWorkspace.path);
          if (toolResult.error) {
            toolUI.setStatus('error', 'Failed');
            toolUI.setOutput(`Error: ${toolResult.error}`);
          } else {
            toolUI.setStatus('success', 'Completed');
            const outPreview = typeof toolResult === 'string'
              ? toolResult
              : (toolResult.content || toolResult.files || toolResult.stdout || toolResult.message || JSON.stringify(toolResult, null, 2));
            toolUI.setOutput(outPreview);
          }
        } catch (tErr) {
          toolResult = { error: tErr.message };
          toolUI.setStatus('error', 'Exception');
          toolUI.setOutput(`Exception: ${tErr.message}`);
        }

        // Report tool_done to mobile
        if (window.newtonAPI?.reportDesktopStep) {
          await window.newtonAPI.reportDesktopStep({
            sessionId: sessionId,
            chatId: targetChat.id,
            workspacePath: activeWorkspace.path,
            stepType: 'tool_done',
            toolName: toolName,
            parameters: toolParams,
            result: toolResult,
            stdout: toolResult?.stdout,
            stderr: toolResult?.stderr,
            message: toolResult?.error ? `Fallo: ${toolResult.error}` : `Éxito: ${toolName}`
          });
        }

        codeSessionHistory.push({ role: 'user', content: currentPrompt });
        codeSessionHistory.push({ role: 'assistant', content: replyText });
        targetChat.messages = [...codeSessionHistory];
        saveWorkspaceChatsMap();
        syncDesktopWorkspacesWithChats();
        let outText = typeof toolResult === 'string'
          ? toolResult
          : (toolResult.content || toolResult.files || toolResult.stdout || toolResult.message || JSON.stringify(toolResult, null, 2));

        const MAX_TOOL_OUTPUT_CHARS = 12000;
        if (typeof outText === 'string' && outText.length > MAX_TOOL_OUTPUT_CHARS) {
          outText = outText.slice(0, MAX_TOOL_OUTPUT_CHARS) + `\n\n[Output truncated: ${outText.length - MAX_TOOL_OUTPUT_CHARS} characters omitted for brevity. Specify line ranges or narrower queries if more details are needed.]`;
        }

        currentPrompt = `<tool_response tool="${toolName}">\n${outText}\n</tool_response>\n\nTool "${toolName}" executed successfully. Now take immediate action: apply the necessary code modifications to the workspace using write_file or edit_file. Do not enter protracted reasoning loops or repeat redundant file reads. If the objective is completely achieved and verified, provide your final response to the user.`;

        botObj = createCodeAssistantBubble();
        messagesStream.appendChild(botObj.container);
        scrollCodeToBottom();
      }
    } catch (err) {
      if (window.newtonAPI?.reportDesktopStep) {
        await window.newtonAPI.reportDesktopStep({
          sessionId: sessionId,
          stepType: 'error',
          message: err.message
        });
      }
    } finally {
      if (codeHeaderOrb) codeHeaderOrb.setState('orbits');
      scrollCodeToBottom();
    }
  }

  function appendCodeMessage(role, text) {
    const messagesStream = document.getElementById('code-messages-stream');
    if (!messagesStream) return;

    if (role === 'user') {
      const bubble = document.createElement('div');
      bubble.className = 'code-bubble-user';
      bubble.textContent = text;
      messagesStream.appendChild(bubble);
      scrollCodeToBottom();
    }
  }

  function createThinkingCardElement(label = 'Newton is reasoning') {
    const card = document.createElement('details');
    card.className = 'thinking-card-code';
    card.style.display = 'block';
    card.open = true;

    const summary = document.createElement('summary');
    summary.className = 'thinking-summary-code';
    summary.innerHTML = `
      <div class="thinking-summary-left-code">
        <span>${escapeHtml(label)}</span>
      </div>
      <i class="f7-icons" style="font-size: 11px; color: #888;">chevron_down</i>
    `;

    const body = document.createElement('div');
    body.className = 'thinking-body-code';

    card.appendChild(summary);
    card.appendChild(body);

    const chevron = summary.querySelector('.f7-icons');
    card.addEventListener('toggle', () => {
      card._userToggled = true;
      if (chevron) {
        chevron.textContent = card.open ? 'chevron_up' : 'chevron_down';
      }
    });

    return { card, body, chevron };
  }

  function createCodeAssistantBubble() {
    const container = document.createElement('div');
    container.className = 'code-bubble-bot';

    const thinkingContainer = document.createElement('div');
    thinkingContainer.className = 'thinking-container-code';

    const content = document.createElement('div');
    content.className = 'markdown-body markdown-body-code';

    // Thinking Orb Indicator (iOS Parity: ThinkingOrbView globe + "Newton está razonando...")
    let orbInstance = null;
    const thinkingRow = document.createElement('div');
    thinkingRow.className = 'thinking-indicator-row';
    const orbSlotMain = document.createElement('div');
    orbSlotMain.className = 'thinking-orb-slot';
    const thinkingLabel = document.createElement('span');
    thinkingLabel.className = 'thinking-label';
    thinkingLabel.textContent = 'Newton is reasoning';
    thinkingRow.appendChild(orbSlotMain);
    thinkingRow.appendChild(thinkingLabel);

    content.appendChild(thinkingRow);
    if (typeof window.createThinkingOrb === 'function') {
      orbInstance = window.createThinkingOrb(orbSlotMain, { state: 'globe', size: 32, isDark: true });
    }

    container.appendChild(thinkingContainer);
    container.appendChild(content);

    return {
      container,
      thinkingContainer,
      thinkingCards: [],
      content,
      orbInstance
    };
  }

  function syncThinkingCards(botObj, fullText) {
    if (!botObj || !fullText) return;

    // Split stream or text by <thinking> tags
    const blocks = [];
    const regex = /<thinking>([\s\S]*?)(?:<\/thinking>|$)/g;
    let match;
    let anyUnclosed = false;
    while ((match = regex.exec(fullText)) !== null) {
      if (match[1] && match[1].trim()) {
        const isClosed = fullText.slice(match.index).indexOf('</thinking>') !== -1;
        if (!isClosed) anyUnclosed = true;
        blocks.push(match[1].trim());
      }
    }

    if (!blocks.length) return;

    if (!botObj.thinkingCards) botObj.thinkingCards = [];

    // Keep a single unified card per turn
    if (botObj.thinkingCards.length === 0) {
      const cardObj = createThinkingCardElement('Razonamiento');
      botObj.thinkingContainer.appendChild(cardObj.card);
      botObj.thinkingCards.push(cardObj);
    }

    const c = botObj.thinkingCards[0];
    const consolidatedText = blocks.join('\n\n---\n\n');

    if (c.body.textContent !== consolidatedText) {
      c.body.textContent = consolidatedText;
    }

    // Auto-collapse only once all thinking tags are closed and user hasn't toggled
    if (!anyUnclosed) {
      if (!c.card._userToggled) {
        c.card.open = false;
        if (c.chevron) c.chevron.textContent = 'chevron_down';
      }
    } else {
      c.card.open = true;
      if (c.chevron) c.chevron.textContent = 'chevron_up';
    }

    botObj._lastThinking = consolidatedText;
  }

  function renderCodeContentImmediate(botObj, cleanText) {
    if (cleanText) {
      if (botObj.orbInstance) { botObj.orbInstance.destroy(); botObj.orbInstance = null; }
      botObj.content.style.display = 'block';
      const html = parseMarkdownSync(cleanText);
      if (html != null) {
        const tpl = document.createElement('template'); tpl.innerHTML = html;
        botObj.content.replaceChildren(tpl.content.cloneNode(true));
      } else {
        botObj.content.textContent = cleanText;
        ensureMarked().then(mod => {
          if (mod && botObj.content.textContent === cleanText) {
            const h2 = parseMarkdownSync(cleanText);
            if (h2 != null) { const t2 = document.createElement('template'); t2.innerHTML = h2; botObj.content.replaceChildren(t2.content.cloneNode(true)); bindCopyButtons(botObj.content); }
          }
        });
      }
    } else {
      if (fullTextHasToolCall(botObj._lastFullText || '')) {
        if (botObj.orbInstance) { botObj.orbInstance.destroy(); botObj.orbInstance = null; }
        botObj.content.style.display = 'none'; botObj.content.replaceChildren();
      } else if ((botObj._lastThinking || '').trim()) {
        if (botObj.orbInstance) { botObj.orbInstance.destroy(); botObj.orbInstance = null; }
        botObj.content.style.display = 'none'; botObj.content.replaceChildren();
      } else {
        botObj.content.style.display = 'block';
        if (!botObj.content.querySelector('.thinking-indicator-row')) {
          botObj.content.replaceChildren();
          const thinkingRow = document.createElement('div');
          thinkingRow.className = 'thinking-indicator-row';
          const orbSlotMain = document.createElement('div'); orbSlotMain.className = 'thinking-orb-slot';
          const thinkingLabel = document.createElement('span'); thinkingLabel.className = 'thinking-label'; thinkingLabel.textContent = 'Newton is reasoning';
          thinkingRow.append(orbSlotMain, thinkingLabel);
          botObj.content.appendChild(thinkingRow);
          if (typeof window.createThinkingOrb === 'function') botObj.orbInstance = window.createThinkingOrb(orbSlotMain, { state: 'globe', size: 32, isDark: true });
        }
      }
    }
    bindCopyButtons(botObj.content);
  }
  function fullTextHasToolCall(t) { return t.includes('<tool_call'); }
  function bindCopyButtons(root) {
    root.querySelectorAll('pre').forEach(pre => {
      if (pre.querySelector('.btn-copy-code-block')) return;
      const copyBtn = document.createElement('button');
      copyBtn.className = 'btn-copy-code-block';
      copyBtn.innerHTML = '<i class="f7-icons" style="font-size: 11px;">doc_on_doc</i>';
      copyBtn.title = 'Copiar código';
      copyBtn.addEventListener('click', () => {
        const code = pre.querySelector('code')?.innerText || pre.innerText;
        navigator.clipboard.writeText(code);
        copyBtn.innerHTML = '<i class="f7-icons" style="font-size: 11px; color: #4ed187;">checkmark</i>';
        setTimeout(() => { copyBtn.innerHTML = '<i class="f7-icons" style="font-size: 11px;">doc_on_doc</i>'; }, 1500);
      });
      pre.style.position = 'relative';
      Object.assign(copyBtn.style, { position: 'absolute', top: '6px', right: '6px', background: 'rgba(255,255,255,0.08)', border: 'none', borderRadius: '4px', padding: '3px 6px', cursor: 'pointer', color: '#bbb' });
      pre.appendChild(copyBtn);
    });
  }
  function stripInternalAgentMarkup(fullText) {
    if (!fullText) return '';
    return fullText
      .replace(/<thinking>[\s\S]*?(?:<\/thinking>|$)/g, '')
      .replace(/<tool_call>[\s\S]*?(?:<\/tool_call>|$)/g, '')
      .replace(/<tool_results>[\s\S]*?(?:<\/tool_results>|$)/g, '')
      .replace(/<system_gate>[\s\S]*?(?:<\/system_gate>|$)/g, '')
      .replace(/<system_notice>[\s\S]*?(?:<\/system_notice>|$)/g, '')
      .replace(/[\s\S]*?<\/tool_call>/g, '') // Catch orphaned closing tags from stream/compact cuts
      .trim();
  }

  function updateCodeAssistantBubble(botObj, fullText) {
    if (!botObj || !fullText) return;
    botObj._lastFullText = fullText;

    syncThinkingCards(botObj, fullText);

    const cleanText = stripInternalAgentMarkup(fullText);

    scheduleMarkdownRender(botObj, cleanText, (text) => renderCodeContentImmediate(botObj, text));
  }

  function updateCodeAssistantBubbleImmediate(botObj, fullText) {
    if (!botObj || !fullText) return;
    botObj._lastFullText = fullText;

    syncThinkingCards(botObj, fullText);

    const cleanText = stripInternalAgentMarkup(fullText);

    _mdPending.delete(botObj);
    renderCodeContentImmediate(botObj, cleanText);
  }

  // 7. Quick Nav buttons (+ New task, Overview tab, Breadcrumb ws click)
  function setupCodeQuickNav() {
    const btnNewTask = document.getElementById('btn-code-new-task');
    btnNewTask?.addEventListener('click', startNewCodeTask);

    const btnViewDashboard = document.getElementById('btn-code-view-dashboard');
    btnViewDashboard?.addEventListener('click', startNewCodeTask);

    const btnHeaderWs = document.getElementById('btn-header-ws');
    btnHeaderWs?.addEventListener('click', handleCycleWorkspace);
  }

  // =========================================================================
  // 8. Authentication System Controller (Login / Register / Direct Key / Logout)
  // =========================================================================
  let authOrb = null;

  function setupAuthSystem() {
    const authModal = document.getElementById('auth-modal');
    const btnDismissAuth = document.getElementById('btn-dismiss-auth');
    const tabLogin = document.getElementById('tab-auth-login');
    const tabRegister = document.getElementById('tab-auth-register');
    const tabKey = document.getElementById('tab-auth-key');

    const formLogin = document.getElementById('form-auth-login');
    const formRegister = document.getElementById('form-auth-register');
    const formKey = document.getElementById('form-auth-key');

    const alertBanner = document.getElementById('auth-alert-banner');
    const alertMsg = document.getElementById('auth-alert-msg');

    const btnToggleLoginPwd = document.getElementById('btn-toggle-login-pwd');
    const btnToggleRegPwd = document.getElementById('btn-toggle-reg-pwd');
    const loginPwdInput = document.getElementById('login-password');
    const regPwdInput = document.getElementById('register-password');

    // Dismiss button (only shown if user is already authenticated and opened modal to switch accounts)
    btnDismissAuth?.addEventListener('click', () => {
      if (authModal) authModal.style.display = 'none';
    });

    // Password visibility toggles
    btnToggleLoginPwd?.addEventListener('click', () => {
      if (!loginPwdInput) return;
      const isPwd = loginPwdInput.type === 'password';
      loginPwdInput.type = isPwd ? 'text' : 'password';
      const icon = btnToggleLoginPwd.querySelector('i');
      if (icon) icon.textContent = isPwd ? 'eye_slash' : 'eye';
    });

    btnToggleRegPwd?.addEventListener('click', () => {
      if (!regPwdInput) return;
      const isPwd = regPwdInput.type === 'password';
      regPwdInput.type = isPwd ? 'text' : 'password';
      const icon = btnToggleRegPwd.querySelector('i');
      if (icon) icon.textContent = isPwd ? 'eye_slash' : 'eye';
    });

    // Tab switcher
    tabLogin?.addEventListener('click', () => switchAuthTab('login'));
    tabRegister?.addEventListener('click', () => switchAuthTab('register'));
    tabKey?.addEventListener('click', () => switchAuthTab('key'));

    function switchAuthTab(tab) {
      if (tabLogin) tabLogin.classList.toggle('active', tab === 'login');
      if (tabRegister) tabRegister.classList.toggle('active', tab === 'register');
      if (tabKey) tabKey.classList.toggle('active', tab === 'key');

      if (formLogin) formLogin.style.display = tab === 'login' ? 'flex' : 'none';
      if (formRegister) formRegister.style.display = tab === 'register' ? 'flex' : 'none';
      if (formKey) formKey.style.display = tab === 'key' ? 'flex' : 'none';

      hideAuthAlert();
    }

    function showAuthAlert(message, isSuccess = false) {
      if (!alertBanner || !alertMsg) return;
      alertBanner.classList.toggle('success', isSuccess);
      const icon = alertBanner.querySelector('.auth-alert-icon');
      if (icon) icon.textContent = isSuccess ? 'checkmark_circle_fill' : 'exclamationmark_triangle_fill';
      alertMsg.textContent = message;
      alertBanner.style.display = 'flex';
    }

    function hideAuthAlert() {
      if (alertBanner) alertBanner.style.display = 'none';
    }

    // 1. Submit Login
    formLogin?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const usernameInput = document.getElementById('login-username');
      const username = usernameInput?.value.trim();
      const password = loginPwdInput?.value;
      const btnSubmit = document.getElementById('btn-submit-login');

      if (!username || !password) return;

      if (btnSubmit) {
        btnSubmit.disabled = true;
        btnSubmit.innerHTML = '<span>Verificando credenciales...</span><i class="f7-icons">arrow_2_circlepath</i>';
      }
      hideAuthAlert();

      try {
        const res = await window.newtonAPI.login({ username, password });
        if (res.success && res.data) {
          showAuthAlert(`¡Bienvenido, ${res.data.username || username}! Conectando...`, true);
          setTimeout(async () => {
            authModal.style.display = 'none';
            if (btnSubmit) {
              btnSubmit.disabled = false;
              btnSubmit.innerHTML = '<span>Entrar a Newton</span><i class="f7-icons">arrow_right</i>';
            }
            await refreshAppStateAfterAuth();
          }, 600);
        } else {
          showAuthAlert(res.error || 'Credenciales inválidas. Verifica tu usuario y contraseña.');
          if (btnSubmit) {
            btnSubmit.disabled = false;
            btnSubmit.innerHTML = '<span>Entrar a Newton</span><i class="f7-icons">arrow_right</i>';
          }
        }
      } catch (err) {
        showAuthAlert(err.message || 'Error de conexión con el servidor.');
        if (btnSubmit) {
          btnSubmit.disabled = false;
          btnSubmit.innerHTML = '<span>Entrar a Newton</span><i class="f7-icons">arrow_right</i>';
        }
      }
    });

    // 2. Submit Register
    formRegister?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const username = document.getElementById('register-username')?.value.trim();
      const email = document.getElementById('register-email')?.value.trim();
      const password = regPwdInput?.value;
      const tier = document.getElementById('register-tier')?.value || 'base';
      const btnSubmit = document.getElementById('btn-submit-register');

      if (!username || !email || !password) return;

      if (btnSubmit) {
        btnSubmit.disabled = true;
        btnSubmit.innerHTML = '<span>Aprovisionando cuenta...</span><i class="f7-icons">arrow_2_circlepath</i>';
      }
      hideAuthAlert();

      try {
        const res = await window.newtonAPI.register({ username, email, password, tier });
        if (res.success && res.data) {
          showAuthAlert('¡Cuenta aprovisionada con éxito! Iniciando sesión...', true);
          setTimeout(async () => {
            authModal.style.display = 'none';
            if (btnSubmit) {
              btnSubmit.disabled = false;
              btnSubmit.innerHTML = '<span>Crear Cuenta</span><i class="f7-icons">plus</i>';
            }
            await refreshAppStateAfterAuth();
          }, 700);
        } else {
          showAuthAlert(res.error || 'No se pudo crear la cuenta.');
          if (btnSubmit) {
            btnSubmit.disabled = false;
            btnSubmit.innerHTML = '<span>Crear Cuenta</span><i class="f7-icons">plus</i>';
          }
        }
      } catch (err) {
        showAuthAlert(err.message || 'Error al registrar.');
        if (btnSubmit) {
          btnSubmit.disabled = false;
          btnSubmit.innerHTML = '<span>Crear Cuenta</span><i class="f7-icons">plus</i>';
        }
      }
    });

    // 3. Submit Direct Key
    formKey?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const keyInput = document.getElementById('input-direct-api-key');
      const key = keyInput?.value.trim();
      const btnSubmit = document.getElementById('btn-submit-key');

      if (!key) return;

      if (btnSubmit) {
        btnSubmit.disabled = true;
        btnSubmit.innerHTML = '<span>Validando clave...</span><i class="f7-icons">arrow_2_circlepath</i>';
      }
      hideAuthAlert();

      try {
        await window.newtonAPI.setApiKey(key);
        const meRes = await window.newtonAPI.getMe();
        if (meRes.success && meRes.data) {
          showAuthAlert('Clave verificada exitosamente.', true);
          setTimeout(async () => {
            authModal.style.display = 'none';
            if (btnSubmit) {
              btnSubmit.disabled = false;
              btnSubmit.innerHTML = '<span>Conectar Clave</span><i class="f7-icons">link</i>';
            }
            await refreshAppStateAfterAuth();
          }, 600);
        } else {
          showAuthAlert('La clave API no es válida o fue rechazada por el servidor.');
          if (btnSubmit) {
            btnSubmit.disabled = false;
            btnSubmit.innerHTML = '<span>Conectar Clave</span><i class="f7-icons">link</i>';
          }
        }
      } catch (err) {
        showAuthAlert(err.message || 'Error al validar la clave API.');
        if (btnSubmit) {
          btnSubmit.disabled = false;
          btnSubmit.innerHTML = '<span>Conectar Clave</span><i class="f7-icons">link</i>';
        }
      }
    });
  }

  function showAuthScreen(allowDismiss = false) {
    const authModal = document.getElementById('auth-modal');
    const btnDismissAuth = document.getElementById('btn-dismiss-auth');
    const orbContainer = document.getElementById('auth-orb-container');

    if (!authModal) return;
    if (btnDismissAuth) {
      btnDismissAuth.style.display = allowDismiss ? 'block' : 'none';
    }

    if (orbContainer && !authOrb && typeof window.createThinkingOrb === 'function') {
      authOrb = window.createThinkingOrb(orbContainer, { state: 'orbits', size: 36, isDark: true });
    }

    authModal.style.display = 'flex';
  }

  async function handleLogout() {
    if (!confirm('¿Cerrar sesión en Newton AI Desktop?\nSe revocará el acceso local a tu cuenta y deberás iniciar sesión para continuar.')) {
      return;
    }

    try {
      if (settingsModal) settingsModal.style.display = 'none';
      await window.newtonAPI.logout();

      // Reset application state
      fullApiKey = '';
      currentChatId = null;
      window.loadedChats = [];
      if (userEmail) userEmail.textContent = 'Sin sesión';
      if (userCredits) userCredits.textContent = '--';
      if (userTier) userTier.textContent = 'Invitado';
      if (userAvatar) userAvatar.textContent = '?';

      const codeUserName = document.getElementById('code-user-name');
      const codeUserFirstName = document.getElementById('code-user-first-name');
      if (codeUserName) codeUserName.textContent = 'Invitado · Gateway';
      if (codeUserFirstName) codeUserFirstName.textContent = 'Invitado';

      if (chatHistoryList) {
        chatHistoryList.innerHTML = '<div class="history-item empty-placeholder"><span>Inicia sesión para ver tus conversaciones</span></div>';
      }
      if (messagesContainer) messagesContainer.replaceChildren();
      if (welcomeScreen) welcomeScreen.style.display = 'flex';
      if (activeChatTitle) activeChatTitle.textContent = 'Nueva Conversación';

      // Reset code mode messages
      const codeMessagesStream = document.getElementById('code-messages-stream');
      const codeDashboardCard = document.getElementById('code-dashboard-card');
      if (codeMessagesStream) {
        codeMessagesStream.replaceChildren();
        codeMessagesStream.style.display = 'none';
      }
      if (codeDashboardCard) codeDashboardCard.style.display = 'flex';

      showAuthScreen(false); // locked mode
    } catch (err) {
      alert('Error al cerrar sesión: ' + err.message);
    }
  }

  async function refreshAppStateAfterAuth() {
    await Promise.allSettled([
      loadUserProfile(),
      loadModels(),
      loadChats()
    ]);
  }
});
