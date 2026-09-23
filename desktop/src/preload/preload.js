const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('newtonAPI', {
  // AI & Gateway
  getMe: () => ipcRenderer.invoke('ai:get-me'),
  getConfig: () => ipcRenderer.invoke('ai:get-config'),
  rotateKey: () => ipcRenderer.invoke('ai:rotate-key'),
  getModels: () => ipcRenderer.invoke('ai:get-models'),
  getChats: (params) => ipcRenderer.invoke('ai:get-chats', params),
  createChat: (data) => ipcRenderer.invoke('ai:create-chat', data),
  getChatMessages: (params) => ipcRenderer.invoke('ai:get-messages', params),
  updateChat: (params) => ipcRenderer.invoke('ai:update-chat', params),
  deleteChat: (chatId) => ipcRenderer.invoke('ai:delete-chat', chatId),
  getUsage: () => ipcRenderer.invoke('ai:get-usage'),
  getUsageHistory: (params) => ipcRenderer.invoke('ai:get-usage-history', params),
  uploadFile: (payload) => ipcRenderer.invoke('ai:upload-file', payload),
  getFileMetadata: (fileId) => ipcRenderer.invoke('ai:get-file-metadata', fileId),
  generateTitle: (prompt) => ipcRenderer.invoke('ai:generate-title', prompt),
  generateImage: (data) => ipcRenderer.invoke('ai:generate-image', data),
  sendMessage: (payload) => ipcRenderer.invoke('ai:send-message', payload),
  getAppInfo: () => ipcRenderer.invoke('app:get-info'),
  onStreamChunk: (callback) => {
    const listener = (_event, chunk) => callback(chunk);
    ipcRenderer.on('ai:stream-chunk', listener);
    return () => ipcRenderer.removeListener('ai:stream-chunk', listener);
  },
  onCloudSyncEvent: (callback) => {
    const listener = (_event, data) => callback(data);
    ipcRenderer.on('sync:cloud-event', listener);
    return () => ipcRenderer.removeListener('sync:cloud-event', listener);
  },
  onDesktopRemoteEvent: (callback) => {
    const listener = (_event, data) => callback(data);
    ipcRenderer.on('desktop:remote-event', listener);
    return () => ipcRenderer.removeListener('desktop:remote-event', listener);
  },
  syncDesktopWorkspaces: (workspaces) => ipcRenderer.invoke('desktop:sync-workspaces', workspaces),
  reportDesktopStep: (payload) => ipcRenderer.invoke('desktop:report-step', payload),
  desktopHeartbeat: (activeWorkspace) => ipcRenderer.invoke('desktop:heartbeat', activeWorkspace),

  // Auth Management
  login: (credentials) => ipcRenderer.invoke('auth:login', credentials),
  register: (payload) => ipcRenderer.invoke('auth:register', payload),
  logout: () => ipcRenderer.invoke('auth:logout'),
  setApiKey: (apiKey) => ipcRenderer.invoke('auth:set-api-key', apiKey),
  getAuthStatus: () => ipcRenderer.invoke('auth:status'),
  resendVerification: (email) => ipcRenderer.invoke('auth:resend-verification', email),

  // Workspace, Files & Terminal
  listWorkspaces: () => ipcRenderer.invoke('workspace:list'),
  addWorkspace: (folderPath) => ipcRenderer.invoke('workspace:add', folderPath),
  removeWorkspace: (folderPath) => ipcRenderer.invoke('workspace:remove', folderPath),
  getWorkspaceSummary: (workspacePath) => ipcRenderer.invoke('workspace:get-summary', workspacePath),
  getBranch: (workspacePath) => ipcRenderer.invoke('workspace:get-branch', workspacePath),
  listFiles: (params) => ipcRenderer.invoke('workspace:list-files', params),
  readFile: (params) => ipcRenderer.invoke('workspace:read-file', params),
  writeFile: (params) => ipcRenderer.invoke('workspace:write-file', params),
  editFile: (params) => ipcRenderer.invoke('workspace:edit-file', params),
  grepSearch: (params) => ipcRenderer.invoke('workspace:grep-search', params),
  createFile: (params) => ipcRenderer.invoke('workspace:create-file', params),
  deleteFile: (params) => ipcRenderer.invoke('workspace:delete-file', params),
  execBash: (params) => ipcRenderer.invoke('workspace:exec-bash', params),
  git: (params) => ipcRenderer.invoke('workspace:git', params),
  loadCodeChats: () => ipcRenderer.invoke('code-chats:load'),
  saveCodeChats: (params) => ipcRenderer.invoke('code-chats:save', params),
  chooseFolder: () => ipcRenderer.invoke('workspace:choose-folder')
});
