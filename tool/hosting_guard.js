#!/usr/bin/env node
'use strict';
/**
 * predeploy do Hosting (firebase.json): impede publicar o web em produção por
 * engano (ex.: `firebase deploy -P prod` sem --only, com um build hml/dev em
 * build/web). O build web carrega as opções de todos os ambientes, então o
 * alvo não dá para deduzir do JS: produção exige confirmação explícita.
 *   CARAJAS_PROD_HOSTING=confirmo-producao firebase deploy -P prod --only hosting
 */
const fs = require('fs');
const path = require('path');
const project = process.env.GCLOUD_PROJECT || '';
const PROD = ['servicoconecta', 'carajas360-a17c5',
  ...String(process.env.PROD_PROJECT_IDS || '').split(',').map((s) => s.trim()).filter(Boolean)];
const root = process.env.PROJECT_DIR || path.join(__dirname, '..');
const fail = (m) => { console.error(`Hosting bloqueado: ${m}`); process.exit(1); };

if (!project) fail('projeto alvo desconhecido (GCLOUD_PROJECT vazio).');
if (!fs.existsSync(path.join(root, 'build', 'web', 'main.dart.js'))) fail('build/web não existe; rode flutter build web antes.');
// Pendência 3: config do push web gerada para OUTRO projeto mandaria os
// tokens para o Firebase errado (null = push web desligado, permitido).
const swCfg = (() => { try { return fs.readFileSync(path.join(root, 'build', 'web', 'firebase-messaging-config.js'), 'utf8'); } catch (_) { return ''; } })();
const swProject = (swCfg.match(/"projectId":\s*"([^"]+)"/) || [])[1];
if (swProject && swProject !== project) fail(`build/web/firebase-messaging-config.js é do projeto "${swProject}", não de "${project}" (rode tool/gen_web_push_config.js).`);
if (PROD.includes(project) && process.env.CARAJAS_PROD_HOSTING !== 'confirmo-producao') {
  fail(`"${project}" é produção. Publicar em produção exige CARAJAS_PROD_HOSTING=confirmo-producao e um build com APP_ENV=prod.`);
}
console.log(`Hosting: alvo ${project} liberado.`);
