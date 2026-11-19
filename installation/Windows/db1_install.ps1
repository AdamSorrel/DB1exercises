<#
.SYNOPSIS
    Installs necessary tools on Windows with enhanced error handling and logging.

.DESCRIPTION
    1. Initializes an install checklist.
    2. Installs Visual Studio Code (via winget).
    3. Installs Python 3.10+ (via winget).
    4. Installs esptool (via pip) within a virtual environment.
    5. Installs VS Code extensions: Pymakr (Preview) and Python.
    6. Creates a demo project directory and virtual environment.
    7. Installs MicroPython stubs into the virtual environment.
    8. Opens VS Code with the demo project.
    9. Provides a final summary of installations.

.NOTES
    - Run this script in PowerShell **as Administrator** for winget installs to work smoothly.
    - Ensure `micropython_esp32_stubs-1.21.0.post3.tar` is in the same directory as the script if you want to install stubs.
#>

# Enable strict mode and set error preferences
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'  # Continue on non-terminating errors

# Define paths and files
$ScriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogFile        = Join-Path $ScriptDir 'install_windows.log'
$ProjectDir     = Join-Path $ScriptDir 'db1'
$StubsTar       = Join-Path $ScriptDir 'micropython_esp32_stubs-1.21.0.post3.tar'
$ChecklistFile  = Join-Path $ScriptDir 'install_checklist.txt'

# Clean up any previous temporary logs
Remove-Item "temp_output.log", "temp_error.log" -ErrorAction SilentlyContinue

# Set output encoding to UTF8 to handle any special characters in logs
$OutputEncoding = [System.Text.Encoding]::UTF8

# Initialize the log file
Set-Content -Path $LogFile -Value "" -Encoding UTF8

# Initialize the checklist file with all components set to false
$checklistContent = @"
vscode_installed=false
vscode_pymakr_installed=false
vscode_python_installed=false
python_installed=false
esptool_installed=false
path_configured=true  # winget typically handles PATH, set to true by default
micropython_stubs_installed=false
demo_project_created=false
"@

# Write the checklist file
Set-Content -Path $ChecklistFile -Value $checklistContent -Encoding UTF8

# A helper function to log messages to both console and a log file
function Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $formattedMessage = "[$timestamp] $message"
    Write-Output $formattedMessage
    $formattedMessage | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

