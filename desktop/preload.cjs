const { ipcRenderer } = require('electron');

// No Node or IPC objects are exposed to game code. Carry localStorage between
// randomly allocated local HTTP ports through a single bounded JSON file.
try {
  const saved = ipcRenderer.sendSync('gridfall:storage:load');
  localStorage.clear();
  for (const [key, value] of Object.entries(saved || {})) localStorage.setItem(key, value);
} catch (error) { console.warn('Could not restore Gridfall settings.', error); }

let previous = '';
function snapshot(sync = false) {
  try {
    const data = Object.fromEntries(Array.from({ length: localStorage.length }, (_, i) => {
      const key = localStorage.key(i);
      return [key, localStorage.getItem(key)];
    }));
    const json = JSON.stringify(data);
    if (json === previous) return;
    if (sync) ipcRenderer.sendSync('gridfall:storage:save-sync', data);
    else ipcRenderer.send('gridfall:storage:save', data);
    previous = json;
  } catch (error) { console.warn('Could not persist Gridfall settings.', error); }
}
setInterval(() => snapshot(), 2000);
window.addEventListener('pagehide', () => snapshot(true));
document.addEventListener('visibilitychange', () => { if (document.hidden) snapshot(true); });
