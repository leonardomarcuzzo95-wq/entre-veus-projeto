// Original loopback-only login adapter for the Entre Veus development lab.
// Canary password sessions contain credentials. This is not a public login service.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { createHash, timingSafeEqual } from 'node:crypto';
const run = promisify(execFile);
const runtime = path.join(process.env.LOCALAPPDATA, 'EntreVeus1525');
async function query(sql) {
  const { stdout } = await run(path.join(process.env.LOCALAPPDATA, 'EntreVeus/mariadb/bin/mariadb.exe'), [
    '--defaults-extra-file=' + path.join(runtime, 'game-client.ini'),
    '--batch', '--skip-column-names', '--raw', '-e', sql
  ], { windowsHide: true, timeout: 5000, maxBuffer: 128 * 1024 });
  return stdout.trim() ? stdout.trim().split(/\r?\n/).map(line => line.split('\t')) : [];
}
const reply = (res, code, data) => {
  res.writeHead(code, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(data));
};
const deny = res => reply(res, 200, { errorCode: 3, errorMessage: 'Conta ou senha incorreta.' });
const server = http.createServer(async (req, res) => {
  if (req.headers.origin) return reply(res, 403, { error: 'Native local client only' });
  if (req.method === 'GET' && req.url === '/health') return reply(res, 200, { service: 'entreveus-local-login', protocol: 1525 });
  if (req.method !== 'POST' || req.url !== '/login') return reply(res, 404, { error: 'Not found' });
  try {
    const chunks = []; let bytes = 0;
    for await (const chunk of req) {
      bytes += chunk.length;
      if (bytes > 8192) return reply(res, 413, { error: 'Body too large' });
      chunks.push(chunk);
    }
    let body;
    try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); }
    catch { return reply(res, 400, { error: 'Invalid JSON' }); }
    if (!body || typeof body.email !== 'string' || !/^[A-Za-z0-9@._-]{1,80}$/.test(body.email) || typeof body.password !== 'string' || body.password.length > 256) return deny(res);
    const [account] = await query(`SELECT id,email,password FROM accounts WHERE name='${body.email}' OR email='${body.email}' LIMIT 1`);
    if (!account) return deny(res);
    const actual = Buffer.from(createHash('sha1').update(body.password).digest('hex'));
    const expected = Buffer.from(account[2].toLowerCase());
    if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) return deny(res);
    const rows = await query(`SELECT name,level,looktype,lookhead,lookbody,looklegs,lookfeet FROM players WHERE account_id=${Number(account[0])} AND deletion=0 ORDER BY id`);
    const characters = rows.map(row => ({ name: row[0], level: +row[1], outfitid: +row[2], headcolor: +row[3], torsocolor: +row[4], legscolor: +row[5], detailcolor: +row[6], addonsflags: 0, worldid: 0, ismaincharacter: true, dailyrewardstate: 0, ishidden: false, vocation: 'Viajante' }));
    reply(res, 200, {
      session: { sessionkey: account[1] + '\n' + body.password, premiumuntil: Math.floor(Date.now() / 1000) + 86400 * 365 },
      playdata: { worlds: [{ id: 0, name: 'Entre Veus', externaladdressprotected: '127.0.0.1', externalportprotected: 7272, previewstate: 0, pvptype: 0 }], characters }
    });
  } catch { reply(res, 503, { errorCode: 1, errorMessage: 'Banco local indisponivel. Consulte os logs do laboratorio.' }); }
});
server.requestTimeout = 10000;
server.headersTimeout = 10000;
server.listen(8090, '127.0.0.1', () => console.log('Entre Veus local login ready on 127.0.0.1:8090'));