# A helper to run commands, log them, and log warnings instead of stopping
function Execute-AndLog($command) {
    Log "Executing: $command"
    try {
        # Start the process and capture both stdout and stderr
        Start-Process -FilePath "powershell.exe" `
                      -ArgumentList "-NoProfile -Command $command" `
                      -NoNewWindow `
                      -RedirectStandardOutput "temp_output.log" `
                      -RedirectStandardError "temp_error.log" `
                      -Wait -PassThru | Out-Null
        # Read the outputs with proper encoding
        if (Test-Path "temp_output.log") {
            $output = Get-Content -Path "temp_output.log" -Encoding UTF8
            if ($output) {
                $output | Out-File -FilePath $LogFile -Append -Encoding UTF8
            }
        }
        if (Test-Path "temp_error.log") {
            $errorOutput = Get-Content -Path "temp_error.log" -Encoding UTF8
            if ($errorOutput) {
                Log "Warning: $errorOutput"
            }
        }
        # Clean up temporary files
        Remove-Item "temp_output.log", "temp_error.log" -ErrorAction SilentlyContinue
    } catch {
        Log "Warning: Failed to execute '$command'. Error: $_"
        # Do not throw; continue execution
    }
}

# Function to update the checklist file
function Update-Checklist($key) {
    if (Test-Path $ChecklistFile) {
        (Get-Content -Path $ChecklistFile) -replace "^$key=false$", "$key=true" | Set-Content -Path $ChecklistFile -Encoding UTF8
    }
}

# Function to create .vscode/settings.json with the Python interpreter path
function Configure-VSCodeSettings($projectDir, $venvPath) {
    $vscodeDir = Join-Path $projectDir '.vscode'
    if (-not (Test-Path $vscodeDir)) {
        New-Item -ItemType Directory -Path $vscodeDir | Out-Null
        Log "Created .vscode directory."
    }

    $settingsFile = Join-Path $vscodeDir 'settings.json'
    $pythonInterpreter = Join-Path $venvPath 'Scripts\python.exe'

    # Initialize an empty hashtable for settings
    $settings = @{}

    # If the file exists, load the existing settings
    if (Test-Path $settingsFile) {
        try {
            $settings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
        } catch {
            Log "Warning: Failed to parse existing settings.json. Starting with a new file."
            $settings = @{}
        }
    }

    # Update or add the python.pythonPath key
    $settings["python.pythonPath"] = $pythonInterpreter

    # Convert the updated settings back to JSON
    $updatedSettings = $settings | ConvertTo-Json -Depth 3 -Compress

    # Write the updated settings back to the file
    Set-Content -Path $settingsFile -Value $updatedSettings -Encoding UTF8
    Log "Configured VS Code settings to use Python interpreter at '$pythonInterpreter'."
}

# Trap errors for a friendlier message
trap {
    Log "An unexpected error occurred: $_"
    Log "Please check install_windows.log for details."
    # Continue execution
}

Log "========================================"
Log "Windows Installation started at $(Get-Date)"
Log "========================================"

# 1. Install Visual Studio Code
# Check if VSCode is installed by looking for 'code.exe' in PATH
$vsCodePath = Get-Command code -ErrorAction SilentlyContinue
if (-not $vsCodePath) {
    Log "Visual Studio Code not found. Installing via winget..."
    Execute-AndLog "winget install --id Microsoft.VisualStudioCode --exact --accept-source-agreements --accept-package-agreements"
    Log "Visual Studio Code installation attempted."
    Update-Checklist "vscode_installed"
} else {
    Log "Visual Studio Code is already installed at '$($vsCodePath.Source)'."
    Update-Checklist "vscode_installed"
}

# 2. Install Python 3.10+ via winget if needed
function Test-PythonVersion {
    param([string]$minVersion = "3.10")

    try {
        $pyVersion = (python --version 2>&1).Split()[1]  # e.g., "3.10.11"
        $installed = [Version]$pyVersion
        $required  = [Version]$minVersion
        return ($installed -ge $required)
    } catch {
        return $false
    }
}

if (Test-PythonVersion) {
    Log "A compatible version of Python (>=3.10) is already installed."
    Update-Checklist "python_installed"
} else {
    Log "Installing Python 3.10 or higher via winget..."
    Execute-AndLog "winget install --id Python.Python.3.10 --exact --accept-source-agreements --accept-package-agreements"
    Log "Python installation attempted."
    Update-Checklist "python_installed"

    # Refresh the PATH environment variable in the current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + `
                [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    Log "Refreshed PATH environment variable."

    # Verify Python is now accessible
    if (Test-PythonVersion) {
        Log "Python version $(python --version) is now accessible."
    } else {
        Log "Warning: Python was installed but is not accessible. Please ensure Python is added to PATH."
    }
}

# 3. Install esptool
Log "Installing/updating esptool via pip..."
# Define virtual environment path
$venvPath = Join-Path $ProjectDir 'venv'
$pipPath = Join-Path $venvPath 'Scripts\pip.exe'

if (-not (Test-Path $pipPath)) {
    Log "pip executable not found at $pipPath. Attempting to install pip within the virtual environment..."
    # Create the virtual environment if it doesn't exist
    if (-not (Test-Path $venvPath)) {
        Log "Virtual environment not found. Creating virtual environment..."
        Execute-AndLog "python -m venv `"$venvPath`""
        Log "Virtual environment '$venvPath' creation attempted."
    }
    # Ensure pip is installed within the venv
    Execute-AndLog "`"$venvPath\Scripts\python.exe`" -m ensurepip --upgrade"
    Execute-AndLog "`"$venvPath\Scripts\python.exe`" -m pip install --upgrade pip"
    Execute-AndLog "`"$venvPath\Scripts\python.exe`" -m pip install --upgrade esptool"
} else {
    Execute-AndLog "`"$pipPath`" install --upgrade pip"
    Execute-AndLog "`"$pipPath`" install --upgrade esptool"
}
Log "esptool installation/upgradation attempted."
Update-Checklist "esptool_installed"

# 4. Install VS Code Extensions: Pymakr (Preview) and Python
function Install-VSCodeExtension([string]$extensionId) {
    $extensions = code --list-extensions
    if ($extensions -notcontains $extensionId) {
        Log "Installing VS Code extension: $extensionId ..."
        Execute-AndLog "code --install-extension $extensionId"
        Log "Extension '$extensionId' installation attempted."
        if ($extensionId -eq "pycom.Pymakr-preview") {
            Update-Checklist "vscode_pymakr_installed"
        } elseif ($extensionId -eq "ms-python.python") {
            Update-Checklist "vscode_python_installed"
        }
    } else {
        Log "Extension '$extensionId' is already installed."
        Update-Checklist "vscode_pymakr_installed"
        Update-Checklist "vscode_python_installed"
    }
}

$codeCmd = Get-Command code -ErrorAction SilentlyContinue
if ($codeCmd) {
    Install-VSCodeExtension -extensionId "pycom.Pymakr-preview"  # Pymakr - Preview
    Install-VSCodeExtension -extensionId "ms-python.python"       # Python

    # If you also want to disable Pylance or another extension, add similar logic here
    # Example to disable Pylance:
    # if ($extensions -contains 'ms-python.vscode-pylance') {
    #     Log "Disabling Pylance extension for VS Code..."
    #     Execute-AndLog "code --disable-extension ms-python.vscode-pylance"
    #     Log "Pylance extension disabled."
    # }
} else {
    Log "VSCode command line not found. Skipping extension installations."
}

# 5. (Optional) Set up a demo project, create a venv, install MicroPython stubs
if (-not (Test-Path $ProjectDir)) {
    Log "Creating demo project directory: $ProjectDir"
    Execute-AndLog "New-Item -ItemType Directory -Path `"$ProjectDir`" | Out-Null"
    Update-Checklist "demo_project_created"
} else {
    Log "Demo project directory already exists: $ProjectDir"
    Update-Checklist "demo_project_created"
}

# Place a virtual environment inside the project directory:
$venvName = 'venv'
$venvPath = Join-Path $ProjectDir $venvName
if (-not (Test-Path $venvPath)) {
    Log "Creating virtual environment at $venvPath ..."
    Execute-AndLog "python -m venv `"$venvPath`""
    Log "Virtual environment '$venvName' creation attempted."
} else {
    Log "Virtual environment already exists: $venvPath"
}

# If you have the micropython stubs .tar in the same directory, install them
if (Test-Path $StubsTar) {
    Log "Installing MicroPython stubs ($StubsTar) into the virtual environment..."
    # Use the pip executable directly from the virtual environment
    $pipVenvPath = Join-Path $venvPath 'Scripts\pip.exe'
    if (-not (Test-Path $pipVenvPath)) {
        Log "pip executable not found at $pipVenvPath. Attempting to install pip within the virtual environment..."
        Execute-AndLog "`"$venvPath\Scripts\python.exe`" -m ensurepip --upgrade"
    }
    Execute-AndLog "`"$pipVenvPath`" install --upgrade pip"
    Execute-AndLog "`"$pipVenvPath`" install `"$StubsTar`""
    Log "MicroPython stubs installation attempted."
    Update-Checklist "micropython_stubs_installed"

    # Configure VS Code to use the virtual environment's Python interpreter
    #Configure-VSCodeSettings -projectDir $ProjectDir -venvPath $venvPath
} else {
    Log "MicroPython stubs file not found at $StubsTar. Skipping stubs installation."
}

# 6. Open VS Code with the demo project (optional)
if (Test-Path $ProjectDir) {
    Log "Opening Visual Studio Code with the demo project..."
    Start-Process "code" -ArgumentList "`"$ProjectDir`""
} else {
    Log "Demo project directory $ProjectDir does not exist."
}

# 7. Final checks and summary
Log "========================================"
Log "Verifying final installations..."
Log "========================================"

# Updating path_configured since it is not getting resolved anywhere
Update-Checklist "path_configured"
# Function to display checklist summary
function Display-Summary($checklistPath) {
    Log "Installation Summary (from $checklistPath):"
    Log "----------------------------------------"
    Get-Content -Path $checklistPath | ForEach-Object {
        $parts = $_ -split '='
        if ($parts.Count -eq 2) {
            $key = $parts[0].Trim()
            $value = $parts[1].Trim().ToLower()
            if ($value -eq "true") {
                $status = "OK"
            } else {
                $status = "Not installed or configured"
            }
            # Format the key for readability
            $readableKey = switch ($key) {
                "vscode_installed"            { "Visual Studio Code" }
                "vscode_pymakr_installed"     { "Pymakr - Preview Extension" }
                "vscode_python_installed"      { "Python Extension for VS Code" }
                "python_installed"             { "Python 3.10+" }
                "esptool_installed"            { "esptool.py" }
                "path_configured"              { "PATH Environment Variable" }
                "micropython_stubs_installed"  { "MicroPython Stubs" }
                "demo_project_created"         { "Demo Project Directory" }
                default                        { $key }
            }
            Log "  ${readableKey}: $status"
        }
    }
    Log "----------------------------------------"
}

# Display Python version
try {
    $pythonVersion = python --version 2>&1
    Log "Python version: $pythonVersion"
} catch {
    Log "Python not found or not working. Please check."
}

# Display pip version from the virtual environment
try {
    $pipVenvPath = Join-Path $venvPath 'Scripts\pip.exe'
    if (Test-Path $pipVenvPath) {
        $pipVersion = & $pipVenvPath --version
        Log "pip version: $pipVersion"
    } else {
        Log "pip executable not found in the virtual environment."
    }
} catch {
    Log "pip not found or not working within the virtual environment. Please check."
}

# Display esptool version
try {
    $esptoolVer = & $venvPath\Scripts\esptool.exe version 2>&1
    Log "esptool.py version: $esptoolVer"
} catch {
    Log "esptool.py not found or not working. Please check."
}

# Display VSCode version
try {
    $vsCodeVer = code --version
    Log "VSCode version: $vsCodeVer"
} catch {
    Log "VSCode command line not found."
}

# Display the checklist summary
Display-Summary $ChecklistFile

Log "========================================"
Log "Installation completed at $(Get-Date)"
Log "========================================"
