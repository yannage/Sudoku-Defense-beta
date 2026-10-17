import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, symlink, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { createGameServer } from '../desktop/server.cjs';
import { serializeStorage, readStorage, writeStorage } from '../desktop/storage.cjs';

test('offline server serves ES modules and rejects writes, invalid hosts, and escaped paths', async t => {
  const root = await mkdtemp(path.join(tmpdir(), 'gridfall-http-'));
  await writeFile(path.join(root, 'index.html'), '<html>Gridfall</html>');
  await writeFile(path.join(root, 'game.js'), 'export const ready = true;');
  await writeFile(path.join(root, '.private.json'), '{"secret":true}');
  await symlink('/etc/passwd', path.join(root, 'outside.json'));
  const server = await createGameServer(root);
  t.after(async () => { await server.close(); await rm(root, { recursive: true, force: true }); });
  assert.match(server.origin, /^http:\/\/127\.0\.0\.1:\d+$/);
  const index = await fetch(server.origin);
  assert.equal(index.status, 200);
  assert.match(index.headers.get('content-security-policy'), /object-src 'none'/);
  assert.equal(await index.text(), '<html>Gridfall</html>');
  const module = await fetch(`${server.origin}/game.js`);
  assert.match(module.headers.get('content-type'), /javascript/);
  assert.equal((await fetch(server.origin, { method: 'POST' })).status, 405);
  assert.equal((await fetch(`${server.origin}/.private.json`)).status, 403);
  assert.equal((await fetch(`${server.origin}/outside.json`)).status, 403);
  assert.equal((await fetch(`${server.origin}/%ZZ`)).status, 400);
  const badHost = await new Promise((resolve, reject) => {
    http.get(server.origin, { headers: { host: 'example.com' } }, res => { res.resume(); resolve(res.statusCode); }).on('error', reject);
  });
  assert.equal(badHost, 403);
});

test('desktop saves preserve JSON strings across origins and reject malformed or excessive data', async t => {
  const root = await mkdtemp(path.join(tmpdir(), 'gridfall-save-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const filename = path.join(root, 'user', 'game-storage.json');
  const data = { 'gridfall-settings': '{"muted":true}', 'gridfall-run': '{"wave":4}' };
  writeStorage(filename, serializeStorage(data));
  assert.deepEqual(readStorage(filename), data);
  assert.equal(serializeStorage({ unsafe: 42 }), null);
  assert.equal(serializeStorage({ large: 'x'.repeat(1024 * 1024) }), null);
  assert.equal(serializeStorage(['array']), null);
  await writeFile(filename, 'broken JSON');
  assert.deepEqual(readStorage(filename), {});
});
