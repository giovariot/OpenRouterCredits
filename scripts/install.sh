#!/bin/bash
# Installa l'app in /Applications, la registra in LaunchServices/pluginkit e la
# apre una volta: da quel momento il widget compare nella galleria widget.
#
# Nota: se l'app arriva da un DMG scaricato dal browser porta l'attributo di
# quarantena di Gatekeeper, e macOS non registra le estensioni delle app in
# quarantena (il widget non compare nella galleria). Qui la quarantena viene
# rimossa, così la registrazione funziona sempre.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_BUNDLE_NAME="OpenRouter Credits"
APP_EXECUTABLE="OpenRouterCredits"
WIDGET_BUNDLE_NAME="OpenRouter Credits Widget"
BUNDLE_ID="com.giovanni.openroutercredits"

SOURCE="build/${APP_BUNDLE_NAME}.app"
DESTINATION="/Applications/${APP_BUNDLE_NAME}.app"
LEGACY_DESTINATION="/Applications/OpenRouterCredits.app"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ ! -d "${SOURCE}" ]]; then
    echo "errore: ${SOURCE} non esiste, esegui prima ./scripts/build-app.sh" >&2
    exit 1
fi

echo "==> Chiusura dell'app in esecuzione"
osascript -e "tell application \"${APP_BUNDLE_NAME}\" to quit" >/dev/null 2>&1 || true
pkill -f "/Applications/${APP_BUNDLE_NAME}.app/Contents/MacOS/" 2>/dev/null || true
sleep 1

if [[ -d "${LEGACY_DESTINATION}" ]]; then
    echo "==> Rimozione della versione con il vecchio nome"
    "${LSREGISTER}" -u "${LEGACY_DESTINATION}" >/dev/null 2>&1 || true
    rm -rf "${LEGACY_DESTINATION}"
fi

echo "==> Copia in ${DESTINATION}"
rm -rf "${DESTINATION}"
cp -R "${SOURCE}" "${DESTINATION}"

echo "==> Rimozione della quarantena (necessaria per registrare il widget)"
xattr -dr com.apple.quarantine "${DESTINATION}" 2>/dev/null || true

echo "==> Registrazione dell'estensione"
"${LSREGISTER}" -f "${DESTINATION}"
pluginkit -a "${DESTINATION}/Contents/PlugIns/${WIDGET_BUNDLE_NAME}.appex" 2>/dev/null || true

echo "==> Avvio dell'app (serve una volta perché il widget venga scoperto)"
open "${DESTINATION}"

echo "==> Aggiornamento della galleria widget"
killall chronod 2>/dev/null || true
sleep 3

echo "==> Estensioni widget registrate:"
if pluginkit -m -v -p com.apple.widgetkit-extension 2>/dev/null | grep -i "${BUNDLE_ID}"; then
    echo
    echo "Fatto. Il widget è in: clic destro sul desktop > Modifica widget… > ${APP_BUNDLE_NAME}"
else
    echo "    non ancora visibile."
    echo "    Riprova tra qualche secondo, oppure riavvia il Mac se non compare."
    echo "    Diagnostica: ./scripts/check-widget.sh"
fi
