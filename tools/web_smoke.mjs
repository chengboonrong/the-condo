// Serves an exported web build and loads it with ?smoke in Chromium and WebKit. Exit 1 if either fails.
//   node tools/web_smoke.mjs [builds/web]
// Needs Playwright with its browsers; set PLAYWRIGHT_FROM=/some/dir/ if it isn't installed next to the project.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { once } from 'node:events';
import { createRequire } from 'node:module';

const require = createRequire(process.env.PLAYWRIGHT_FROM ?? import.meta.url);
const { chromium, webkit } = require('playwright');
const dir = path.resolve(process.argv[2] ?? 'builds/web');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.png': 'image/png' };

const server = http.createServer(async (req, res) => {
  const file = path.join(dir, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!file.startsWith(dir)) return res.writeHead(403).end();
  try {
    const body = await fs.readFile(file);
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] ?? 'application/octet-stream' }).end(body);
  } catch {
    res.writeHead(404).end();
  }
}).listen(0, '127.0.0.1');
await once(server, 'listening');
const url = `http://127.0.0.1:${server.address().port}/index.html?smoke`;

let failed = 0;
for (const [name, type] of [['chromium', chromium], ['webkit', webkit]]) {
  const browser = await type.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const lines = [];
  page.on('console', (m) => lines.push(m.text()));
  page.on('pageerror', (e) => lines.push('PAGEERROR ' + e.message));
  const t0 = Date.now();
  await page.goto(url);
  let smoke;
  for (let i = 0; i < 120 && !smoke; i++) {
    await page.waitForTimeout(500);
    smoke = lines.find((l) => l.startsWith('SMOKE'));
  }
  const shot = path.join(dir, '..', `smoke-${name}.png`);
  await page.screenshot({ path: shot });
  console.log(`${name}: ${smoke ?? 'no SMOKE line'} (${((Date.now() - t0) / 1000).toFixed(1)} s, ${shot})`);
  // Pointer lock needs a click; the smoke run has none, so that error is expected.
  for (const l of lines.filter((l) => /error/i.test(l) && !/pointer lock/i.test(l))) console.log('  ', l);
  if (!smoke?.startsWith('SMOKE ok')) failed++;
  await browser.close();
}
server.close();
process.exit(failed ? 1 : 0);
