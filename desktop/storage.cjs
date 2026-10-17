const fs = require('node:fs');
const path = require('node:path');

const MAX_BYTES = 1024 * 1024;
function serializeStorage(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const entries = Object.entries(value);
  if (entries.some(([key, item]) => key.length > 512 || typeof item !== 'string')) return null;
  const json = JSON.stringify(Object.fromEntries(entries));
  return Buffer.byteLength(json) <= MAX_BYTES ? json : null;
}
function readStorage(filename) {
  try {
    if (fs.statSync(filename).size > MAX_BYTES) return {};
    const value = JSON.parse(fs.readFileSync(filename, 'utf8'));
    return serializeStorage(value) === null ? {} : value;
  } catch { return {}; }
}
function writeStorage(filename, json) {
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  fs.writeFileSync(`${filename}.tmp`, json, { mode: 0o600 });
  fs.renameSync(`${filename}.tmp`, filename);
}
module.exports = { serializeStorage, readStorage, writeStorage };
