#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  echo
  echo "This script must be run with bash."
  echo "Please run:"
  echo "    bash $(basename "$0")"
  echo
  exit 1
fi

# Exit immediately if a command exits with a non-zero status
set -e

# Define log file
LOG_FILE="uninstall.log"

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Define demo project directory within SCRIPT_DIR
DEMO_PROJECT_DIR="$SCRIPT_DIR/db1"

# Define checklist file
CHECKLIST_FILE="$SCRIPT_DIR/install_checklist.txt"

# Function to log and execute commands
execute_and_log() {
    echo "Executing: $*" | tee -a "$LOG_FILE"
    "$@" 2>&1 | tee -a "$LOG_FILE"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo "Error executing: $*" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Function to check command existence
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "========================================" | tee -a "$LOG_FILE"
echo "Uninstallation started at $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

# Check if checklist file exists
if [ ! -f "$CHECKLIST_FILE" ]; then
    echo "Checklist file not found at $CHECKLIST_FILE. Cannot proceed with uninstallation." | tee -a "$LOG_FILE"
    exit 1
fi

# Read all lines into a variable and reverse the order using awk
reversed_lines=$(awk '{ lines[NR] = $0 } END { for (i=NR; i>=1; i--) print lines[i] }' "$CHECKLIST_FILE")

# Iterate over the reversed lines
while IFS='=' read -r key value; do
    # Skip empty lines
    [ -z "$key" ] && continue
    case "$key" in
        micropython_stubs_installed)
            if [ "$value" = "true" ]; then
                echo "Removing MicroPython stubs by deleting the virtual environment..." | tee -a "$LOG_FILE"
                # Define the virtual environment directory
                VENV_DIR="$DEMO_PROJECT_DIR/venv"
                if [ -d "$VENV_DIR" ]; then
                    rm -rf "$VENV_DIR"
                    echo "Virtual environment deleted successfully." | tee -a "$LOG_FILE"
                else
                    echo "Virtual environment directory $VENV_DIR does not exist. Skipping." | tee -a "$LOG_FILE"
                fi
            fi
            ;;
        vscode_demo_project_opened)
            # No uninstallation needed for opening VS Code
            ;;
        path_configured)
            if [ "$value" = "true" ]; then
                echo "Removing Homebrew from PATH in ~/.zprofile and ~/.bash_profile..." | tee -a "$LOG_FILE"
                # Remove the specific export lines
                sed -i '' '/export PATH="\/opt\/homebrew\/bin:\$PATH"/d' ~/.zprofile
                sed -i '' '/export PATH="\/opt\/homebrew\/bin:\$PATH"/d' ~/.bash_profile
                echo "Homebrew removed from PATH." | tee -a "$LOG_FILE"
            fi
            ;;
        esptool_installed)
            if [ "$value" = "true" ]; then
                echo "Uninstalling esptool.py..." | tee -a "$LOG_FILE"
                execute_and_log brew uninstall esptool | tee -a "$LOG_FILE"
                echo "esptool.py uninstalled successfully." | tee -a "$LOG_FILE"
            fi
            ;;
        python_installed)
            if [ "$value" = "true" ]; then
                echo "Uninstalling Python 3.10+..." | tee -a "$LOG_FILE"
                execute_and_log brew uninstall python | tee -a "$LOG_FILE"
                echo "Python uninstalled successfully." | tee -a "$LOG_FILE"
            fi
            ;;
        vscode_micropython_installed)
            if [ "$value" = "true" ]; then
                VSCODE_CMD="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
                if command_exists "$VSCODE_CMD"; then
                    echo "Uninstalling MicroPython extension for VS Code..." | tee -a "$LOG_FILE"
                    "$VSCODE_CMD" --uninstall-extension pycom.Pymakr-preview | tee -a "$LOG_FILE"
                    echo "MicroPython extension uninstalled successfully." | tee -a "$LOG_FILE"
                else
                    echo "Visual Studio Code command-line tools not found. Skipping MicroPython extension uninstallation." | tee -a "$LOG_FILE"
                fi
            fi
            ;;
        vscode_python_installed)
            if [ "$value" = "true" ]; then
                VSCODE_CMD="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
                if command_exists "$VSCODE_CMD"; then
                    echo "Uninstalling Python extension for VS Code..." | tee -a "$LOG_FILE"
                    "$VSCODE_CMD" --uninstall-extension ms-python.python | tee -a "$LOG_FILE"
                    echo "Python extension uninstalled successfully." | tee -a "$LOG_FILE"
                else
                    echo "Visual Studio Code command-line tools not found. Skipping Python extension uninstallation." | tee -a "$LOG_FILE"
                fi
            fi
            ;;
        vscode_pymakr_installed)
            if [ "$value" = "true" ]; then
                VSCODE_CMD="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
                if command_exists "$VSCODE_CMD"; then
                    echo "Uninstalling Pymakr - Preview extension for VS Code..." | tee -a "$LOG_FILE"
                    "$VSCODE_CMD" --uninstall-extension pycom.Pymakr-preview | tee -a "$LOG_FILE"
                    echo "Pymakr - Preview extension uninstalled successfully." | tee -a "$LOG_FILE"
                else
                    echo "Visual Studio Code command-line tools not found. Skipping Pymakr - Preview extension uninstallation." | tee -a "$LOG_FILE"
                fi
            fi
            ;;
        vscode_installed)
            if [ "$value" = "true" ]; then
                echo "Uninstalling Visual Studio Code..." | tee -a "$LOG_FILE"
                execute_and_log brew uninstall --cask visual-studio-code | tee -a "$LOG_FILE"
                echo "Visual Studio Code uninstalled successfully." | tee -a "$LOG_FILE"
            fi
            ;;
        homebrew_installed)
            if [ "$value" = "true" ]; then
                echo "Uninstalling Homebrew..." | tee -a "$LOG_FILE"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" | tee -a "$LOG_FILE"
                echo "Homebrew uninstalled successfully." | tee -a "$LOG_FILE"
            fi
            ;;
        *)
            echo "Unknown component '$key' in checklist. Skipping." | tee -a "$LOG_FILE"
            ;;
    esac
done <<< "$reversed_lines"

# 11. Remove Checklist File
echo "Removing checklist file..." | tee -a "$LOG_FILE"
rm -f "$CHECKLIST_FILE"

echo "========================================" | tee -a "$LOG_FILE"
echo "Uninstallation completed at $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

exit 0
