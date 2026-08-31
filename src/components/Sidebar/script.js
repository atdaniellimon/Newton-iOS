// src/components/Sidebar/script.js
(() => {
	const sidebar = document.querySelector('.side-bar');
	const header = sidebar?.querySelector('header');
	const backdrop = document.getElementById('sidebar-backdrop');
	const mobileToggle = document.getElementById('mobile-sidebar-toggle');
	const headerNewChatBtn = document.getElementById('header-new-chat-btn');

	window.toggleMobileSidebar = () => {
		if (!sidebar) return;
		const isOpened = sidebar.classList.toggle('mobile-open');
		if (backdrop) {
			backdrop.classList.toggle('active', isOpened);
		}
	};

	window.closeMobileSidebar = () => {
		if (sidebar) sidebar.classList.remove('mobile-open');
		if (backdrop) backdrop.classList.remove('active');
	};

	if (mobileToggle) {
		mobileToggle.addEventListener('click', (e) => {
			e.stopPropagation();
			window.toggleMobileSidebar();
		});
	}

	if (backdrop) {
		backdrop.addEventListener('click', () => {
			window.closeMobileSidebar();
		});
	}

	if (headerNewChatBtn) {
		headerNewChatBtn.addEventListener('click', () => {
			if (typeof createNewConversation === 'function') createNewConversation();
			if (typeof clearChatDisplay === 'function') clearChatDisplay();
			if (typeof renderConversationList === 'function') renderConversationList();
			window.closeMobileSidebar();
		});
	}

	if (header) {
		header.addEventListener('click', async (e) => {
			const btn = e.target.closest('button');
			if (!btn) return;
			const nav = btn.getAttribute('act');
			if (nav) {
				window.closeMobileSidebar();
				await Moke.navigate(`/${nav}`);

				switch (nav) {
					case 'code':
						// Cargar el componente Code si no está cargado
						if (!window._codeComponent) {
							try {
								const module = await import('/src/components/Code/script.js');
								const CodeComponent = module.default;
								window._codeComponent = new CodeComponent();
							} catch (err) {
								console.error('Failed to load Code component:', err);
								Moke.alert('Could not load Code editor. Check console.');
							}
						} else {
							// Refresh editor if already loaded
							window._codeComponent.refresh();
							window._codeComponent.loadFiles();
						}
						break;
					case 'app':
						// Lógica existente: crear nueva conversación o limpiar
						if (typeof createNewConversation === 'function') createNewConversation();
						if (typeof clearChatDisplay === 'function') clearChatDisplay();
						if (typeof renderConversationList === 'function') renderConversationList();
						break;
					default:
						break;
				}
			}
		});
	}
})();