#!/usr/bin/env bash

echo "Current shell: $SHELL"

if [ -z "$BASH_VERSION" ]; then
  echo
  echo "This script must be run with bash."
  echo "Please run:"
  echo "    bash $(basename "$0")"
  echo
  exit 1
fi

# Exit immediately if a command exits with a non-zero status.
set -e

# Trap errors for a friendlier message
trap 'echo "An error occurred. Please check the log file for details." | tee -a "$LOG_FILE"' ERR

# Define log file
LOG_FILE="install.log"

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Define demo project directory within SCRIPT_DIR
DEMO_PROJECT_DIR="$SCRIPT_DIR/db1"

# Define checklist file
CHECKLIST_FILE="$SCRIPT_DIR/install_checklist.txt"

# Initialize the checklist file with all components set to false
cat > "$CHECKLIST_FILE" <<EOL
homebrew_installed=false
vscode_installed=false
vscode_pymakr_installed=false
vscode_python_installed=false
vscode_micropython_installed=false
python_installed=false
esptool_installed=false
path_configured=false
vscode_demo_project_opened=false
micropython_stubs_installed=false
EOL

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
echo "Installation started at $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

# 0. Check if Xcode Command Line Tools are installed
if ! xcode-select -p &>/dev/null; then
    echo "Xcode command line tools not found. Installing them now..." | tee -a "$LOG_FILE"
    xcode-select --install
    echo "Please rerun this script once the Xcode command line tools finish installing." | tee -a "$LOG_FILE"
    exit 1
fi

# Detect Apple Silicon vs. Intel and set BREW_PREFIX accordingly
if [[ "$(uname -m)" == "arm64" ]]; then
    # Apple Silicon
    BREW_PREFIX="/opt/homebrew"
else
    # Intel
    BREW_PREFIX="/usr/local"
fi

# 1. Install Homebrew if not installed
if ! command_exists brew; then
    echo "Homebrew not found. Installing Homebrew..." | tee -a "$LOG_FILE"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" | tee -a "$LOG_FILE"
    echo "Homebrew installed successfully." | tee -a "$LOG_FILE"
    # Mark as installed
    sed -i '' 's/homebrew_installed=false/homebrew_installed=true/' "$CHECKLIST_FILE"
else
    echo "Homebrew is already installed. Updating Homebrew..." | tee -a "$LOG_FILE"
    execute_and_log brew update
    sed -i '' 's/homebrew_installed=false/homebrew_installed=true/' "$CHECKLIST_FILE"
fi

# Ensure Homebrew is in PATH (based on architecture)
export PATH="$BREW_PREFIX/bin:$PATH"

# 2. Install Visual Studio Code
if ! [ -d "/Applications/Visual Studio Code.app" ]; then
    echo "Installing Visual Studio Code..." | tee -a "$LOG_FILE"
    execute_and_log brew install --cask visual-studio-code
    echo "Visual Studio Code installed successfully." | tee -a "$LOG_FILE"
    # Mark as installed
    sed -i '' 's/vscode_installed=false/vscode_installed=true/' "$CHECKLIST_FILE"
else
    echo "Visual Studio Code is already installed." | tee -a "$LOG_FILE"
    sed -i '' 's/vscode_installed=false/vscode_installed=true/' "$CHECKLIST_FILE"
fi

# (Removed the interactive 'Press Enter to continue...' prompt)

# 3. Install "Pymakr - Preview" and Python extensions in VS Code
VSCODE_CMD="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

if command_exists "$VSCODE_CMD"; then
    # Install "Pymakr - Preview" extension if not installed
    if ! "$VSCODE_CMD" --list-extensions | grep -q "pycom.Pymakr-preview"; then
        echo "Installing Pymakr - Preview extension for VS Code..." | tee -a "$LOG_FILE"
        execute_and_log "$VSCODE_CMD" --install-extension pycom.Pymakr-preview
        echo "Pymakr - Preview extension installed successfully." | tee -a "$LOG_FILE"
        # Mark as installed
        sed -i '' 's/vscode_pymakr_installed=false/vscode_pymakr_installed=true/' "$CHECKLIST_FILE"
    else
        echo "Pymakr - Preview extension is already installed." | tee -a "$LOG_FILE"
        sed -i '' 's/vscode_pymakr_installed=false/vscode_pymakr_installed=true/' "$CHECKLIST_FILE"
    fi

    # Install Python extension if not installed
    if ! "$VSCODE_CMD" --list-extensions | grep -q "ms-python.python"; then
        echo "Installing Python extension for VS Code..." | tee -a "$LOG_FILE"
        execute_and_log "$VSCODE_CMD" --install-extension ms-python.python
        echo "Python extension installed successfully." | tee -a "$LOG_FILE"
        # Mark as installed
        sed -i '' 's/vscode_python_installed=false/vscode_python_installed=true/' "$CHECKLIST_FILE"
    else
        echo "Python extension is already installed." | tee -a "$LOG_FILE"
        sed -i '' 's/vscode_python_installed=false/vscode_python_installed=true/' "$CHECKLIST_FILE"
    fi

    # [Suggestion #7 about the MicroPython extension is *not* implemented here]
else
    echo "Visual Studio Code command-line tools not found. Skipping extension installations." | tee -a "$LOG_FILE"
fi

