#!/bin/bash
# Controlla che l'app e l'estensione widget siano installate e funzionanti.
set -uo pipefail

APP_NAME="OpenRouterCredits"
WIDGET_NAME="OpenRouterCreditsWidget"
APP="/Applications/${APP_NAME}.app"
APPEX="${APP}/Contents/PlugIns/${WIDGET_NAME}.appex"

# Stampa "sandbox=<true|false>" e "group=<app group o vuoto>".
entitlement_report() {
    local tmp
    tmp="$(mktemp)"
    codesign -d --entitlements - --xml "$1" 2>/dev/null | sed -n '/<?xml/,$p' > "${tmp}"
    python3 - "${tmp}" <<'PY'
import plistlib, sys
try:
    with open(sys.argv[1], "rb") as handle:
        entitlements = plistlib.load(handle)
except Exception:
    entitlements = {}
groups = entitlements.get("com.apple.security.application-groups") or []
print("sandbox=" + str(entitlements.get("com.apple.security.app-sandbox", False)).lower())
print("group=" + (groups[0] if groups else ""))
PY
    rm -f "${tmp}"
}

REPORT="$(entitlement_report "${APPEX}")"
SANDBOX="$(printf '%s\n' "${REPORT}" | sed -n 's/^sandbox=//p')"
GROUP="$(printf '%s\n' "${REPORT}" | sed -n 's/^group=//p')"
DATA_DIR=""
if [[ -n "${GROUP}" ]]; then
    DATA_DIR="${HOME}/Library/Group Containers/${GROUP}/${APP_NAME}"
fi

echo "== App installata"
if [[ -d "${APP}" ]]; then
    codesign -dv "${APP}" 2>&1 | grep -E "Identifier=|TeamIdentifier=|Signature=" | sed 's/^/    /'
else
    echo "    manca ${APP}: esegui ./scripts/install.sh"
fi

echo
echo "== Estensione registrata (pluginkit)"
if pluginkit -m -v -p com.apple.widgetkit-extension 2>/dev/null | grep -i "${WIDGET_NAME}"; then
    :
else
    echo "    non registrata: esegui ./scripts/install.sh e apri l'app una volta"
fi

echo
echo "== Sandbox e app group dell'estensione"
echo "    app-sandbox: ${SANDBOX:-sconosciuto}"
echo "    app group:   ${GROUP:-nessuno (il widget non potrà leggere i dati)}"

echo
echo "== Processo del widget"
if pgrep -fl "${WIDGET_NAME}" >/dev/null 2>&1; then
    pgrep -fl "${WIDGET_NAME}" | sed 's/^/    /'
else
    echo "    non in esecuzione (viene avviato dal sistema quando il widget è sul desktop)"
fi

echo
echo "== Dati condivisi"
if [[ -n "${DATA_DIR}" && -d "${DATA_DIR}" ]]; then
    ls -la "${DATA_DIR}" | sed 's/^/    /'
    if [[ -f "${DATA_DIR}/state.json" ]]; then
        python3 - "${DATA_DIR}/state.json" <<'PY' 2>/dev/null | sed 's/^/    /'
import json, sys
state = json.load(open(sys.argv[1]))
snapshot = state.get("snapshot") or {}
print("credito residuo:", snapshot.get("accountRemaining"))
print("limite chiave:  ", snapshot.get("keyLimitRemaining"))
print("aggiornato:     ", snapshot.get("updatedAt"))
print("ultimo errore:  ", state.get("lastError"))
print("campioni:       ", len(state.get("history", [])))
PY
    fi
else
    echo "    la cartella non esiste ancora: apri l'app e salva una chiave"
fi

echo
echo "== Errori recenti dell'estensione (ultimi 30 minuti)"
ERRORS="$(log show --last 30m --info --debug --predicate "process == \"${WIDGET_NAME}\"" --style compact 2>/dev/null \
    | grep -iE "error|crash|denied" \
    | grep -v "An XPC Service cannot be run directly" \
    | grep -v "libxpc.dylib" \
    | tail -10)"
if [[ -n "${ERRORS}" ]]; then
    echo "${ERRORS}" | sed 's/^/    /'
else
    echo "    nessun errore"
fi

echo
echo "== Ultime richieste ricevute dal widget"
if [[ -n "${DATA_DIR}" && -f "${DATA_DIR}/widget-trace.log" ]]; then
    tail -6 "${DATA_DIR}/widget-trace.log" | sed 's/^/    /'
    if ! grep -q "timeline" "${DATA_DIR}/widget-trace.log"; then
        echo "    attenzione: il widget non ha mai chiesto la timeline"
        echo "    (controlla che il metadata AppIntents sia nell'estensione)"
    fi
else
    echo "    nessuna traccia: apri l'app una volta e aggiungi il widget"
fi
