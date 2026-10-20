#!/bin/bash
# Rifirma con il TUO certificato un'app scaricata dalla release di GitHub.
#
# La build di GitHub è firmata ad-hoc: senza un team ID l'app group non viene
# riconosciuto e il widget non vede le chiavi salvate nell'app. Questo script
# la installa in /Applications, la rifirma con il tuo certificato "Apple
# Development" (anche quello gratuito di Xcode), toglie la quarantena e
# registra il widget.
#
# Uso: ./scripts/resign.sh [percorso/di/OpenRouter Credits.app]
#      (senza argomenti rifirma quella già in /Applications)
set -euo pipefail

APP_BUNDLE_NAME="OpenRouter Credits"
WIDGET_BUNDLE_NAME="OpenRouter Credits Widget"
BUNDLE_ID="com.giovanni.openroutercredits"
DESTINATION="/Applications/${APP_BUNDLE_NAME}.app"
SOURCE="${1:-${DESTINATION}}"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ ! -d "${SOURCE}" ]]; then
    echo "errore: ${SOURCE} non esiste" >&2
    exit 1
fi

CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
if [[ -z "${CODESIGN_IDENTITY}" ]]; then
    CODESIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | awk '/Apple Development/ { print $2; exit }')"
fi
if [[ -z "${CODESIGN_IDENTITY}" ]]; then
    echo "errore: nessun certificato di firma trovato." >&2
    echo "Apri Xcode > Settings > Accounts per crearne uno, oppure indica" >&2
    echo "un'identità con CODESIGN_IDENTITY=<hash o nome>." >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# Il team ID si legge dalla firma di un file di prova.
touch "${TMP}/probe"
codesign --force --sign "${CODESIGN_IDENTITY}" --timestamp=none "${TMP}/probe" >/dev/null
TEAM_ID="$(codesign -dv --verbose=4 "${TMP}/probe" 2>&1 | sed -n 's/^TeamIdentifier=//p' | head -1)"
if [[ -z "${TEAM_ID}" ]]; then
    echo "errore: impossibile determinare il team ID di ${CODESIGN_IDENTITY}" >&2
    exit 1
fi
APP_GROUP="${TEAM_ID}.${BUNDLE_ID}"
echo "    identità: ${CODESIGN_IDENTITY}"
echo "    app group: ${APP_GROUP}"

echo "==> Chiusura dell'app in esecuzione"
osascript -e "tell application \"${APP_BUNDLE_NAME}\" to quit" >/dev/null 2>&1 || true
pkill -f "${DESTINATION}/Contents/MacOS/" 2>/dev/null || true
sleep 1

if [[ "${SOURCE}" != "${DESTINATION}" ]]; then
    echo "==> Copia in ${DESTINATION}"
    rm -rf "${DESTINATION}"
    cp -R "${SOURCE}" "${DESTINATION}"
fi

APPEX="${DESTINATION}/Contents/PlugIns/${WIDGET_BUNDLE_NAME}.appex"
if [[ ! -d "${APPEX}" ]]; then
    echo "errore: estensione widget non trovata in ${DESTINATION}" >&2
    exit 1
fi

cat > "${TMP}/entitlements.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>${APP_GROUP}</string>
    </array>
</dict>
</plist>
PLIST

echo "==> Rimozione della quarantena"
xattr -dr com.apple.quarantine "${DESTINATION}" 2>/dev/null || true

echo "==> Firma (prima l'estensione, poi l'app)"
codesign --force --sign "${CODESIGN_IDENTITY}" --timestamp=none \
    --entitlements "${TMP}/entitlements.plist" "${APPEX}"
codesign --force --sign "${CODESIGN_IDENTITY}" --timestamp=none \
    --entitlements "${TMP}/entitlements.plist" "${DESTINATION}"
codesign --verify --deep --strict "${DESTINATION}"

echo "==> Registrazione dell'estensione"
"${LSREGISTER}" -f "${DESTINATION}"
pluginkit -a "${APPEX}" 2>/dev/null || true

echo "==> Avvio dell'app"
open "${DESTINATION}"
killall chronod 2>/dev/null || true
sleep 3

if pluginkit -m -v -p com.apple.widgetkit-extension 2>/dev/null | grep -i "${BUNDLE_ID}"; then
    echo
    echo "Fatto. Il widget è in: clic destro sul desktop > Modifica widget… > ${APP_BUNDLE_NAME}"
else
    echo "    widget non ancora visibile: riprova tra qualche secondo o usa ./scripts/check-widget.sh"
fi
