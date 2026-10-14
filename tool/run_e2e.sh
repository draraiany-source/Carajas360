#!/usr/bin/env bash
# Fase 7: compila os harnesses web e roda os E2E, cada um num emulador limpo.
# Somente dev/emulador (projeto demo-carajas360); nada sai da máquina.
#
# Uso: tool/run_e2e.sh <dir-saida> <firebase-js-sdk-dir> [catalog checkout resolve schedule phase6]
#   <firebase-js-sdk-dir>: node_modules/firebase (v12) servido no lugar do CDN.
# Requer: flutter, firebase-tools, Playwright (PLAYWRIGHT_MODULE) e Chromium (CHROMIUM_PATH).
set -u
OUT=${1:?dir de saída}; SDK=${2:?dir do firebase js sdk}; shift 2
SUITES=${*:-catalog checkout resolve schedule phase6}
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
FLUTTER=${FLUTTER:-flutter}
mkdir -p "$OUT"

defines() {
  # checkout e resolve pagam com o gateway falso do emulador.
  case $1 in
    checkout|resolve) echo "--dart-define=APP_ENV=dev --dart-define=PAYMENTS_FAKE_TOKENS=true" ;;
    *) echo "--dart-define=APP_ENV=dev" ;;
  esac
}

summary="$OUT/resumo.txt"; : > "$summary"; failed=0
for s in $SUITES; do
  web="$OUT/web_$s"; ev="$OUT/evidencias_$s"; mkdir -p "$ev"
  # shellcheck disable=SC2046
  if ! $FLUTTER build web --profile --no-web-resources-cdn $(defines "$s") \
      -t "test_driver/e2e_${s}_main.dart" --output="$web" > "$OUT/build_$s.log" 2>&1; then
    echo "$s: BUILD FALHOU (ver build_$s.log)" | tee -a "$summary"; failed=1; continue
  fi
  firebase emulators:exec --project demo-carajas360 --only auth,firestore,storage,functions \
    "node firebase-tests/e2e/$s.e2e.js $web $ev $SDK" > "$OUT/e2e_$s.log" 2>&1
  rc=$?
  ok=$(sed -n '/^RESULTS {/,/^}/p' "$OUT/e2e_$s.log" | grep -c '": "OK"')
  total=$(sed -n '/^RESULTS {/,/^}/p' "$OUT/e2e_$s.log" | grep -c '": "')
  echo "$s: exit=$rc $ok/$total" | tee -a "$summary"
  [ $rc -eq 0 ] || failed=1
done
# Builds de harness alteram o registrante de plugins Android; desfaz.
git checkout -q -- android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java 2>/dev/null || true
exit $failed
