import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
export async function launch(w = 1440, h = 900) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cdp-'));
  const port = 9300 + Math.floor(Math.random() * 500);
  const p = spawn(CHROME, ['--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${dir}`, `--window-size=${w},${h}`, '--no-first-run', '--disable-gpu', '--allow-file-access-from-files', 'about:blank'], { stdio: 'ignore' });
  let ws;
  for (let i = 0; i < 50; i++) {
    await new Promise(r => setTimeout(r, 200));
    try {
      const list = await new Promise((res, rej) => http.get(`http://127.0.0.1:${port}/json`, r => { let d = ''; r.on('data', c => d += c); r.on('end', () => res(JSON.parse(d))); }).on('error', rej));
      const t = list.find(x => x.type === 'page');
      if (t) { ws = t.webSocketDebuggerUrl; break; }
    } catch {}
  }
  const sock = new WebSocket(ws);
  await new Promise(r => sock.addEventListener('open', r));
  let id = 0; const pend = new Map(); const errors = []; const logs = [];
  sock.addEventListener('message', ev => {
    const m = JSON.parse(ev.data);
    if (m.id && pend.has(m.id)) { pend.get(m.id)(m); pend.delete(m.id); return; }
    if (m.method === 'Runtime.exceptionThrown') errors.push((m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text).slice(0, 300));
    if (m.method === 'Runtime.consoleAPICalled' && ['error', 'warning'].includes(m.params.type)) logs.push(m.params.type + ': ' + m.params.args.map(a => a.value ?? a.description).join(' ').slice(0, 200));
  });
  const send = (method, params = {}) => new Promise(r => { const i = ++id; pend.set(i, r); sock.send(JSON.stringify({ id: i, method, params })); });
  await send('Runtime.enable'); await send('Page.enable');
  const api = {
    errors, logs,
    async goto(url, wait = 900) { errors.length = 0; logs.length = 0; await send('Page.navigate', { url }); await new Promise(r => setTimeout(r, wait)); },
    async eval(expr) { const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true }); if (!r.result||r.result.exceptionDetails) return { __err: r.result.exceptionDetails.exception?.description || 'eval error (page navigated?)' }; return r.result.result.value; },
    async resize(w, h) { await send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: w < 700 }); },
    async shot(file) { const r = await send('Page.captureScreenshot', { format: 'png' }); fs.writeFileSync(file, Buffer.from(r.result.data, 'base64')); },
    sleep: ms => new Promise(r => setTimeout(r, ms)),
    close() { try { sock.close(); p.kill(); } catch {} },
  };
  return api;
}
