#!/usr/bin/env bash
# Read-only diagnostics; never use sudo. Run: bash db1_doctor.sh
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$DIR/db1"; VENV="$PROJECT/.venv"
PASS=0; WARN=0; FAIL=0
ok(){ printf '[OK] %s\n' "$*"; PASS=$((PASS+1)); }
warn(){ printf '[WARN] %s\n' "$*"; WARN=$((WARN+1)); }
fail(){ printf '[FAIL] %s\n' "$*"; FAIL=$((FAIL+1)); }
echo '=== DB1 macOS doctor (read-only) ==='
if [[ "$(uname -s)" == Darwin ]]; then ok "macOS $(sw_vers -productVersion) / $(uname -m)"; else fail 'Not macOS'; fi
if (( EUID == 0 )); then fail 'Running as root. Stop using sudo for DB1.'; else ok "User: $(id -un)"; fi
if [[ -d "$PROJECT" && -w "$PROJECT" ]]; then ok "Writable project: $PROJECT"; else fail "Missing or unwritable project: $PROJECT (copy into ~/Projects)"; fi
if [[ "$DIR" == /Applications* || "$DIR" == /System* || "$DIR" == /usr/* || "$DIR" == /db1* ]]; then warn "Course files in system location: $DIR"; fi
if xcode-select -p >/dev/null 2>&1; then ok 'Xcode Command Line Tools'; else fail 'Xcode tools missing: xcode-select --install'; fi
BREW=''
for p in "$(command -v brew 2>/dev/null || true)" /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [[ -n "$p" && -x "$p" ]]; then BREW="$p"; break; fi
done
if [[ -n "$BREW" ]]; then
  ok "Homebrew: $BREW"
  if ! command -v brew >/dev/null 2>&1; then warn 'brew not on PATH in this terminal: check brew shellenv / ~/.zprofile'; fi
else fail 'Homebrew not found'; fi
if command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import sys; assert sys.version_info >= (3,10)' 2>/dev/null; then ok "Python: $(command -v python3) ($(python3 --version))"; else fail "Python version too old: $(python3 --version 2>&1)"; fi
else fail 'python3 not found'; fi
if [[ -x "$VENV/bin/python" ]]; then
  ok "Course venv: $VENV"
  if "$VENV/bin/python" -m pip --version >/dev/null 2>&1; then ok 'venv pip'; else fail 'venv pip broken'; fi
  if "$VENV/bin/python" -m pip show micropython-esp32-stubs >/dev/null 2>&1; then ok 'MicroPython ESP32 stubs installed'; else warn 'MicroPython stubs not detected in venv (check package metadata/name)'; fi
else fail "Course venv missing/broken: $VENV"; fi
if command -v esptool >/dev/null 2>&1; then
  if esptool version >/dev/null 2>&1; then ok "esptool: $(command -v esptool)"; else fail 'esptool executable fails'; fi
elif command -v esptool.py >/dev/null 2>&1; then
  if esptool.py version >/dev/null 2>&1; then ok 'Legacy esptool.py'; else fail 'esptool.py executable fails'; fi
else fail 'esptool command missing'; fi
CODE=''
for app in '/Applications/Visual Studio Code.app' "$HOME/Applications/Visual Studio Code.app"; do
  p="$app/Contents/Resources/app/bin/code"
  if [[ -x "$p" ]]; then CODE="$p"; break; fi
done
if [[ -n "$CODE" ]]; then
  ok 'VS Code CLI'
  EXTENSIONS="$("$CODE" --list-extensions 2>/dev/null || true)"
  for ext in pycom.Pymakr-preview ms-python.python; do
    if printf '%s\n' "$EXTENSIONS" | grep -Fxiq "$ext"; then ok "Extension: $ext"; else fail "VS Code extension missing: $ext"; fi
  done
else fail 'VS Code not found at standard app locations'; fi
if [[ -f "$DIR/micropython_esp32_stubs-1.21.0.post3.tar" ]]; then ok 'Stubs archive present'; else warn 'Stubs archive missing from course bundle'; fi
echo "=== Summary: $PASS OK, $WARN warnings, $FAIL failures ==="
echo 'ESP32 hardware not tested: connect board, check cable and /dev/cu.* manually.'
if (( FAIL > 0 )); then exit 1; fi
exit 0
