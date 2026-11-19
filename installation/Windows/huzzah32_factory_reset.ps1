# FactoryResetHuzzah32.ps1
# This script performs a factory reset on an Adafruit Huzzah32 board.
# It erases all data on the board and flashes it with a specified firmware file.

# Define firmware file variable (update the path if necessary)
$FIRMWARE_FILE = "ESP32_GENERIC-20231005-v1.21.0.bin"

# Check if firmware file exists
if (-Not (Test-Path -Path $FIRMWARE_FILE)) {
    Write-Error "Firmware file '$FIRMWARE_FILE' not found. Please ensure the file is in the script directory or update the FIRMWARE_FILE variable."
    exit 1
}

# Initialize the serial_ports array in script scope
$script:serial_ports = @()

# Function to list available serial ports
function List-SerialPorts {
    Write-Output "`nListing available serial ports:"

    # Fetch all serial ports using Get-CimInstance
    $serialPortsCim = Get-CimInstance Win32_SerialPort

    # Add serial ports from Win32_SerialPort
    foreach ($port in $serialPortsCim) {
        $script:serial_ports += $port.DeviceID
        $index = $script:serial_ports.Count - 1
        Write-Output "$index) $($port.Caption) ($($port.DeviceID))"
    }

    # Include additional virtual COM ports not captured by Win32_SerialPort
    $existingPorts = $serialPortsCim | Select-Object -ExpandProperty DeviceID
    $virtualPorts = [System.IO.Ports.SerialPort]::GetPortNames() | Where-Object { $_ -notin $existingPorts }

    foreach ($vPort in $virtualPorts) {
        $script:serial_ports += $vPort
        $index = $script:serial_ports.Count - 1
        Write-Output "$index) Virtual Serial Port ($vPort)"
    }

    # Debug: Display the count and contents of serial_ports
    #Write-Output "`nDebug: Total serial ports found: $($script:serial_ports.Count)"
    #for ($i = 0; $i -lt $script:serial_ports.Count; $i++) {
    #    Write-Output "Debug: serial_ports[$i] = $($script:serial_ports[$i])"
    #}

    if ($script:serial_ports.Count -eq 0) {
        Write-Error "No serial ports found. Please connect your Huzzah32 board and try again."
        exit 1
    }
}

# Function to select a serial port
function Select-SerialPort {
    while ($true) {
        $port_number = Read-Host "`nSelect the serial port number (or press Enter to cancel)"
        if ([string]::IsNullOrWhiteSpace($port_number)) {
            Write-Output "No serial port selected. Exiting."
            exit 1
        }

        # Validate input is a number
        if ($port_number -match '^\d+$') {
            $port_index = [int]$port_number
            if ($port_index -ge 0 -and $port_index -lt $script:serial_ports.Count) {
                $selectedPort = $script:serial_ports[$port_index]
                Write-Output "Selected serial port: $selectedPort"
                $script:SERIAL_PORT = $selectedPort
                break
            } else {
                Write-Output "Invalid selection. Please enter a number between 0 and $($script:serial_ports.Count - 1)."
            }
        } else {
            Write-Output "Invalid input. Please enter a numeric value."
        }
    }
}

# Function to confirm factory reset
function Confirm-Reset {
    Write-Output "`nWARNING: This script will factory reset the Huzzah32 board. ALL DATA WILL BE ERASED."
    $confirmation = Read-Host "Are you sure you want to proceed? Type 'yes' to confirm (default is no)"
    if ($confirmation -ne "yes") {
        Write-Output "Operation cancelled. Exiting."
        exit 1
    }
}

# Function to perform erase_flash
function Erase-Flash {
    Write-Output "`nErasing flash on $script:SERIAL_PORT..."
    esptool.exe --chip esp32 --port "$script:SERIAL_PORT" erase_flash
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to erase flash. Please check the connection and try again."
        exit 1
    }
    Write-Output "Flash erased successfully."
}

# Function to perform write_flash
function Write-Flash {
    Write-Output "`nFlashing firmware to $script:SERIAL_PORT..."
    esptool.exe --chip esp32 --port "$script:SERIAL_PORT" --baud 921600 write_flash -z 0x1000 "$FIRMWARE_FILE"
    if ($LASTEXITCODE -eq 0) {
        Write-Output "Factory reset complete."
    }
    else {
        Write-Error "Failed to write firmware. Please check the connection and try again."
        exit 1
    }
}

# Main Script Logic
Confirm-Reset
List-SerialPorts
Select-SerialPort
Erase-Flash
Write-Flash
