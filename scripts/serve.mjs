import http from 'node:http';
import { readFile, realpath } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const port = Number(process.env.PORT || 4173);
const root = await realpath(fileURLToPath(new URL('../dist/', import.meta.url)));
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.json': 'application/json', '.woff2': 'font/woff2', '.ogg': 'audio/ogg', '.mp3': 'audio/mpeg', '.wav': 'audio/wav' };
// Development-only public bind lets the Sites preview proxy reach this server.
// The packaged desktop application uses its separate loopback-only server.
const server = http.createServer(async (req, res) => {
  const fail = status => { res.writeHead(status); res.end(http.STATUS_CODES[status]); };
  if (req.method !== 'GET' && req.method !== 'HEAD') return fail(405);
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    if (pathname.includes('\0') || pathname.includes('\\') || pathname.split('/').some(part => part.startsWith('.'))) return fail(403);
    const candidate = path.resolve(root, pathname === '/' ? 'index.html' : pathname.slice(1));
    const filename = await realpath(candidate);
    if (!filename.startsWith(root + path.sep)) return fail(403);
    const data = await readFile(filename);
    res.writeHead(200, { 'Content-Type': types[path.extname(filename)] || 'application/octet-stream', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    res.end(req.method === 'HEAD' ? null : data);
  } catch (error) { fail(error instanceof URIError ? 400 : 404); }
});
server.listen(port, '0.0.0.0', () => console.log(`Sudoku Defense preview is running on http://0.0.0.0:${port}`));
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(() => process.exit(0)));
