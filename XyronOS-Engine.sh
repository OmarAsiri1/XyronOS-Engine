#!/bin/bash
# ==============================================================================
# PROJECT: XyronOS Build Engine
# ARCHITECT: $(whoami)
# VERSION: 2026.1.1
# DESCRIPTION: Zero-Touch Arch-based ISO Factory (Full Automation)
# ==============================================================================

# --- [ 1. COLOR DEFINITIONS ] ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GOLD='\033[0;33m'
NC='\033[0m'

# --- [ 2. BRANDING BANNER ] ---
show_banner() {
    clear
    echo -e "${BLUE}"
    echo "  ██╗  ██╗██╗   ██╗██████╗  ██████╗ ███╗   ██╗ ██████╗ ███████╗"
    echo "  ╚██╗██╔╝╚██╗ ██╔╝██╔══██╗██╔═══██╗████╗  ██║██╔═══██╗██╔════╝"
    echo "   ╚███╔╝  ╚████╔╝ ██████╔╝██║   ██║██╔██╗ ██║██║   ██║███████╗"
    echo "   ██╔██╗   ╚██╔╝  ██╔══██╗██║   ██║██║╚██╗██║██║   ██║╚════██║"
    echo "  ██╔╝ ██╗   ██║   ██║  ██║╚██████╔╝██║ ╚████║╚██████╔╝███████║"
    echo "  ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝"
    echo -e "               SYSTEM ARCHITECT ENGINE v2026.1${NC}\n"
}

# --- [ 3. PRE-FLIGHT SYSTEM CHECKS ] ---
check_env() {
    echo -e "${CYAN}[*] Performing Pre-Flight Checks...${NC}"
    
    # Root check
    if [ "$EUID" -eq 0 ]; then 
        echo -e "${RED}[!] Critical: Do not run this engine as root directly.${NC}"
        exit 1
    fi
    
    # Disk space check
    FREE_SPACE=$(df -k . | awk 'NR==2 {print $4}')
    if [ "$FREE_SPACE" -lt 26214400 ]; then
        echo -e "${RED}[!] Error: Insufficient disk space. Need 25GB+ free.${NC}"
        exit 1
    fi
    
    # Network check
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        echo -e "${RED}[!] Error: No internet connection detected.${NC}"
        exit 1
    fi
}

# --- [ 4. GLOBAL PATHS ] ---
REAL_USER=$(whoami)
BASE_DIR="$HOME/XyronOS-Engine"
OUT_DIR="$BASE_DIR/ISO_Output"
VM_DISK="$BASE_DIR/build_disk.qcow2"
ISO_BASE="$BASE_DIR/arch_base.iso"
MONITOR_SOCKET="$BASE_DIR/qemu-monitor.sock"
SERIAL_LOG="$BASE_DIR/vm_serial.log"

# --- [ 5. HOST ORCHESTRATION ] ---
update_host() {
    show_banner
    echo -e "${GOLD}[Phase 1] Orchestrating Host Environment...${NC}"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            arch|manjaro) 
                sudo pacman -Syu --noconfirm qemu-full wget expect netcat edk2-ovmf libnewt ;;
            debian|ubuntu|pop) 
                sudo apt update && sudo apt upgrade -y && sudo apt install -y qemu-system-x86 wget expect netcat-openbsd ovmf whiptail ;;
            fedora) 
                sudo dnf update -y && sudo dnf install -y qemu-system-x86 wget expect nc edk2-ovmf newt ;;
        esac
    fi
}

# --- [ 6. TUI CONFIGURATION ] ---
get_user_choices() {
    DE=$(whiptail --title "XyronOS Architect" --menu "Select Desktop Environment:" 15 60 4 \
    "gnome" "GNOME Desktop (Standard)" \
    "kde
