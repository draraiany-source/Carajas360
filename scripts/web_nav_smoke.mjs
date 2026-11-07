// Smoke test de navegação da versão web (Chrome headless + CDP).
// Uso: node scripts/web_nav_smoke.mjs <url> <saida_dir> [targets.json]
// Requer o build servido localmente (ex.: http://localhost:8765/).
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const url = process.argv[2] ?? 'http://localhost:8765/';
const outDir = process.argv[3] ?? 'build/smoke';
const targetsFile = process.argv[4];
const chrome = process.env.CHROME_PATH ??
  'C:/Program Files/Google/Chrome/Application/chrome.exe';
const port = 9333;
fs.mkdirSync(outDir, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const proc = spawn(chrome, [
  '--headless=new', `--remote-debugging-port=${port}`,
  `--user-data-dir=${path.resolve('build/chrome-smoke-profile')}`,
  '--no-first-run', '--disable-gpu', '--window-size=1440,900', 'about:blank',
], { stdio: 'ignore' });

let ws, seq = 0;
const pending = new Map();
const send = (method, params = {}) => new Promise((resolve, reject) => {
  const id = ++seq;
  pending.set(id, { resolve, reject });
  ws.send(JSON.stringify({ id, method, params }));
});
const evaluate = async (expression) => {
  const r = await send('Runtime.evaluate',
    { expression, returnByValue: true, awaitPromise: true });
  return r.result?.value;
};

const LAB = `(n)=>(n.getAttribute('aria-label')||[...n.childNodes].filter(c=>c.nodeType===3).map(c=>c.textContent).join('')||(n.querySelector('flt-semantics')?'':n.textContent)||'').trim()`;
const enableSemantics = () => evaluate(
  `document.querySelector('flt-semantics-placeholder')?.click(); document.querySelectorAll('flt-semantics').length`);
const labels = () => evaluate(
  `(()=>{const lab=${LAB};return [...document.querySelectorAll('flt-semantics')].map(lab).filter(Boolean)})()`);
const rectOf = (label, nth = 0) => evaluate(
  `(()=>{const lab=${LAB};const n=[...document.querySelectorAll('flt-semantics')].filter(x=>lab(x)===${JSON.stringify(label)}).at(${nth})??[...document.querySelectorAll('flt-semantics input[aria-label],flt-semantics textarea[aria-label]')].filter(x=>x.getAttribute('aria-label').includes(${JSON.stringify(label)})).at(${nth});if(!n)return null;const r=n.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}})()`);

async function clickAt({ x, y }) {
  for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) {
    await send('Input.dispatchMouseEvent',
      { type, x, y, button: 'left', clickCount: 1 });
    await sleep(40);
  }
}
async function waitFor(pred, ms = 10000) {
  const t = Date.now();
  while (Date.now() - t < ms) {
    await enableSemantics();
    if (await pred()) return true;
    await sleep(300);
  }
  return false;
}
async function shot(name) {
  const r = await send('Page.captureScreenshot', { format: 'png' });
  fs.writeFileSync(path.join(outDir, name), Buffer.from(r.data, 'base64'));
}
let wheelX = 700;
async function wheel(deltaY, x = wheelX, y = 500) {
  await send('Input.dispatchMouseEvent',
    { type: 'mouseWheel', x, y, deltaX: 0, deltaY });
  await sleep(900);
}
async function load(width, height, mobile) {
  await send('Emulation.setDeviceMetricsOverride',
    { width, height, deviceScaleFactor: 1, mobile });
  await send('Page.navigate', { url });
  await sleep(9000);
  await enableSemantics();
  await sleep(800);
}

async function clickLabel(label, nth = 0, ms = 10000) {
  let rect = null;
  await waitFor(async () => (rect = await rectOf(label, nth)) != null, ms);
  if (!rect) return false;
  await clickAt(rect);
  await sleep(900);
  return true;
}
// Recarrega e executa os passos de preparação do viewport (ex.: abrir uma aba).
async function loadVp(vp) {
  await load(vp.width, vp.height, vp.mobile);
  for (const s of vp.setup ?? []) await clickLabel(s.label, s.nth ?? 0, 15000);
}

