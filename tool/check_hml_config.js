#!/usr/bin/env node
'use strict';
/**
 * Confere a configuração de HOMOLOGAÇÃO sem expor segredos: lista o que
 * ainda é modelo ("COLE_SUA…", "NUMERO", "HASH"), o que falta e o que
 * só existe fora do repositório. Não lê nem imprime valores de chaves.
 *   node tool/check_hml_config.js [--project carajas360-hml]
 * Saída 0 = pronto para implantar em homologação; 1 = há itens pendentes.
 */
const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const args = process.argv.slice(2);
const rc = JSON.parse(fs.readFileSync(path.join(ROOT, '.firebaserc'), 'utf8'));
const project = (args.includes('--project') && args[args.indexOf('--project') + 1]) || rc.projects.hml;
const PLACEHOLDER = /COLE_SUA|COLE_SEU|NUMERO|:HASH|AQUI|example|PLACEHOLDER/i;

const rows = [];
const add = (area, item, ok, detail) => rows.push({ area, item, ok, detail });
const read = (rel) => { try { return fs.readFileSync(path.join(ROOT, rel), 'utf8'); } catch (_) { return null; } };
const fileItem = (area, rel, why) => {
  const t = read(rel);
  if (t == null) return add(area, rel, false, `ausente — ${why}`);
  add(area, rel, !PLACEHOLDER.test(t), PLACEHOLDER.test(t) ? `modelo (valores de exemplo) — ${why}` : 'preenchido');
};

add('Firebase', `.firebaserc → hml = ${project}`, Boolean(project) && !/servicoconecta|a17c5/.test(project), 'alias do projeto de homologação');
fileItem('Firebase', 'lib/firebase_options_hml.dart', 'gerar com flutterfire configure --project=<hml>');
fileItem('Firebase', 'android/app/src/hml/google-services.json', 'baixar do console (app Android br.com.servicoconecta.hml)');
const iosHml = read('config/ios/GoogleService-Info-hml.plist');
add('Firebase', 'config/ios/GoogleService-Info-hml.plist', iosHml != null && !PLACEHOLDER.test(iosHml), iosHml == null ? 'ausente — app iOS do projeto hml' : (PLACEHOLDER.test(iosHml) ? 'modelo' : 'preenchido'));
const web = read('web/index.html') || '';
add('Login Google', 'web/index.html google-signin-client_id', !/COLE_SEU_GOOGLE_WEB_CLIENT_ID/.test(web), 'client id OAuth web do projeto hml (Authentication → Google)');
const env = read('config/env/hml.json');
add('App', 'config/env/hml.json', env != null && !PLACEHOLDER.test(env), env == null ? 'ausente (copiar de hml.example.json; fora do Git) — Maps e public key de TESTE do Mercado Pago' : (PLACEHOLDER.test(env) ? 'modelo' : 'preenchido'));
const fenv = read(`functions/.env.${project}`);
const need = ['PAYMENTS_GATEWAY', 'PAYMENTS_ENV', 'PROD_PROJECT_IDS', 'PAYMENTS_WEBHOOK_URL', 'MP_TEST_USER_CREDENTIALS'];
if (fenv == null) add('Functions', `functions/.env.${project}`, false, `ausente — copiar de .env.example (${need.join(', ')})`);
else {
  const miss = need.filter((k) => !new RegExp(`^${k}=.+`, 'm').test(fenv));
  add('Functions', `functions/.env.${project}`, miss.length === 0 && /PAYMENTS_ENV=sandbox/.test(fenv), miss.length ? `faltam: ${miss.join(', ')}` : (/PAYMENTS_ENV=sandbox/.test(fenv) ? 'ok' : 'PAYMENTS_ENV precisa ser sandbox'));
  if (/MERCADOPAGO_ACCESS_TOKEN|MP_WEBHOOK_SECRET|ANTHROPIC_API_KEY/.test(fenv)) add('Segurança', `functions/.env.${project}`, false, 'contém segredo: mova para o Secret Manager');
}
add('Segredos (Secret Manager)', 'MERCADOPAGO_ACCESS_TOKEN (usuário de TESTE), MP_WEBHOOK_SECRET, ANTHROPIC_API_KEY', null, 'não verificável daqui: firebase functions:secrets:access no projeto hml');
add('Mercado Pago', 'Webhook → https://us-central1-<hml>.cloudfunctions.net/paymentsWebhook', null, 'cadastrar no painel de testes e copiar a assinatura para MP_WEBHOOK_SECRET');
const gs = read('android/local.properties') || '';
add('Maps', 'MAPS_API_KEY (android/local.properties / ios MapsKey.xcconfig)', /MAPS_API_KEY=AIza/.test(gs), 'chave restrita ao app hml; sem ela mapas ficam desligados');

const pad = (s, n) => String(s).padEnd(n);
console.log(`Configuração de homologação — projeto ${project}\n`);
for (const r of rows) console.log(`${r.ok === true ? 'OK    ' : r.ok === false ? 'FALTA ' : 'VERIF.'} ${pad(r.area, 26)} ${pad(r.item, 64)} ${r.detail}`);
const pending = rows.filter((r) => r.ok === false).length;
console.log(`\n${pending} item(ns) pendente(s); ${rows.filter((r) => r.ok === null).length} a verificar no console.`);
process.exit(pending ? 1 : 0);
