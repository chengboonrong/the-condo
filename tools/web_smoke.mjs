// Serves an exported web build and loads it with ?smoke in Chromium and WebKit. Exit 1 if either fails.
//   node tools/web_smoke.mjs [builds/web] [--perf] [--chromium|--webkit]
// --perf runs the perf tour (?perf) in visible browser windows instead, so the real GPU is used
// (add --headless to compare: a visible window that is covered by others can be throttled by macOS).
// Needs Playwright with its browsers; set PLAYWRIGHT_FROM=/some/dir/ if it isn't installed next to the project.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { once } from 'node:events';
import { createRequire } from 'node:module';

const require = createRequire(process.env.PLAYWRIGHT_FROM ?? import.meta.url);
const { chromium, webkit } = require('playwright');
const perf = process.argv.includes('--perf');
const headed = perf && !process.argv.includes('--headless');
const dir = path.resolve(process.argv.slice(2).find((a) => !a.startsWith('--')) ?? 'builds/web');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.png': 'image/png' };

const server = http.createServer(async (req, res) => {
  let file;
  try {
    file = path.join(dir, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  } catch {
    return res.writeHead(400).end();
  }
  const rel = path.relative(dir, file);
  if (rel.startsWith('..') || path.isAbsolute(rel)) return res.writeHead(403).end();
  try {
    const body = await fs.readFile(file);
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] ?? 'application/octet-stream' }).end(body);
  } catch {
    res.writeHead(404).end();
  }
}).listen(0, '127.0.0.1');
await once(server, 'listening');
const url = `http://127.0.0.1:${server.address().port}/index.html?${perf ? 'perf' : 'smoke'}`;

let failed = 0;
const only = process.argv.find((a) => a === '--chromium' || a === '--webkit')?.slice(2);
for (const [name, type] of [['chromium', chromium], ['webkit', webkit]].filter(([n]) => !only || n === only)) {
  const browser = await type.launch({ headless: !headed });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const lines = [];
  page.on('console', (m) => lines.push(m.text()));
  page.on('pageerror', (e) => lines.push('PAGEERROR ' + e.message));
  const t0 = Date.now();
  await page.goto(url);
  await page.bringToFront();
  let smoke;
  const done = perf ? 'PERF load' : 'SMOKE';
  for (let i = 0; i < 240 && !smoke; i++) {
    await page.waitForTimeout(500);
    smoke = lines.find((l) => l.startsWith(done));
  }
  if (perf) {
    console.log(`${name}:\n${lines.filter((l) => l.startsWith('PERF')).join('\n') || 'no PERF lines'}`);
    if (!smoke) failed++;
    await browser.close();
    continue;
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
