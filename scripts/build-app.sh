#!/bin/bash
# Costruisce OpenRouterCredits.app con l'estensione widget incorporata.
#
# SwiftPM non sa produrre bundle .app/.appex, quindi li assembliamo a mano:
# binari universali, Info.plist corretti, entitlements (sandbox + app group),
# correzione di LC_BUILD_VERSION e firma con un certificato reale. Vedi il
# README per il perché di queste ultime due.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="OpenRouterCredits"
WIDGET_NAME="OpenRouterCreditsWidget"
BUNDLE_ID="com.giovanni.openroutercredits"
WIDGET_BUNDLE_ID="${BUNDLE_ID}.widget"
VERSION="1.0"
BUILD_NUMBER="1"
DEPLOYMENT_TARGET="14.0"

# Firma: serve un certificato reale ("Apple Development"). Con la firma
# ad-hoc il sandbox non riconosce l'app group e l'app non riesce a leggere i
# dati condivisi (e il widget non si registra affatto senza sandbox).
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

OUT_DIR="build"
APP_DIR="${OUT_DIR}/${APP_NAME}.app"
APPEX_DIR="${APP_DIR}/Contents/PlugIns/${WIDGET_NAME}.appex"

SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"

detect_team_id() {
    local tmp
    tmp="$(mktemp)"
    local team=""
    if codesign --force --sign "${CODESIGN_IDENTITY}" --timestamp=none "${tmp}" >/dev/null 2>&1; then
        team="$(codesign -dv --verbose=4 "${tmp}" 2>&1 | sed -n 's/^TeamIdentifier=//p' | head -1)"
    fi
    rm -f "${tmp}"
    echo "${team}"
}

if [[ -n "${APP_GROUP_ID:-}" ]]; then
    APP_GROUP="${APP_GROUP_ID}"
elif [[ "${CODESIGN_IDENTITY}" == "-" ]]; then
    # Firma ad-hoc: nessun team, quindi nessun prefisso.
    APP_GROUP="group.com.giovanni.openroutercredits"
else
    TEAM_ID="$(detect_team_id)"
    if [[ -z "${TEAM_ID}" ]]; then
        echo "errore: impossibile determinare il team ID di ${CODESIGN_IDENTITY}" >&2
        exit 1
    fi
    APP_GROUP="${TEAM_ID}.com.giovanni.openroutercredits"
fi
echo "    identità: ${CODESIGN_IDENTITY}"

echo "==> Compilazione release universale (arm64 + x86_64)"
# I const values servono per estrarre il metadata AppIntents (impostazioni del
# widget): senza, il sistema non riesce a risolvere la configurazione.
swift build -c release --arch arm64 --arch x86_64 -Xswiftc -emit-const-values

# La cartella dei prodotti cambia tra versioni di SwiftPM.
PRODUCTS_DIR=""
for candidate in ".build/apple/Products/Release" ".build/out/Products/Release" ".build/release"; do
    if [[ -x "${candidate}/${APP_NAME}" && -x "${candidate}/${WIDGET_NAME}" ]]; then
        PRODUCTS_DIR="${candidate}"
        break
    fi
done

if [[ -z "${PRODUCTS_DIR}" ]]; then
    echo "errore: prodotti di build non trovati" >&2
    exit 1
fi

echo "==> Icona dell'app"
mkdir -p "${OUT_DIR}"
"${PRODUCTS_DIR}/CreditsIconGen" "${OUT_DIR}" >/dev/null
if [[ ! -f "${OUT_DIR}/AppIcon.icns" || "${OUT_DIR}/AppIcon.iconset" -nt "${OUT_DIR}/AppIcon.icns" ]]; then
    iconutil -c icns "${OUT_DIR}/AppIcon.iconset" -o "${OUT_DIR}/AppIcon.icns"
fi

echo "==> Assemblaggio del bundle"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources" "${APPEX_DIR}/Contents/MacOS" "${APPEX_DIR}/Contents/Resources"

cp "${PRODUCTS_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "${PRODUCTS_DIR}/${WIDGET_NAME}" "${APPEX_DIR}/Contents/MacOS/${WIDGET_NAME}"
cp "${OUT_DIR}/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"

