#!/usr/bin/env bash
# DB1 macOS installer. 
# Run as a regular user: bash db1_install.sh

if [ -z "$BASH_VERSION" ]; then
  echo
  echo "This script must be run with bash."
  echo "Please run:"
  echo "    bash $(basename "$0")"
  echo
  exit 1
fi

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$SCRIPT_DIR/db1"
VENV="$PROJECT/.venv"
STUBS="$SCRIPT_DIR/micropython_esp32_stubs-1.21.0.post3.tar"
LOG="$SCRIPT_DIR/db1_install.log"

if (( EUID == 0 )); then echo 'ERROR: Do not run this installer with sudo.' >&2; exit 1; fi
if [[ "$(uname -s)" != Darwin ]]; then echo 'ERROR: This installer is macOS-only.' >&2; exit 1; fi

# Students may keep DB1 anywhere they have write access (permissions!)
if [[ ! -d "$PROJECT" ]]; then
  echo "ERROR: Course project folder not found: $PROJECT" >&2
  echo "Make sure you extracted the complete DB1 installation ZIP." >&2
  exit 1
fi

# Test actual write access instead of assuming a specific location (permissions!)
for dir in "$SCRIPT_DIR" "$PROJECT"; do
  if ! test_file="$(mktemp "$dir/.db1-write-test.XXXXXX" 2>/dev/null)"; then
    echo "ERROR: Cannot write to: $dir" >&2
    echo "Move the extracted DB1 folder to a location you can edit." >&2
    echo "Your university coursework folder is fine." >&2
    exit 1
  fi
  rm -f "$test_file"
done

# Logging
exec > >(tee -a "$LOG") 2>&1
trap 'status=$?; echo "ERROR line $LINENO: $BASH_COMMAND (exit $status)" >&2' ERR

section() { printf '\n\033[1;36m━━ %s ━━\033[0m\n' "$1"; }
info()    { printf '  \033[0;34m→\033[0m %s\n' "$1"; }
warn()    { printf '  \033[0;33m!\033[0m %s\n' "$1"; }

printf '\n\033[1;36m╭──────────────────────────────────────╮\n│          DB1 · Mac setup            │\n╰──────────────────────────────────────╯\033[0m\n'
info "Started: $(date)"
info "User: $(id -un)  ·  macOS $(sw_vers -productVersion)  ·  $(uname -m)"
section '1 / 3  Prerequisites'

# Xcode Command Line Tools
if ! xcode-select -p >/dev/null 2>&1; then
  echo 'Xcode Command Line Tools needed. Complete the popup, then rerun.'
  xcode-select --install || true
  exit 1
fi

# Homebrew
find_brew() {
  if command -v brew >/dev/null 2>&1; then command -v brew; return; fi
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$p" ]]; then printf '%s\n' "$p"; return; fi
  done
  return 1
}
if ! BREW_BIN="$(find_brew)"; then
  echo 'Installing Homebrew (its own installer may request admin authorization)...'
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW_BIN="$(find_brew)" || { echo 'ERROR: Homebrew not found after install.'; exit 1; }
fi
eval "$("$BREW_BIN" shellenv)"

"$BREW_BIN" update
# Make Homebrew commands available in future macOS Terminal sessions (zsh).
# Add its setup line to ~/.zprofile only if missing; keep existing settings.
BREW_INIT="eval \"\$($BREW_BIN shellenv)\""
touch "$HOME/.zprofile"
if ! grep -Fqx "$BREW_INIT" "$HOME/.zprofile"; then printf '%s\n' "$BREW_INIT" >> "$HOME/.zprofile"; fi
"$BREW_BIN" --version | head -n 1

# Visual Studio Code
VSCODE_APP=''
for app in '/Applications/Visual Studio Code.app' "$HOME/Applications/Visual Studio Code.app"; do
  if [[ -d "$app" ]]; then VSCODE_APP="$app"; break; fi
done
if [[ -z "$VSCODE_APP" ]]; then
  "$BREW_BIN" install --cask visual-studio-code
  VSCODE_APP='/Applications/Visual Studio Code.app'
fi
CODE="$VSCODE_APP/Contents/Resources/app/bin/code"
[[ -x "$CODE" ]] || { echo "ERROR: VS Code CLI missing: $CODE"; exit 1; }

# Avoid creating the course environment from an active Conda installation.
if [[ -n "${CONDA_PREFIX:-}" ]]; then
  echo "WARNING: Conda environment detected."
  echo "Please run 'conda deactivate' before starting this installer."
  exit 1
fi

# Select one Python interpreter for the whole course environment.
if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; assert sys.version_info >= (3,10)' 2>/dev/null; then
  PYTHON_BIN="$(command -v python3)"
else
  "$BREW_BIN" install python
  eval "$("$BREW_BIN" shellenv)"
  PYTHON_BIN="$(command -v python3)"
fi
"$PYTHON_BIN" -c 'import sys; assert sys.version_info >= (3,10), "Python >=3.10 required"'
echo "Python: $PYTHON_BIN ($("$PYTHON_BIN" --version))"
if ! command -v esptool >/dev/null 2>&1 && ! command -v esptool.py >/dev/null 2>&1; then
  "$BREW_BIN" install esptool
fi
if command -v esptool >/dev/null 2>&1; then ESPTOOL=esptool
elif command -v esptool.py >/dev/null 2>&1; then ESPTOOL=esptool.py
else echo 'ERROR: esptool missing after installation.'; exit 1; fi
"$ESPTOOL" version

section '2 / 3  Course environment'

if [[ -e "$VENV" && ! -x "$VENV/bin/python" ]]; then
  echo "ERROR: Broken virtual environment: $VENV"
  echo 'The existing .venv looks incomplete. Rename or remove only db1/.venv, then rerun this installer.'; exit 1
fi
if [[ ! -d "$VENV" ]]; then "$PYTHON_BIN" -m venv "$VENV"; fi
"$VENV/bin/python" -m pip --version
if [[ -f "$STUBS" ]]; then
  "$VENV/bin/python" -m pip install --upgrade "$STUBS"
else
  warn 'MicroPython stubs archive not found.'
  info 'Run this script from the complete extracted course ZIP folder, with the .tar archive beside the installer.'
fi
for extension in pycom.Pymakr-preview ms-python.python; do
  if ! "$CODE" --list-extensions | grep -Fxiq "$extension"; then
    "$CODE" --install-extension "$extension"
  fi
done

# Open the DB1 project in VS Code after installation.
if [[ -d "$PROJECT" ]]; then
    if [[ -n "${CODE:-}" && -x "$CODE" ]]; then
        "$CODE" "$PROJECT" || echo "WARNING: Could not open the DB1 project."
    else
        echo "WARNING: VS Code CLI unavailable. Open $PROJECT manually."
    fi
fi

section '3 / 3  Verification'
bash "$SCRIPT_DIR/db1_doctor.sh"
printf '\n\033[1;32m✓ DB1 setup finished.\033[0m\n'
info 'Check the verification results above; follow any WARN/FAIL instructions.'
