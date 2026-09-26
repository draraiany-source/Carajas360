'use strict';

const fs = require('fs');
const path = require('path');

if (process.argv.includes('--fase7-warnings-audit')) {
  runFase7WarningsAudit();
  process.exit(0);
}

function runFase7WarningsAudit() {
  const analyzePath = path.join(__dirname, '..', 'docs', 'evidence', 'fase7_analyze.txt');
  const outPath = path.join(__dirname, '..', 'docs', 'evidence', 'fase7_warnings_audit.md');
  if (!fs.existsSync(analyzePath)) {
    console.error('Missing', analyzePath);
    process.exit(1);
  }
  const raw = fs.readFileSync(analyzePath, 'utf8');
  const issues = [];
  for (const line of raw.split(/\r?\n/)) {
    const m = line.match(
      /^\s*(warning|info)\s+-\s+(.+)\s+-\s+((?:lib|tool)[^:]+):(\d+):\d+\s+-\s+(\S+)\s*$/,
    );
    if (m) {
      issues.push({
        level: m[1],
        message: m[2],
        file: m[3].replace(/\\/g, '/'),
        line: Number(m[4]),
        rule: m[5],
      });
    }
  }
  function classify(issue) {
    const { rule, message } = issue;
    if (rule === 'use_build_context_synchronously') {
      return message.includes('guarded by an unrelated') ? 'IMPORTANT' : 'CRITICAL';
    }
    if (rule === 'unnecessary_null_comparison' || rule === 'unnecessary_cast') {
      return 'IMPORTANT';
    }
    if (
      rule === 'deprecated_member_use' &&
      (message.includes("'bytes'") || message.includes('out-of-memory'))
    ) {
      return 'IMPORTANT';
    }
    return 'COSMETIC';
  }
  const bySeverity = { CRITICAL: [], IMPORTANT: [], COSMETIC: [] };
  const byRule = {};
  let warnings = 0;
  let infos = 0;
  for (const issue of issues) {
    if (issue.level === 'warning') warnings++;
    else infos++;
    bySeverity[classify(issue)].push(issue);
    byRule[issue.rule] = (byRule[issue.rule] || 0) + 1;
  }
  const criticalFixNow = bySeverity.CRITICAL.length > 0;
  function formatItem(i) {
    const msg = i.message.length > 120 ? `${i.message.slice(0, 120)}…` : i.message;
    return `- \`${i.file}:${i.line}\` — **${i.rule}**: ${msg}`;
  }
  const fixNowLine = criticalFixNow
    ? '**Yes** — unguarded `BuildContext` after async (dispose crash risk).'
    : '**No** — none meet CRITICAL bar under current criteria.';
  const md = `# Fase 7 — Flutter analyze warnings audit

Generated: ${new Date().toISOString()}  
Source: \`docs/evidence/fase7_analyze.txt\`  
Flutter reported: **161** issues (parser matched **${issues.length}** lines).

## Severity summary (release-freeze criteria)

| Severity | Count | Notes |
|----------|------:|-------|
| **CRITICAL** | ${bySeverity.CRITICAL.length} | Crash risk, security, publish blockers, or clear bugs |
| **IMPORTANT** | ${bySeverity.IMPORTANT.length} | Correctness / lifecycle / memory edge cases; post-freeze |
| **COSMETIC** | ${bySeverity.COSMETIC.length} | Style, deprecations (non-blocking per \`analysis_options.yaml\`), unused imports |

| Analyzer level | Count |
|----------------|------:|
| \`warning\` | ${warnings} |
| \`info\` | ${infos} |

## CRITICAL — fix now?

${fixNowLine}

${bySeverity.CRITICAL.length ? `### CRITICAL items (${bySeverity.CRITICAL.length})\n\n${bySeverity.CRITICAL.map(formatItem).join('\n')}` : '_No CRITICAL items._'}

## IMPORTANT (all items)

${bySeverity.IMPORTANT.length ? bySeverity.IMPORTANT.map(formatItem).join('\n') : '_None._'}

## Rule breakdown (all ${issues.length} issues)

| Rule | Count |
|------|------:|
${Object.entries(byRule)
  .sort((a, b) => b[1] - a[1])
  .map(([r, c]) => `| \`${r}\` | ${c} |`)
  .join('\n')}

## Classification policy

- **CRITICAL**: Unguarded \`use_build_context_synchronously\` (widget disposed 뿯↽ runtime failure).
- **IMPORTANT**: Wrong \`mounted\` guard; \`unnecessary_null_comparison\` / \`unnecessary_cast\`; deprecated \`PlatformFile.bytes\` (OOM on large files).
- **COSMETIC**: \`deprecated_member_use\` (incl. \`withOpacity\`, configured as \`warning\` not error), braces/style lints, unused imports, tool \`unused_element\`.

## Release freeze action

- **Code changes this audit:** none (no 1-line safe CRITICAL fix applied).
- **Recommended post-freeze:** address CRITICAL async-context sites; batch \`withValues\` / deprecation migrations separately.

`;
  fs.writeFileSync(outPath, md, { encoding: 'utf8' });
  console.log(
    JSON.stringify({
      parsed: issues.length,
      CRITICAL: bySeverity.CRITICAL.length,
      IMPORTANT: bySeverity.IMPORTANT.length,
      COSMETIC: bySeverity.COSMETIC.length,
      criticalFixNow,
      warnings,
      infos,
    }),
  );
}

const docsDir = path.join(__dirname, '..', 'docs');
const targetFile = path.join(docsDir, 'CARAJAS360_RELATORIO_FASE8.md');
const expectedPrefixHex = '2320434152414a41';

