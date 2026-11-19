#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  echo
  echo "This script must be run with bash."
  echo "Please run:"
  echo "    bash $(basename "$0")"
  echo
  exit 1
fi

# This script performs a factory reset on an Adafruit Huzzah32 board.
# It erases all data on the board and flashes it with a specified firmware file.
# The user is prompted to confirm the operation and select a serial port.
# The firmware file is defined at the top of the script as a variable for easy modification.
# The script uses esptool.py to handle the erase and flash operations.

# Define firmware file variable
FIRMWARE_FILE="ESP32_GENERIC-20231005-v1.21.0.bin"

# Function to list available serial ports
list_serial_ports() {
    echo "Likely serial ports for Huzzah32:" 
    likely_ports=( $(ls /dev/tty.SLAB* /dev/tty.usb* 2>/dev/null) )
    for i in "${!likely_ports[@]}"; do
        echo "$i) ${likely_ports[$i]}"
    done

    echo "Other serial ports:" 
    other_ports=( $(ls /dev/tty.* | grep -vE '/dev/tty\.(SLAB|usb)' 2>/dev/null) )
    for i in "${!other_ports[@]}"; do
        echo "$((i + ${#likely_ports[@]}))) ${other_ports[$i]}"
    done

    serial_ports=( "${likely_ports[@]}" "${other_ports[@]}" )
}

# Function to select a serial port
select_serial_port() {
    while true; do
        read -p "Select the serial port number (or press Enter to cancel): " port_number
        if [[ -z "$port_number" ]]; then
            echo "No serial port selected. Exiting."
            exit 1
        elif [[ "$port_number" =~ ^[0-9]+$ ]] && (( port_number >= 0 && port_number < ${#serial_ports[@]} )); then
            echo "Selected serial port: ${serial_ports[$port_number]}"
            SERIAL_PORT="${serial_ports[$port_number]}"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

# Function to confirm factory reset
confirm_reset() {
    echo "This script will factory reset the Huzzah32 board. ALL DATA WILL BE ERASED."
    read -p "Are you sure you want to proceed? Type 'yes' to confirm (default is no): " confirmation
    if [[ "$confirmation" != "yes" ]]; then
        echo "Operation cancelled. Exiting."
        exit 1
    fi
}

# Main script logic
confirm_reset
list_serial_ports
select_serial_port

# Perform factory reset
esptool.py --chip esp32 --port "$SERIAL_PORT" erase_flash
if [[ $? -ne 0 ]]; then
    echo "Failed to erase flash. Exiting."
    exit 1
fi

esptool.py --chip esp32 --port "$SERIAL_PORT" --baud 921600 write_flash -z 0x1000 "$FIRMWARE_FILE"
if [[ $? -eq 0 ]]; then
    echo "Factory reset complete."
else
    echo "Failed to write firmware. Exiting."
    exit 1
fi
