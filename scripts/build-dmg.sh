#!/bin/bash
# Crea il DMG di distribuzione: app + collegamento ad Applicazioni + istruzioni.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_BUNDLE_NAME="OpenRouter Credits"
VERSION="${APP_VERSION:-1.2.0}"
APP="build/${APP_BUNDLE_NAME}.app"
STAGE="build/dmg"
DMG="build/OpenRouterCredits-${VERSION}.dmg"

if [[ ! -d "${APP}" ]]; then
    echo "errore: ${APP} non esiste, esegui prima ./scripts/build-app.sh" >&2
    exit 1
fi

echo "==> Preparazione della cartella"
rm -rf "${STAGE}"
mkdir -p "${STAGE}"
cp -R "${APP}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applicazioni"

# Il DMG viene scaricato dal browser e quindi quarantinato da Gatekeeper: senza
# il primo avvio "esplicito" l'app non parte e macOS non registra l'estensione
# widget, che quindi non compare nella galleria. Le istruzioni lo spiegano.
cat > "${STAGE}/Come installare.txt" <<'TXT'
OpenRouter Credits — installazione
=================================

1. Trascina "OpenRouter Credits" nella cartella Applicazioni.

2. Al primo avvio l'app non è notarizzata (è firmata con un certificato di
   sviluppo), quindi macOS la blocca. Sbloccala in uno di questi due modi:

   a) clic destro sull'app in Applicazioni > Apri > Apri;
   b) oppure, dal Terminale:

        xattr -dr com.apple.quarantine "/Applications/OpenRouter Credits.app"

   Questo passaggio è obbligatorio: finché l'app è "in quarantena" macOS non
   registra la sua estensione widget e il widget non compare nella galleria.

3. Apri l'app e incolla la chiave API di OpenRouter (da
   https://openrouter.ai/settings/keys), poi premi "Salva chiavi".

4. Aggiungi il widget: clic destro sul desktop > Modifica widget… >
   cerca "OpenRouter Credits" > scegli piccolo o medio.

Se il widget non compare subito, apri il Terminale ed esegui:

    killall chronod

---

OpenRouter Credits — installation
=================================

1. Drag "OpenRouter Credits" into your Applications folder.

2. On first launch macOS blocks the app (it is not notarized: it is signed
   with a development certificate). Allow it either by right-clicking the app
   in Applications > Open > Open, or by running:

        xattr -dr com.apple.quarantine "/Applications/OpenRouter Credits.app"

   This step is required: while the app is quarantined, macOS does not register
   its widget extension and the widget does not appear in the gallery.

3. Open the app, paste your OpenRouter API key, press "Save keys".

4. Add the widget: right-click the desktop > Edit Widgets… > search for
   "OpenRouter Credits" > pick the small or medium size.

If the widget does not show up, run:

    killall chronod
TXT

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
