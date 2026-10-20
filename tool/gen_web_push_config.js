#!/usr/bin/env node
'use strict';
/**
 * Pendência 3: gera firebase-messaging-config.js (lido pelo
 * web/firebase-messaging-sw.js) com a config WEB do Firebase do ambiente,
 * tirada de lib/firebase_options_<env>.dart. A apiKey web do Firebase não é
 * segredo, mas valores de exemplo (COLE_SUA…, NUMERO, HASH, demo) NUNCA vão
 * para o arquivo: nesse caso ele sai `null` (push web desligado) e a saída
 * é 2, com o motivo.
 *   flutter build web --dart-define-from-file=config/env/hml.json
 *   node tool/gen_web_push_config.js --env hml [--out build/web] [--options <arquivo>]
 * Saída 0 = gerado com config real; 2 = gerado desligado; 1 = erro.
 */
const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const args = process.argv.slice(2);
const arg = (k, d) => (args.includes(k) ? args[args.indexOf(k) + 1] : d);
const env = arg('--env', '');
const outDir = path.resolve(ROOT, arg('--out', 'build/web'));
if (!['dev', 'hml', 'prod'].includes(env)) {
  console.error('Uso: node tool/gen_web_push_config.js --env <dev|hml|prod> [--out build/web]');
  process.exit(1);
}
const PLACEHOLDER = /COLE_SUA|COLE_SEU|NUMERO|HASH|AQUI|PLACEHOLDER|demo-|XXXXXXXX|^1:0+:/i;

/** Lê o bloco `static const web = FirebaseOptions(...)` do arquivo do ambiente. */
function readWebOptions(src) {
  const m = src.match(/static const (?:FirebaseOptions )?web = FirebaseOptions\(([\s\S]*?)\);/);
  if (!m) return null;
  const consts = Object.fromEntries([...src.matchAll(/static const (?:String )?(\w+) = '([^']*)';/g)].map((x) => [x[1], x[2]]));
  const o = {};
  for (const f of m[1].matchAll(/(\w+):\s*(?:'([^']*)'|(\w+))/g)) {
    let v = f[2] != null ? f[2] : consts[f[3]];
    if (typeof v !== 'string') continue;
    v = v.replace(/\$(\w+)|\$\{(\w+)\}/g, (_, a, b) => consts[a || b] || '');
    o[f[1]] = v;
  }
  return o;
}

function check(o) {
  if (!o) return 'bloco web não encontrado';
  const need = ['apiKey', 'appId', 'messagingSenderId', 'projectId'];
  const miss = need.filter((k) => !o[k]);
  if (miss.length) return `faltam ${miss.join(', ')}`;
  const bad = need.filter((k) => PLACEHOLDER.test(o[k]));
  if (bad.length) return `valores de exemplo em ${bad.join(', ')}`;
  return null;
}

const rel = arg('--options', `lib/firebase_options_${env}.dart`);
let src;
try { src = fs.readFileSync(path.resolve(ROOT, rel), 'utf8'); } catch (_) { console.error(`${rel} não existe`); process.exit(1); }
const opts = readWebOptions(src);
const problem = check(opts);
const keep = ['apiKey', 'authDomain', 'projectId', 'storageBucket', 'messagingSenderId', 'appId'];
const cfg = problem ? null : Object.fromEntries(keep.filter((k) => opts[k]).map((k) => [k, opts[k]]));
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'firebase-messaging-config.js'),
  `// Gerado por tool/gen_web_push_config.js --env ${env} (não editar à mão).\n`
  + (problem ? `// Push web DESLIGADO: ${problem} em ${rel}.\n` : '')
  + `self.C360_FIREBASE_WEB = ${JSON.stringify(cfg, null, 2)};\n`);
if (problem) {
  console.warn(`Push web desligado (${env}): ${problem} em ${rel}. Gere o arquivo com flutterfire configure.`);
  process.exit(2);
}
console.log(`Push web (${env}): config do projeto ${cfg.projectId} gravada em ${path.relative(ROOT, outDir)}/firebase-messaging-config.js`);