# 4. Install Python 3.10+ if not installed (improved version check)
if command_exists python3; then
    # Use Python itself to check version >= 3.10
    if python3 -c "import sys; exit(0 if sys.version_info >= (3,10) else 1)"; then
        echo "Python $(python3 --version) is already installed and meets the requirement (>=3.10)." | tee -a "$LOG_FILE"
        sed -i '' 's/python_installed=false/python_installed=true/' "$CHECKLIST_FILE"
    else
        echo "Existing Python is lower than 3.10. Installing Python 3.10+..." | tee -a "$LOG_FILE"
        execute_and_log brew install python
        echo "Python installed successfully." | tee -a "$LOG_FILE"
        sed -i '' 's/python_installed=false/python_installed=true/' "$CHECKLIST_FILE"
    fi
else
    echo "Python not found. Installing Python 3.10+..." | tee -a "$LOG_FILE"
    execute_and_log brew install python
    echo "Python installed successfully." | tee -a "$LOG_FILE"
    sed -i '' 's/python_installed=false/python_installed=true/' "$CHECKLIST_FILE"
fi

# 5. Install esptool.py
if ! command_exists esptool.py; then
    echo "Installing esptool.py..." | tee -a "$LOG_FILE"
    execute_and_log brew install esptool
    echo "esptool.py installed successfully." | tee -a "$LOG_FILE"
    sed -i '' 's/esptool_installed=false/esptool_installed=true/' "$CHECKLIST_FILE"
else
    echo "esptool.py is already installed." | tee -a "$LOG_FILE"
    sed -i '' 's/esptool_installed=false/esptool_installed=true/' "$CHECKLIST_FILE"
fi

# 6. Configure Environment (Add Homebrew to PATH if not present)
if ! echo "$PATH" | grep -q "$BREW_PREFIX/bin"; then
    echo "Adding Homebrew to PATH in zprofile and bash_profile..." | tee -a "$LOG_FILE"
    echo "export PATH=\"$BREW_PREFIX/bin:\$PATH\"" >> ~/.zprofile
    echo "export PATH=\"$BREW_PREFIX/bin:\$PATH\"" >> ~/.bash_profile
    sed -i '' 's/path_configured=false/path_configured=true/' "$CHECKLIST_FILE"
else
    echo "Homebrew is already in PATH." | tee -a "$LOG_FILE"
    sed -i '' 's/path_configured=false/path_configured=true/' "$CHECKLIST_FILE"
fi

# 7. Install MicroPython Stubs in a Virtual Environment (unchanged from your script)
VENV_DIR="$DEMO_PROJECT_DIR/venv"
if [ -f "$SCRIPT_DIR/micropython_esp32_stubs-1.21.0.post3.tar" ]; then
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating virtual environment in $VENV_DIR..." | tee -a "$LOG_FILE"
        execute_and_log python3 -m venv "$VENV_DIR"
        echo "Virtual environment created successfully." | tee -a "$LOG_FILE"
    else
        echo "Virtual environment already exists in $VENV_DIR." | tee -a "$LOG_FILE"
    fi

    echo "Installing MicroPython stubs from $SCRIPT_DIR/micropython_esp32_stubs-1.21.0.post3.tar in the virtual environment..." | tee -a "$LOG_FILE"
    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate"
    execute_and_log pip install -U "$SCRIPT_DIR/micropython_esp32_stubs-1.21.0.post3.tar"
    deactivate
    echo "MicroPython stubs installed successfully." | tee -a "$LOG_FILE"
    sed -i '' 's/micropython_stubs_installed=false/micropython_stubs_installed=true/' "$CHECKLIST_FILE"
else
    echo "MicroPython stubs tar file not found. Skipping stubs installation." | tee -a "$LOG_FILE"
fi

# 8. Set Demo Project as Default VS Code Project and Open VS Code
open_vscode_with_demo_project() {
    echo "Opening Visual Studio Code with the demo project..." | tee -a "$LOG_FILE"
    if [ -d "$DEMO_PROJECT_DIR" ]; then
        open -a "/Applications/Visual Studio Code.app" "$DEMO_PROJECT_DIR"
        sed -i '' 's/vscode_demo_project_opened=false/vscode_demo_project_opened=true/' "$CHECKLIST_FILE"
    else
        echo "Demo project directory $DEMO_PROJECT_DIR does not exist. Please create it manually." | tee -a "$LOG_FILE"
    fi
}

open_vscode_with_demo_project

# 9. Final Checks
echo "========================================" | tee -a "$LOG_FILE"
echo "Verifying installations..." | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

echo -n "Python version: " | tee -a "$LOG_FILE"
python3 --version | tee -a "$LOG_FILE"

echo -n "pip version: " | tee -a "$LOG_FILE"
pip3 --version | tee -a "$LOG_FILE"

echo -n "esptool.py version: " | tee -a "$LOG_FILE"
esptool.py version | tee -a "$LOG_FILE"

if command_exists "$VSCODE_CMD"; then
    echo -n "Visual Studio Code version: " | tee -a "$LOG_FILE"
    "$VSCODE_CMD" --version | tee -a "$LOG_FILE"
else
    echo "Visual Studio Code command-line tools not found." | tee -a "$LOG_FILE"
fi

# 9a. Provide a short summary from the checklist
echo "========================================" | tee -a "$LOG_FILE"
echo "Installation Summary (from $CHECKLIST_FILE):" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

while read -r line; do
    key="$(echo "$line" | cut -d '=' -f1)"
    value="$(echo "$line" | cut -d '=' -f2)"
    if [ "$value" = "true" ]; then
        echo "  $key: OK" | tee -a "$LOG_FILE"
    else
        echo "  $key: Not installed or configured" | tee -a "$LOG_FILE"
    fi
done < "$CHECKLIST_FILE"

echo "========================================" | tee -a "$LOG_FILE"
echo "Installation completed at $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

exit 0