const defaultTargets = [];
const targets = targetsFile
  ? JSON.parse(fs.readFileSync(targetsFile, 'utf8'))
  : defaultTargets;

async function run() {
  for (let i = 0; i < 50; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const page = list.find((t) => t.type === 'page');
      if (page) { ws = new WebSocket(page.webSocketDebuggerUrl); break; }
    } catch { /* aguardando o Chrome */ }
    await sleep(300);
  }
  await new Promise((r) => ws.addEventListener('open', r, { once: true }));
  ws.addEventListener('message', (ev) => {
    const m = JSON.parse(ev.data);
    if (m.id && pending.has(m.id)) {
      const p = pending.get(m.id); pending.delete(m.id);
      m.error ? p.reject(new Error(m.error.message)) : p.resolve(m.result);
    }
  });
  await send('Page.enable');
  await send('Runtime.enable');

  const report = { url, startedAt: new Date().toISOString(), viewports: [] };
  for (const vp of targets.viewports ?? []) {
    wheelX = vp.scrollX ?? Math.round(vp.width / 2);
    await loadVp(vp);
    const homeMarker = vp.homeMarker;
    const res = { name: vp.name, width: vp.width, height: vp.height,
      screenshots: [], checks: [] };
    await waitFor(async () => (await labels()).includes(homeMarker), 15000);
    if (vp.dumpLabels) res.labels = await labels();
    for (let s = 0; s < (vp.scrollShots ?? 1); s++) {
      const f = `${vp.name}_home_${s + 1}.png`;
      await shot(f); res.screenshots.push(f);
      await wheel(vp.scrollStep ?? 700);
    }
    await loadVp(vp);
    const backMarker = vp.backMarker ?? homeMarker;
    for (const t of vp.targets ?? []) {
      const atHome = async () => (await labels()).includes(homeMarker);
      const atShell = async () => (await labels()).includes(backMarker);
      await waitFor(atHome, 15000);
      for (let k = 0; k < (t.scroll ?? 0); k++) await wheel(vp.scrollStep ?? 700);
      await enableSemantics();
      const rect = await rectOf(t.label, t.nth ?? 0);
      if (!rect) {
        res.checks.push({ target: t.label, nth: t.nth ?? 0, result: 'NOT FOUND' });
        await loadVp(vp);
        continue;
      }
      await clickAt(rect);
      if (t.type) {
        await sleep(700);
        await send('Input.insertText', { text: t.type });
        await sleep(1200);
      }
      for (const s of t.then ?? []) {
        await sleep(700);
        if (!(await clickLabel(s.label, s.nth ?? 0, 6000))) {
          res.checks.push({ target: t.label, step: s.label, result: 'STEP NOT FOUND' });
        }
      }
      let opened = await waitFor(async () => {
        const l = await labels();
        const none = (t.expectNone ?? []).every((e) => !l.some((x) => x.includes(e)));
        return none && (t.expectAny
          ? t.expectAny.some((e) => l.some((x) => x.includes(e)))
          : !l.includes(homeMarker));
      }, 8000);
      await sleep(600);
      const seen = (await labels()).slice(0, 8).map((s) => s.replace(/\s+/g, ' ').slice(0, 80));
      let shotName;
      if (t.shot) { shotName = `${vp.name}_${t.shot}.png`; await shot(shotName); }
      let back = 'NOT TESTED';
      if (t.inPlace) {
        back = 'NOT APPLICABLE';
        await send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 });
        await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 });
        await sleep(800);
      } else {
        const v = (await rectOf('Voltar')) ?? (await rectOf('Back'));
        if (v) {
          await clickAt(v);
          back = (await waitFor(atShell, 8000)) ? 'PASS' : 'FAIL';
        } else {
          back = 'NO BACK BUTTON';
        }
      }
      res.checks.push({ target: t.label, nth: t.nth ?? 0,
        result: opened ? 'PASS' : 'FAIL', back, seen, screenshot: shotName });
      await loadVp(vp);
    }
    report.viewports.push(res);
  }
  report.finishedAt = new Date().toISOString();
  fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
}

run().catch((e) => { console.error('SMOKE ERROR', e); process.exitCode = 1; })
  .finally(() => { try { ws?.close(); } catch {} proc.kill(); });
