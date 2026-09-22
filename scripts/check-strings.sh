#!/bin/bash
# Controlla i file di traduzione: sintassi, chiavi allineate e chiavi usate nel
# codice. Le chiavi sono le frasi italiane in Localization/it.lproj.
set -euo pipefail

cd "$(dirname "$0")/.."

python3 - <<'PY'
import re
import subprocess
import sys
from pathlib import Path

localization = Path("Localization")
base = localization / "it.lproj/Localizable.strings"

if not base.exists():
    print(f"manca {base}")
    sys.exit(1)

def keys_of(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    return set(re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', text, re.M))

problems = 0

files = sorted(localization.glob("*.lproj/Localizable.strings"))
for file in files:
    # plutil conosce anche il formato storico `"chiave" = "valore";`
    result = subprocess.run(["plutil", "-lint", str(file)], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"sintassi non valida in {file}: {result.stdout.strip()}{result.stderr.strip()}")
        problems += 1

base_keys = keys_of(base)
for file in files:
    if file == base:
        continue
    keys = keys_of(file)
    missing = base_keys - keys
    extra = keys - base_keys
    if missing:
        print(f"{file.parent.name}: mancano {len(missing)} chiavi, per esempio {sorted(missing)[:3]}")
        problems += 1
    if extra:
        print(f"{file.parent.name}: chiavi non previste {sorted(extra)[:3]}")
        problems += 1

code_keys: set[str] = set()
for file in Path("Sources").rglob("*.swift"):
    text = file.read_text(encoding="utf-8")
    code_keys |= set(re.findall(r'Strings\.text\("([^"]+)"', text))
    if "CreditsWidgetIntent" in file.name:
        code_keys |= set(re.findall(r'(?:title|subtitle):\s*"([^"]+)"', text))
        code_keys |= set(re.findall(r'description:\s*"([^"]+)"', text))
        code_keys |= set(re.findall(r'TypeDisplayRepresentation\(name:\s*"([^"]+)"', text))
        code_keys |= set(re.findall(r'IntentDescription\("([^"]+)"', text))
    if file.name == "CreditsWidget.swift":
        code_keys |= set(re.findall(r'configurationDisplayName\("([^"]+)"', text))
        code_keys |= set(re.findall(r'\.description\("([^"]+)"', text))
code_keys.add("OpenRouter Credits")

used_but_missing = code_keys - base_keys
unused = base_keys - code_keys

if used_but_missing:
    print(f"chiavi usate nel codice ma assenti in it.lproj: {sorted(used_but_missing)}")
    problems += 1
if unused:
    print(f"nota: chiavi in it.lproj non (più) usate nel codice: {sorted(unused)}")

languages = sorted(file.parent.name for file in files)
print(f"{len(languages)} lingue: {', '.join(languages)}")
print(f"{len(base_keys)} chiavi")
if problems:
    print(f"{problems} problemi da sistemare")
    sys.exit(1)
print("tutte le traduzioni sono allineate")
PY
