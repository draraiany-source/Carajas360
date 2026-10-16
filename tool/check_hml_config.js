#!/usr/bin/env node
'use strict';
/**
 * Confere a configuração de HOMOLOGAÇÃO sem expor segredos: lista o que
 * ainda é modelo ("COLE_SUA…", "NUMERO", "HASH"), o que falta e o que
 * só existe fora do repositório. Não lê nem imprime valores de chaves.
 *   node tool/check_hml_config.js [--project carajas360-hml] [--deploy]
 * Saída 0 = pronto para implantar em homologação; 1 = há itens pendentes.
 * --deploy: só conta o que a implantação de web/backend exige (os arquivos
 * só do Android/iOS e a chave do Maps continuam listados, sem bloquear).
 */
const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const args = process.argv.slice(2);
const rc = JSON.parse(fs.readFileSync(path.join(ROOT, '.firebaserc'), 'utf8'));
const project = (args.includes('--project') && args[args.indexOf('--project') + 1]) || rc.projects.hml;
const deployOnly = args.includes('--deploy');
// Sem "example": o firebase_options gerado pelo flutterfire tem "/// Example:" no comentário.
const PLACEHOLDER = /COLE_SUA|COLE_SEU|NUMERO|:HASH|AQUI|PLACEHOLDER/i;

const rows = [];
// mobile = item só do app Android/iOS (não bloqueia --deploy).
const add = (area, item, ok, detail, mobile = false) => rows.push({ area, item, ok, detail, mobile });
const read = (rel) => { try { return fs.readFileSync(path.join(ROOT, rel), 'utf8'); } catch (_) { return null; } };
const fileItem = (area, rel, why, mobile = false) => {
  const t = read(rel);
  if (t == null) return add(area, rel, false, `ausente — ${why}`, mobile);
  add(area, rel, !PLACEHOLDER.test(t), PLACEHOLDER.test(t) ? `modelo (valores de exemplo) — ${why}` : 'preenchido', mobile);
};

