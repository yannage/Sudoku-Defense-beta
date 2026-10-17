const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('node:path');
const { createGameServer } = require('./server.cjs');
const { serializeStorage, readStorage, writeStorage } = require('./storage.cjs');

let window;
let gameServer;
let storagePath;
let lastSaved = '';

function trusted(event) {
  if (!window || event.sender !== window.webContents || event.senderFrame !== window.webContents.mainFrame) return false;
  try { return new URL(event.senderFrame.url).origin === gameServer.origin; } catch { return false; }
}
function save(event, value) {
  if (!trusted(event)) return false;
  const json = serializeStorage(value);
  if (json === null) return false;
  try {
    if (json !== lastSaved) writeStorage(storagePath, json);
    lastSaved = json;
    return true;
  } catch (error) { console.error('Could not save Gridfall data:', error.message); return false; }
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (window) { if (window.isMinimized()) window.restore(); window.focus(); }
  });
  app.whenReady().then(async () => {
    storagePath = path.join(app.getPath('userData'), 'game-storage.json');
    gameServer = await createGameServer(path.join(__dirname, '..', 'dist'));
    ipcMain.on('gridfall:storage:load', event => { event.returnValue = trusted(event) ? readStorage(storagePath) : {}; });
    ipcMain.on('gridfall:storage:save', save);
    ipcMain.on('gridfall:storage:save-sync', (event, data) => { event.returnValue = save(event, data); });
    window = new BrowserWindow({
      width: 1280, height: 800, minWidth: 960, minHeight: 600,
      icon: path.join(__dirname, 'icon.png'),
      title: 'Gridfall', backgroundColor: '#12132b', show: false,
      fullscreen: !process.argv.includes('--windowed'), autoHideMenuBar: true,
      webPreferences: {
        preload: path.join(__dirname, 'preload.cjs'),
        nodeIntegration: false, contextIsolation: true, sandbox: true,
        webSecurity: true, backgroundThrottling: true
      }
    });
    window.setMenu(null);
    window.webContents.session.setPermissionRequestHandler((_contents, _permission, callback) => callback(false));
    window.webContents.session.setPermissionCheckHandler(() => false);
    window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
    window.webContents.on('will-navigate', (event, url) => {
      if (new URL(url).origin !== gameServer.origin) event.preventDefault();
    });
    window.webContents.on('will-attach-webview', event => event.preventDefault());
    window.webContents.on('before-input-event', (event, input) => {
      if (input.type === 'keyDown' && input.key === 'F11') { event.preventDefault(); window.setFullScreen(!window.isFullScreen()); }
      if (input.type === 'keyDown' && input.key === 'F12' && !app.isPackaged) window.webContents.toggleDevTools();
    });
    window.once('ready-to-show', () => window.show());
    window.on('closed', () => { window = null; });
    await window.loadURL(gameServer.origin);
  }).catch(error => {
    console.error(error);
    dialog.showErrorBox('Gridfall could not start', error.message);
    app.quit();
  });
  app.on('window-all-closed', () => app.quit());
  app.on('will-quit', () => { gameServer?.close().catch(console.error); });
}