# Le traduzioni servono in entrambi i bundle: il widget le cerca nel proprio.
for lproj in Localization/*.lproj; do
    cp -R "${lproj}" "${APP_DIR}/Contents/Resources/"
    cp -R "${lproj}" "${APPEX_DIR}/Contents/Resources/"
done

# WidgetKit risolve le impostazioni del widget (WidgetConfigurationIntent)
# leggendo il metadata AppIntents: Xcode lo genera con questo strumento a
# partire dai const values emessi dal compilatore. Senza, il widget resta sul
# placeholder e non riceve mai la timeline.
echo "==> Metadata AppIntents (impostazioni del widget)"
METADATA_TOOL="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsmetadataprocessor"
if [[ ! -x "${METADATA_TOOL}" ]]; then
    METADATA_TOOL="$(xcrun --find appintentsmetadataprocessor 2>/dev/null || true)"
fi
if [[ -z "${METADATA_TOOL}" || ! -x "${METADATA_TOOL}" ]]; then
    echo "errore: appintentsmetadataprocessor non trovato (serve Xcode)" >&2
    exit 1
fi

CONST_VALUES_LIST="${OUT_DIR}/widget-const-values.txt"
find .build -path "*OpenRouterCreditsWidget-p.build*" -name "*-primary.swiftconstvalues" -type f > "${CONST_VALUES_LIST}"
if [[ ! -s "${CONST_VALUES_LIST}" ]]; then
    echo "errore: nessun const value del widget trovato" >&2
    exit 1
fi

SOURCE_LIST="${OUT_DIR}/widget-sources.txt"
ls Sources/OpenRouterCreditsWidget/*.swift > "${SOURCE_LIST}"

XCODE_VERSION="$(xcodebuild -version 2>/dev/null | awk '/^Xcode / { gsub(/\./, "", $2); print $2 "00" }' | head -1)"
XCODE_VERSION="${XCODE_VERSION:-2700}"

rm -rf "${OUT_DIR}/metadata"
"${METADATA_TOOL}" \
    --output "${OUT_DIR}/metadata" \
    --toolchain-dir "$(dirname "$(dirname "$(xcrun --find swiftc)")")" \
    --module-name "${WIDGET_NAME}" \
    --sdk-root "$(xcrun --sdk macosx --show-sdk-path)" \
    --xcode-version "${XCODE_VERSION}" \
    --platform-family macOS \
    --deployment-target "${DEPLOYMENT_TARGET}" \
    --target-triple "$(uname -m)-apple-macos${DEPLOYMENT_TARGET}" \
    --source-file-list "${SOURCE_LIST}" \
    --swift-const-vals-list "${CONST_VALUES_LIST}"

if [[ ! -f "${OUT_DIR}/metadata/Metadata.appintents/extract.actionsdata" ]]; then
    echo "errore: metadata AppIntents non generato" >&2
    exit 1
fi
cp -R "${OUT_DIR}/metadata/Metadata.appintents" "${APPEX_DIR}/Contents/Resources/"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>OpenRouter Credits</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>${DEPLOYMENT_TARGET}</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>${BUNDLE_ID}</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>openroutercredits</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

cat > "${APPEX_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>OpenRouter Credits</string>
    <key>CFBundleExecutable</key>
    <string>${WIDGET_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${WIDGET_BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${WIDGET_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>${DEPLOYMENT_TARGET}</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
PLIST

# macOS registra un'estensione widget solo se è sandboxata; l'app group serve
# a condividere chiavi e dati tra app e widget.
echo "==> Entitlement (sandbox + app group ${APP_GROUP})"
ENTITLEMENTS_DIR="${OUT_DIR}/entitlements"
mkdir -p "${ENTITLEMENTS_DIR}"

for variant in app widget; do
    cat > "${ENTITLEMENTS_DIR}/${variant}.entitlements" <<PLIST
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
done

# SwiftPM scrive il deployment target al posto dell'SDK in LC_BUILD_VERSION.
# macOS decide l'aspetto di finestre e widget dall'SDK con cui il binario
# risulta collegato: senza questa correzione il widget verrebbe disegnato con
# il layout di compatibilità di macOS 14.
echo "==> Correzione di LC_BUILD_VERSION (minos ${DEPLOYMENT_TARGET}, sdk ${SDK_VERSION})"
for binary in "${APP_DIR}/Contents/MacOS/${APP_NAME}" "${APPEX_DIR}/Contents/MacOS/${WIDGET_NAME}"; do
    vtool -set-build-version macos "${DEPLOYMENT_TARGET}" "${SDK_VERSION}" -replace -output "${binary}" "${binary}"
done

echo "==> Firma (${CODESIGN_IDENTITY}: prima l'estensione, poi l'app)"
codesign --force --sign "${CODESIGN_IDENTITY}" --timestamp=none \
    --entitlements "${ENTITLEMENTS_DIR}/widget.entitlements" "${APPEX_DIR}"
codesign --force --sign "${CODESIGN_IDENTITY}" --timestamp=none \
    --entitlements "${ENTITLEMENTS_DIR}/app.entitlements" "${APP_DIR}"

echo "==> Verifica"
codesign --verify --deep --strict "${APP_DIR}"
codesign -d --entitlements - "${APPEX_DIR}" 2>/dev/null | grep -A3 application-groups | tail -2
vtool -show-build "${APPEX_DIR}/Contents/MacOS/${WIDGET_NAME}" | grep -E "platform|minos|sdk"
lipo -info "${APP_DIR}/Contents/MacOS/${APP_NAME}" | sed 's/^/    /'

echo
echo "Fatto: ${APP_DIR}"
echo "Per installarlo e registrare il widget: ./scripts/install.sh"