const hmlName = Boolean(project) && /hml|homolog|staging/.test(project) && !/servicoconecta|a17c5/.test(project);
add('Firebase', `.firebaserc → hml = ${project}`, hmlName, hmlName ? 'alias do projeto de homologação' : 'não parece homologação (precisa conter hml/homolog/staging e não ser produção)');
fileItem('Firebase', 'lib/firebase_options_hml.dart', 'gerar com flutterfire configure --project=<hml>');
fileItem('Firebase', 'android/app/src/hml/google-services.json', 'baixar do console (app Android br.com.servicoconecta.hml)', true);
const opts = read('lib/firebase_options_hml.dart') || '';
const optIds = [...new Set([...opts.matchAll(/projectId:\s*'([^']+)'/g)].map((m) => m[1]))];
add('Firebase', 'firebase_options_hml.dart → projectId', optIds.length === 1 && optIds[0] === project, optIds.length === 1 && optIds[0] === project ? 'igual ao projeto alvo' : `aponta para ${optIds.join(', ') || 'nada'}; precisa ser ${project}`);
// Caminho que a fase de build do Xcode copia (ios/config, ignorado pelo Git).
const iosHml = read('ios/config/GoogleService-Info-hml.plist');
add('Firebase', 'ios/config/GoogleService-Info-hml.plist', iosHml != null && !PLACEHOLDER.test(iosHml), iosHml == null ? 'ausente — app iOS do projeto hml' : (PLACEHOLDER.test(iosHml) ? 'modelo' : 'preenchido'), true);
const web = read('web/index.html') || '';
add('Login Google', 'web/index.html google-signin-client_id', !/COLE_SEU_GOOGLE_WEB_CLIENT_ID/.test(web), 'client id OAuth web do projeto hml (Authentication → Google)');
const env = read('config/env/hml.json');
let envJson = null;
try { envJson = env == null ? null : JSON.parse(env); } catch (_) { envJson = null; }
// APP_ENV decide as opções do Firebase compiladas no app: precisa ser hml (nunca prod/dev nem emulador).
const envOk = env != null && !PLACEHOLDER.test(env) && envJson && envJson.APP_ENV === 'hml' && String(envJson.USE_FIREBASE_EMULATOR || '') !== 'true';
add('App', 'config/env/hml.json', Boolean(envOk), env == null ? 'ausente (copiar de hml.example.json; fora do Git) — Maps e public key de TESTE do Mercado Pago'
  : !envJson ? 'JSON inválido' : PLACEHOLDER.test(env) ? 'modelo'
  : envJson.APP_ENV !== 'hml' ? `APP_ENV precisa ser "hml" (está "${envJson.APP_ENV}")`
  : String(envJson.USE_FIREBASE_EMULATOR || '') === 'true' ? 'USE_FIREBASE_EMULATOR não pode ser true' : 'preenchido');
const fenv = read(`functions/.env.${project}`);
const need = ['PAYMENTS_GATEWAY', 'PAYMENTS_ENV', 'PROD_PROJECT_IDS', 'PAYMENTS_WEBHOOK_URL', 'MP_TEST_USER_CREDENTIALS'];
if (fenv == null) add('Functions', `functions/.env.${project}`, false, `ausente — copiar de .env.example (${need.join(', ')})`);
else {
  const miss = need.filter((k) => !new RegExp(`^${k}=.+`, 'm').test(fenv));
  const prodIds = ((fenv.match(/^PROD_PROJECT_IDS=(.*)$/m) || [])[1] || '').split(',').map((x) => x.trim());
  const prodOk = ['servicoconecta', 'carajas360-a17c5'].every((id) => prodIds.includes(id));
  add('Functions', `functions/.env.${project}`, miss.length === 0 && /PAYMENTS_ENV=sandbox/.test(fenv) && prodOk,
    miss.length ? `faltam: ${miss.join(', ')}` : !/PAYMENTS_ENV=sandbox/.test(fenv) ? 'PAYMENTS_ENV precisa ser sandbox'
      : !prodOk ? 'PROD_PROJECT_IDS precisa incluir servicoconecta e carajas360-a17c5' : 'ok');
  if (/MERCADOPAGO_ACCESS_TOKEN|MP_WEBHOOK_SECRET|ANTHROPIC_API_KEY/.test(fenv)) add('Segurança', `functions/.env.${project}`, false, 'contém segredo: mova para o Secret Manager');
}
add('Segredos (Secret Manager)', 'MERCADOPAGO_ACCESS_TOKEN (usuário de TESTE), MP_WEBHOOK_SECRET, ANTHROPIC_API_KEY', null, 'não verificável daqui: firebase functions:secrets:access no projeto hml');
add('Mercado Pago', 'Webhook → https://us-central1-<hml>.cloudfunctions.net/paymentsWebhook', null, 'cadastrar no painel de testes e copiar a assinatura para MP_WEBHOOK_SECRET');
const gs = read('android/local.properties') || '';
add('Maps', 'MAPS_API_KEY (android/local.properties / ios MapsKey.xcconfig)', /MAPS_API_KEY=AIza/.test(gs), 'chave restrita ao app hml; sem ela mapas ficam desligados', true);

const pad = (s, n) => String(s).padEnd(n);
console.log(`Configuração de homologação — projeto ${project}\n`);
for (const r of rows) console.log(`${r.ok === true ? 'OK    ' : r.ok === false ? 'FALTA ' : 'VERIF.'} ${pad(r.area, 26)} ${pad(r.item, 64)} ${r.detail}`);
const pending = rows.filter((r) => r.ok === false && !(deployOnly && r.mobile)).length;
const mobileOnly = deployOnly ? rows.filter((r) => r.ok === false && r.mobile).length : 0;
console.log(`\n${pending} item(ns) pendente(s)${deployOnly ? ' para implantar web/backend' : ''}; ${rows.filter((r) => r.ok === null).length} a verificar no console.`);
if (mobileOnly) console.log(`${mobileOnly} item(ns) só do app móvel (não bloqueiam --deploy).`);
process.exit(pending ? 1 : 0);