const content = `# CARAJAS360 - Relatorio Fase 8 (Entrada - Bloqueada)

**Data entrada:** 2026-09-24  
**Tipo desta entrega:** Auditoria de bloqueio apenas — Fase 8 NAO iniciada operacionalmente  
**Branch:** release/carajas360-rc1  
**HEAD:** 1c47a74  
**Versao:** 1.0.0+402  
**Pagamentos:** OFF  
**Piloto:** PILOTO BLOQUEADO — NAO INICIADO  

## 1. Resumo executivo

- Fase 8 entrada: **BLOCKED**
- Piloto: **NAO iniciado**
- Commit: \`1c47a74\`
- Versao app: \`1.0.0+402\`
- Pagamentos: **OFF** (correto para este gate)

## 2. Bloqueadores (herdados F7, sem resolucao)

| Bloqueador | Estado |
|------------|--------|
| AAB/APK Android distribuivel | Nao produzido |
| Politica de privacidade / Termos (URLs publicas) | HTTP 404 |
| Gate F7 | **NO-GO** (\`CARAJAS360_GO_NO_GO.md\`) |

## 3. Testes automatizados (evidencia F7)

| Suite | Resultado |
|-------|-----------|
| Flutter | 134 pass, 1 skip (\`docs/evidence/fase7_flutter_test.txt\`) |
| npm (functions) | 115 pass (\`docs/evidence/fase7_npm_test.txt\`) |

## 4. Metricas

Nenhuma metrica de piloto ou producao — **nao inventar** nesta fase.

## 5. Conclusao

Fase 8 permanece **BLOCKED**. Piloto **nao deve** iniciar. Sem expansao publica. Sem Fase 9. Sem pagamentos reais.

## RAIANY — O QUE VOCE PRECISA FAZER

Nao cole secrets neste chat.

### A) Politica de Privacidade e Termos (bloqueador 404)

- **O QUE:** publicar paginas de privacidade e termos ate responder **HTTP 200** (URLs usadas pelo app).
- **COMO VALIDAR:** navegador anonimo abre o texto completo (hoje 404).

### B) Artefato Android RC

- **O QUE:** produzir **AAB assinado** (e APK de homologacao se necessario) e registrar **SHA-256** em \`docs/evidence\`.
- **O QUE NAO COMPARTILHAR:** senha do keystore, \`key.properties\` real, ou qualquer secret de assinatura.

### C) Testadores fechados (somente apos GO)

- **O QUE:** adicionar testadores fechados **somente depois** de GO documentado (F7/F8/piloto).
- **ONDE:** Google Play Console > teste fechado, quando o AAB existir.

### D) Ainda NAO autorizar

- **NAO** habilitar \`PRODUCTION_PAYMENTS_ENABLED\`
- **NAO** lancamento publico
- **NAO** piloto com usuarios reais enquanto o gate estiver BLOQUEADO
`;

function isUtf16LeMarkdown(buf) {
  if (buf.length < 2) return false;
  if (buf[0] === 0xff && buf[1] === 0xfe) return true;
  if (buf[0] === 0x23 && buf[1] === 0x00) return true;
  return false;
}

function utf16LeBufferToUtf8(buf) {
  let start = 0;
  if (buf[0] === 0xff && buf[1] === 0xfe) start = 2;
  const body = buf.subarray(start);
  if (body.length % 2 !== 0) {
    throw new Error('invalid utf16le length');
  }
  return body.toString('utf16le');
}

function scanAndConvertCarajasDocs() {
  const pattern = /^CARAJAS360_.*\.md$/;
  const entries = fs.readdirSync(docsDir);
  const conversions = [];

  for (const name of entries.sort()) {
    if (!pattern.test(name)) continue;
    const filePath = path.join(docsDir, name);
    const stat = fs.statSync(filePath);
    if (!stat.isFile()) continue;

    const buf = fs.readFileSync(filePath);
    if (!isUtf16LeMarkdown(buf)) {
      conversions.push({ file: name, action: 'unchanged', reason: 'utf8 or other encoding' });
      continue;
    }

    const utf8Text = utf16LeBufferToUtf8(buf);
    fs.writeFileSync(filePath, utf8Text, 'utf8');
    conversions.push({ file: name, action: 'converted', from: 'utf16le', to: 'utf8' });
  }

  return conversions;
}

function verifyFirst8Bytes(filePath) {
  const buf = fs.readFileSync(filePath);
  const hex = buf.subarray(0, 8).toString('hex');
  return {
    hex,
    ok: hex === expectedPrefixHex,
    expected: expectedPrefixHex,
    asciiPreview: buf.subarray(0, 8).toString('ascii'),
  };
}

const scanResults = scanAndConvertCarajasDocs();
fs.writeFileSync(targetFile, content, 'utf8');
const fase8Verify = verifyFirst8Bytes(targetFile);

const postScan = fs
  .readdirSync(docsDir)
  .filter((n) => /^CARAJAS360_.*\.md$/.test(n))
  .sort()
  .map((name) => {
    const p = path.join(docsDir, name);
    const buf = fs.readFileSync(p);
    const first8 = buf.subarray(0, 8).toString('hex');
    const utf16 = isUtf16LeMarkdown(buf);
    return { file: name, first8Hex: first8, utf16LeDetected: utf16 };
  });

console.log(
  JSON.stringify(
    {
      target: path.relative(path.join(__dirname, '..'), targetFile),
      writeEncoding: 'utf8',
      fase8First8Bytes: fase8Verify,
      utf16ScanAndConvert: scanResults,
      carajasDocsPostScan: postScan,
    },
    null,
    2,
  ),
);

if (!fase8Verify.ok) {
  process.exitCode = 1;
}
