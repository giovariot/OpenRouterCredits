#!/bin/bash
# Installa l'app in /Applications, la registra in LaunchServices/pluginkit e la
# apre una volta: da quel momento il widget compare nella galleria widget.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="OpenRouterCredits"
SOURCE="build/${APP_NAME}.app"
DESTINATION="/Applications/${APP_NAME}.app"

if [[ ! -d "${SOURCE}" ]]; then
    echo "errore: ${SOURCE} non esiste, esegui prima ./scripts/build-app.sh" >&2
    exit 1
fi

echo "==> Chiusura dell'app in esecuzione"
osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true

echo "==> Copia in ${DESTINATION}"
rm -rf "${DESTINATION}"
cp -R "${SOURCE}" "${DESTINATION}"

echo "==> Registrazione dell'estensione"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"${LSREGISTER}" -f "${DESTINATION}"
pluginkit -a "${DESTINATION}/Contents/PlugIns/${APP_NAME}Widget.appex" 2>/dev/null || true

echo "==> Avvio dell'app (serve una volta perché il widget venga scoperto)"
open "${DESTINATION}"

echo "==> Estensioni widget registrate:"
pluginkit -m -v -p com.apple.widgetkit-extension 2>/dev/null | grep -i openrouter || echo "    (non ancora visibile: riprova tra qualche secondo)"
