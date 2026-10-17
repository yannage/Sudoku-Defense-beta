import { readdir, readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = path.resolve(fileURLToPath(new URL('../dist/', import.meta.url)));
await stat(path.join(root, 'index.html'));
let scripts = 0;
async function check(folder) {
  for (const entry of await readdir(folder, { withFileTypes: true })) {
    const filename = path.join(folder, entry.name);
    if (entry.isDirectory()) await check(filename);
    else if (/\.(?:m?js)$/.test(entry.name)) {
      const result = spawnSync(process.execPath, ['--check', filename], { encoding: 'utf8' });
      if (result.status !== 0) throw new Error(result.stderr || `Syntax error: ${filename}`);
      scripts++;
    }
  }
}
await check(root);
const html = await readFile(path.join(root, 'index.html'), 'utf8');
if (!html.includes('<html') || !html.includes('</html>')) throw new Error('dist/index.html is incomplete.');
for (const match of html.matchAll(/(?:src|href)=["']([^"']+)["']/g)) {
  const reference = match[1];
  if (/^(?:[a-z]+:|\/\/|#)/i.test(reference)) continue;
  const local = path.resolve(root, reference.replace(/^\//, '').split(/[?#]/)[0]);
  if (local !== root && !local.startsWith(root + path.sep)) throw new Error(`Asset escapes dist: ${reference}`);
  try { await stat(local); } catch { throw new Error(`Missing HTML asset: ${reference}`); }
}
console.log(`Static build ready: dist/index.html and ${scripts} checked JavaScript modules.`);
