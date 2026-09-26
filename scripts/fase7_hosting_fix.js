const fs = require('fs');
const path = require('path');
const root = process.cwd();
const hosting = path.join(root, 'hosting');
fs.mkdirSync(hosting, { recursive: true });
function fixEmails(s) { return s.split('servicoconecta.com.br').join('carajas360.com.br'); }
const privacy = fs.readFileSync(path.join(root, 'web', 'privacy.html'), 'utf8');
const terms = fs.readFileSync(path.join(root, 'web', 'terms.html'), 'utf8');
fs.writeFileSync(path.join(hosting, 'privacy.html'), fixEmails(privacy), 'utf8');
fs.writeFileSync(path.join(hosting, 'terms.html'), fixEmails(terms), 'utf8');
const index = '<!DOCTYPE html>\n<html lang="pt-BR">\n<head>\n<meta charset="UTF-8"/>\n<meta name="viewport" content="width=device-width, initial-scale=1"/>\n<title>Carajas 360</title>\n<style>\nbody{margin:0;min-height:100vh;font-family:system-ui,sans-serif;background:linear-gradient(160deg,#0D47A1,#0A3880 40%,#1B5E20);color:#fff;display:flex;align-items:center;justify-content:center}\n.box{text-align:center;padding:32px 24px}\nh1{font-size:2rem;margin:0 0 12px}\np{opacity:.9;margin:0 0 24px}\na{color:#fff;margin:0 10px}\n</style>\n</head>\n<body>\n<div class="box">\n<h1>Carajas 360</h1>\n<p>Documentos legais publicos</p>\n<p>\n<a href="/privacy">Politica de Privacidade</a>\n·\n<a href="/terms">Termos de Uso</a>\n</p>\n</div>\n</body>\n</html>\n';
fs.writeFileSync(path.join(hosting, 'index.html'), index, 'utf8');
const evidence = [
'# Fase 7 — Hosting Privacy/Terms 404 Fix',
'',
'## Root cause',
'`firebase.json` had `hosting.public` set to `build/web`. Legal pages live in `web/privacy.html` and `web/terms.html`. A typical Flutter web build output in `build/web` does not include those static legal files, so deployed `/privacy` and `/terms` rewrites pointed at missing files → **404**.',
'',
'## Fix (code/config only — no deploy in this session)',
'1. Created `hosting/` with `privacy.html` and `terms.html` (content from `web/`, LGPD retained).',
'2. Contact emails aligned with AppInfo:',
'   - `suporte@carajas360.com.br`',
'   - `privacidade@carajas360.com.br`',
'3. Added minimal `hosting/index.html` (Carajas 360 + links to /privacy and /terms).',
'4. Changed `firebase.json` `hosting.public` from `build/web` to `hosting` (rewrites for /privacy and /terms unchanged).',
'5. Synced `web/privacy.html` and `web/terms.html` emails to `carajas360.com.br` for consistency.',
'',
'## EXTERNAL ACTION REQUIRED',
'Owner must run (requires Firebase owner auth):',
'',
'```bash',
'firebase deploy --only hosting',
'```',
'',
'**Do not** enable payments, publish the app, or start Phase 8 as part of this fix.',
'',
].join('\n');
fs.mkdirSync(path.join(root, 'docs', 'evidence'), { recursive: true });
fs.writeFileSync(path.join(root, 'docs', 'evidence', 'fase7_hosting_privacy_fix.md'), evidence, 'utf8');
console.log('OK');
for (const f of ['index.html', 'privacy.html', 'terms.html']) {
  const p = path.join(hosting, f);
  const txt = fs.readFileSync(p, 'utf8');
  console.log(f, fs.statSync(p).size, 'carajas=', txt.includes('carajas360.com.br'), 'old=', txt.includes('servicoconecta.com.br'));
}
console.log('public=', JSON.parse(fs.readFileSync('firebase.json','utf8')).hosting.public);