<#
.SYNOPSIS
    Uninstalls the tools and configurations installed by the WindowsInstall.ps1 script with enhanced error handling and logging.

.DESCRIPTION
    1. Reads the install_checklist.txt to determine which components were installed.
    2. Uninstalls VS Code extensions: Pymakr (Preview) and Python.
    3. Uninstalls esptool via pip from the virtual environment.
    4. Uninstalls Python 3.10+ via winget.
    5. Uninstalls Visual Studio Code via winget.
    6. Deletes the project directory and virtual environment.
    7. Logs all actions and errors to uninstall_windows.log.

.NOTES
    - Run this script in PowerShell **as Administrator** to ensure all uninstallations complete successfully.
    - Ensure that `install_checklist.txt` is present in the same directory as this script.
#>

# Enable strict mode and set error preferences
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'  # Continue on non-terminating errors

# Define paths and files
$ScriptDir         = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogFile           = Join-Path $ScriptDir 'uninstall_windows.log'
$ChecklistFile     = Join-Path $ScriptDir 'install_checklist.txt'

# Clean up any previous temporary logs
Remove-Item "temp_output.log", "temp_error.log" -ErrorAction SilentlyContinue

# Set output encoding to UTF8 to handle any special characters in logs
$OutputEncoding = [System.Text.Encoding]::UTF8

# Initialize the log file
Set-Content -Path $LogFile -Value "" -Encoding UTF8

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

# Function to read the checklist and return a hashtable of installed components
function Get-InstalledComponents($checklistPath) {
    $components = @{}
    if (Test-Path $checklistPath) {
        Get-Content -Path $checklistPath | ForEach-Object {
            $parts = $_ -split '='
            if ($parts.Count -eq 2) {
                $key = $parts[0].Trim()
                $value = $parts[1].Trim().ToLower()
                $components[$key] = $value
            }
        }
    } else {
        Log "Checklist file not found at $checklistPath. Exiting uninstall script."
        exit 1
    }
    return $components
}

# Function to uninstall VS Code extensions
function Uninstall-VSCodeExtension([string]$extensionId) {
    $extensions = code --list-extensions
    if ($extensions -contains $extensionId) {
        Log "Uninstalling VS Code extension: $extensionId ..."
        Execute-AndLog "code --uninstall-extension $extensionId"
        Log "Extension '$extensionId' uninstallation attempted."
    } else {
        Log "Extension '$extensionId' is not installed. Skipping."
    }
}

# Function to uninstall pip packages from virtual environment
function Uninstall-PipPackage($pipPath, $packageName) {
    if (Test-Path $pipPath) {
        Log "Uninstalling $packageName via pip..."
        Execute-AndLog "`"$pipPath`" uninstall -y $packageName"
        Log "$packageName uninstallation attempted."
    } else {
        Log "pip executable not found at $pipPath. Cannot uninstall $packageName."
    }
}

# Function to uninstall Python via winget
function Uninstall-Python {
    Log "Uninstalling Python via winget..."
    Execute-AndLog "winget uninstall --id Python.Python.3.10 --exact --silent"
    Log "Python uninstallation attempted."
}

# Function to uninstall Visual Studio Code via winget
function Uninstall-VSCode {
    Log "Uninstalling Visual Studio Code via winget..."
    Execute-AndLog "winget uninstall --id Microsoft.VisualStudioCode --exact --silent"
    Log "Visual Studio Code uninstallation attempted."
}

# Function to delete the project directory
function Delete-ProjectDirectory($projectDir) {
   if (Test-Path $projectDir) {
        Log "Deleting project directory: $projectDir ..."
        Execute-AndLog "Remove-Item -Path `"$projectDir`" -Recurse -Force"
        Log "Project directory deletion attempted."
    } else {
        Log "Project directory $projectDir does not exist. Skipping deletion."
    }
}

# Main Uninstallation Process
try {
    Log "========================================"
    Log "Windows Uninstallation started at $(Get-Date)"
    Log "========================================"

    # Get the installed components from the checklist
    $installedComponents = Get-InstalledComponents -checklistPath $ChecklistFile

    # Define project directory based on the installation script
    $ProjectDir = Join-Path $ScriptDir 'db1'
    $venvPath = Join-Path $ProjectDir 'venv'
    $pipPath = Join-Path $venvPath 'Scripts\pip.exe'

    # 1. Uninstall VS Code Extensions
    if ($installedComponents.ContainsKey('vscode_pymakr_installed') -and $installedComponents['vscode_pymakr_installed'] -eq 'true') {
        Uninstall-VSCodeExtension -extensionId "pycom.Pymakr-preview"
    }

    if ($installedComponents.ContainsKey('vscode_python_installed') -and $installedComponents['vscode_python_installed'] -eq 'true') {
        Uninstall-VSCodeExtension -extensionId "ms-python.python"
    }

    # 2. Uninstall esptool via pip
    if ($installedComponents.ContainsKey('esptool_installed') -and $installedComponents['esptool_installed'] -eq 'true') {
        Uninstall-PipPackage -pipPath $pipPath -packageName "esptool"
    }

    # 3. Uninstall Python via winget
    if ($installedComponents.ContainsKey('python_installed') -and $installedComponents['python_installed'] -eq 'true') {
        Uninstall-Python
    }

    # 4. Uninstall Visual Studio Code via winget
    if ($installedComponents.ContainsKey('vscode_installed') -and $installedComponents['vscode_installed'] -eq 'true') {
        Uninstall-VSCode
    }

    # 5. Delete the virtual environment
    # Function to remove the virtual environment only
    function Remove-Venv {
        param ([string]$venvPath)

        if (Test-Path $venvPath) {
            try {
                Remove-Item -Path $venvPath -Recurse -Force
                Log "Deleted virtual environment: $venvPath"
            } catch {
                Log "Warning: Failed to delete virtual environment at $venvPath. Error: $_"
            }
        } else {
            Log "Virtual environment not found: $venvPath"
        }
    }

    # Define the path to the virtual environment
    $venvPath = Join-Path $ProjectDir 'venv'

    # Always remove the virtual environment, but do not touch the project directory
    Remove-Venv -venvPath $venvPath

    # 6. Optionally, remove the install_checklist.txt and uninstall script log
    # Uncomment the following lines if you wish to delete these files after uninstallation
    # Log "Deleting installation checklist file..."
    # Execute-AndLog "Remove-Item -Path `"$ChecklistFile`" -Force"
    # Log "Deleting uninstall log file..."
    # Execute-AndLog "Remove-Item -Path `"$LogFile`" -Force"

    Log "========================================"
    Log "Uninstallation process completed at $(Get-Date)"
    Log "========================================"

} catch {
    Log "An unexpected error occurred during uninstallation: $_"
    Log "Please check uninstall_windows.log for details."
    # Continue execution
}
