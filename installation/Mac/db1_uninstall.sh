#!/usr/bin/env bash
# DB1 macOS uninstaller. Does NOT remove Homebrew, Python, VS Code or extensions.
# Run as a regular user: bash db1_uninstall.sh

if [ -z "$BASH_VERSION" ]; then
  echo
  echo "This script must be run with bash."
  echo "Please run:"
  echo "    bash $(basename "$0")"
  echo
  exit 1
fi

set -Eeuo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$DIR/db1"
VENV="$PROJECT/.venv"
if (( EUID == 0 )); then echo 'ERROR: Do not run with sudo.' >&2; exit 1; fi
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS only.' >&2; exit 1; }
[[ -d "$PROJECT" && ! -L "$PROJECT" ]] || { echo 'Course project missing or symlinked; refusing.' >&2; exit 1; }
[[ "$VENV" == "$PROJECT/.venv" && "$PROJECT" != / && "$PROJECT" != "$HOME" ]] || { echo 'Unsafe cleanup target.' >&2; exit 1; }
if [[ ! -e "$VENV" && ! -L "$VENV" ]]; then echo 'No DB1 .venv to remove. Nothing changed.'; exit 0; fi
if [[ -L "$VENV" ]]; then echo 'Refusing to delete symlinked .venv; ask a TA.' >&2; exit 1; fi
[[ -d "$VENV" ]] || { echo 'Unexpected .venv file; ask a TA.' >&2; exit 1; }
printf 'Will delete ONLY this course virtual environment:\n  %s\n' "$VENV"
echo 'Will NOT remove your source files, Homebrew, Python, esptool, VS Code, or extensions.'
read -r -p 'Type DELETE to confirm: ' reply
if [[ "$reply" != DELETE ]]; then echo 'Cancelled. No changes.'; exit 0; fi
rm -rf -- "$VENV"
echo 'Course virtual environment removed. Everything else left alone.'
