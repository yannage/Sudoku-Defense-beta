const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');

const CONTENT_TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp',
  '.woff2': 'font/woff2', '.woff': 'font/woff', '.ico': 'image/x-icon',
  '.wav': 'audio/wav', '.ogg': 'audio/ogg', '.mp3': 'audio/mpeg', '.wasm': 'application/wasm'
};

const CSP = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; media-src 'self' blob:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'";

/** An offline HTTP origin for ES modules. Serves only files below root on loopback. */
async function createGameServer(root, { port = 0 } = {}) {
  const base = await fs.realpath(root);
  let origin = '';
  const server = http.createServer(async (req, res) => {
    res.setHeader('Content-Security-Policy', CSP);
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Referrer-Policy', 'no-referrer');
    const fail = code => { res.writeHead(code); res.end(http.STATUS_CODES[code]); };
    if (req.headers.host !== new URL(origin).host) return fail(403);
    if (req.method !== 'GET' && req.method !== 'HEAD') return fail(405);
    try {
      const url = new URL(req.url, origin);
      if (url.origin !== origin) return fail(403);
      const pathname = decodeURIComponent(url.pathname);
      if (pathname.includes('\0') || pathname.includes('\\') || pathname.split('/').some(p => p.startsWith('.'))) return fail(403);
      const relative = pathname === '/' ? 'index.html' : pathname.slice(1);
      const candidate = path.resolve(base, relative);
      if (!candidate.startsWith(base + path.sep)) return fail(403);
      const target = await fs.realpath(candidate);
      if (!target.startsWith(base + path.sep)) return fail(403);
      const type = CONTENT_TYPES[path.extname(target).toLowerCase()];
      if (!type) return fail(403);
      const stat = await fs.stat(target);
      if (!stat.isFile()) return fail(404);
      const data = req.method === 'HEAD' ? null : await fs.readFile(target);
      res.writeHead(200, { 'Content-Type': type, 'Content-Length': stat.size });
      res.end(data);
    } catch (error) {
      fail(error instanceof URIError ? 400 : 404);
    }
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', resolve);
  });
  origin = `http://127.0.0.1:${server.address().port}`;
  return {
    origin,
    close: () => new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()))
  };
}

module.exports = { createGameServer };
