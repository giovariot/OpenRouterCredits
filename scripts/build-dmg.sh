#!/bin/bash
# Crea il DMG di distribuzione: app + collegamento ad Applicazioni.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="OpenRouterCredits"
VERSION="1.0.0"
APP="build/${APP_NAME}.app"
STAGE="build/dmg"
DMG="build/${APP_NAME}-${VERSION}.dmg"

if [[ ! -d "${APP}" ]]; then
    echo "errore: ${APP} non esiste, esegui prima ./scripts/build-app.sh" >&2
    exit 1
fi

echo "==> Preparazione della cartella"
rm -rf "${STAGE}"
mkdir -p "${STAGE}"
cp -R "${APP}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applicazioni"

echo "==> Creazione del DMG"
rm -f "${DMG}"
hdiutil create \
    -volname "OpenRouter Credits" \
    -srcfolder "${STAGE}" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "${DMG}" >/dev/null

rm -rf "${STAGE}"
hdiutil verify "${DMG}" >/dev/null

echo "Fatto: ${DMG}"
