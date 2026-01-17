#!/bin/bash

# ==============================================================================
# XyronOS Engine - Universal TUI Developer Suite
# Architect: Omar 
# ==============================================================================

# Variables
TITLE="XyronOS Engine 26.0"
WORK_DIR="$HOME/XyronOS_Workspace"
ISO_URL="https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
ISO_FILE="$WORK_DIR/base_arch.iso"

# --- Root Check ---
if [[ $EUID -ne 0 ]]; then
   echo "Error: Please run as root (sudo ./XyronOS-Engine.sh)"
   exit 1
fi

# --- 1. Auto-Dependency Installer ---
install_deps() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        exit 1
    fi

    echo "Checking dependencies for $DISTRO..."
    case $DISTRO in
        arch|manjaro) pacman -Sy --needed wget qemu-full proot libnewt cdrtools --noconfirm ;;
        debian|ubuntu|pop) apt update && apt install -y wget qemu-system-x86 proot whiptail genisoimage ;;
        fedora) dnf install -y wget qemu-system-x86 proot newt genisoimage ;;
        alpine) apk add bash wget qemu-system-x86_64 proot newt cdrkit ;;
    esac
}

# --- 2. TUI Functions ---

fetch_iso() {
    mkdir -p "$WORK_DIR"
    if [ -f "$ISO_FILE" ]; then
        whiptail --title "Download" --yesno "ISO already exists. Redownload?" 8 45 || return
    fi
    
    # Downloading with progress bar
    wget -c "$ISO_URL" -O "$ISO_FILE" 2>&1 | \
    stdbuf -o0 awk '/[0-9]+%/ {print substr($0, index($0, "%")-3, 3)}' | \
    whiptail --title "XyronOS Fetcher" --gauge "Downloading latest Arch ISO..." 8 50 0
    
    whiptail --title "Success" --msgbox "Base ISO fetched successfully to $ISO_FILE" 8 45
}

modify_env() {
    if [ ! -f "$ISO_FILE" ]; then
        whiptail --title "Error" --msgbox "Download the ISO first!" 8 45
        return
    fi
    
    MOD_DIR="$WORK_DIR/Xyron_Mod_Files"
    mkdir -p "$MOD_DIR"
    
    whiptail --title "Proot Shell" --msgbox "Entering proot shell. \n\n1. Edit files in /mnt \n2. Type 'exit' to return." 10 50
    
    # Enter proot
    proot -0 -b "$MOD_DIR:/mnt" /bin/bash
}

debug_iso() {
    if [ ! -f "$ISO_FILE" ]; then
        whiptail --title "Error" --msgbox "ISO file not found!" 8 45
        return
    fi

    RAM=$(whiptail --title "Memory Setup" --inputbox "Enter RAM size (MB):" 8 45 "2048" 3>&1 1>&2 2>&3)
    
    echo "Launching QEMU Debugger..."
    qemu-system-x86_64 \
        -m $RAM \
        -enable-kvm \
        -cpu host \
        -cdrom "$ISO_FILE" \
        -boot d \
        -device virtio-vga-gl -display gtk,gl=on \
        -net nic -net user \
        -name "XyronOS Preview" &
    
    whiptail --title "QEMU" --msgbox "QEMU is running in the background. Check the new window." 8 45
}

# --- 3. Main Loop ---
install_deps
clear

while true; do
    CHOICE=$(whiptail --title "$TITLE" --menu "Select an action to build your XyronOS ISO:" 15 60 4 \
    "1" "Fetch Latest Arch ISO" \
    "2" "Modify Environment (Proot)" \
    "3" "Debug ISO (QEMU GUI)" \
    "4" "Exit" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1) fetch_iso ;;
        2) modify_env ;;
        3) debug_iso ;;
        4) clear; exit ;;
        *) clear; exit ;;
    esac
done
