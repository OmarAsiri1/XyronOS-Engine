#!/bin/bash
# ==============================================================================
# PROJECT: XyronOS Build Engine
# ARCHITECT: OmarAsiri1
# VERSION: 1.0
# DESCRIPTION: Zero-Touch Arch-based ISO Factory (Full Orchestration)
# ==============================================================================

# --- [ 1. COLOR DEFINITIONS ] ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GOLD='\033[0;33m'
NC='\033[0m' # No Color

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
    echo -e "               FULL ARCHITECT ENGINE v2026.1${NC}\n"
}

# --- [ 3. PRE-FLIGHT SYSTEM CHECKS ] ---
check_env() {
    echo -e "${CYAN}[*] Performing Pre-Flight Checks...${NC}"
    
    if [ "$EUID" -eq 0 ]; then 
        echo -e "${RED}[!] Critical: Do not run this engine as root. It handles sudo internally.${NC}"
        exit 1
    fi
    
    FREE_SPACE=$(df -k . | awk 'NR==2 {print $4}')
    if [ "$FREE_SPACE" -lt 26214400 ]; then
        echo -e "${RED}[!] Error: Insufficient disk space. Need at least 25GB.${NC}"
        exit 1
    fi
    
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
                sudo apt update && sudo apt install -y qemu-system-x86 wget expect netcat-openbsd ovmf whiptail ;;
            fedora) 
                sudo dnf update -y && sudo dnf install -y qemu-system-x86 wget expect nc edk2-ovmf newt ;;
        esac
    fi
}

# --- [ 6. TUI CONFIGURATION ] ---
get_user_choices() {
    DE=$(whiptail --title "XyronOS Architect" --menu "Select Desktop Environment:" 15 60 4 \
    "gnome" "GNOME Desktop (Professional)" \
    "kde" "KDE Plasma (Modern)" \
    "xfce" "XFCE (Fast/Light)" \
    "sway" "Sway (Tiling WM)" 3>&1 1>&2 2>&3)

    GREETER=$(whiptail --title "XyronOS Architect" --menu "Select Display Manager:" 15 60 3 \
    "gdm" "GDM (GNOME Recommended)" \
    "sddm" "SDDM (KDE Recommended)" \
    "lightdm" "LightDM (Universal)" 3>&1 1>&2 2>&3)
}

# --- [ 7. BLUEPRINT GENERATION ] ---
prepare_configs() {
    echo -e "${CYAN}[*] Generating Virtual Blueprints...${NC}"
    mkdir -p "$OUT_DIR"
    touch "$SERIAL_LOG"

    cat <<EOF > "$OUT_DIR/user_config.json"
{
    "audio": "pipewire",
    "bootloader": "grub-install",
    "desktop-environment": "$DE",
    "display-manager": "$GREETER",
    "hostname": "XyronOS-Dev",
    "kernels": ["linux"],
    "nic": "NetworkManager",
    "storage": {"disk_layouts": [{"device": "/dev/vda", "method": "wipe"}]},
    "users": [{"username": "xyron", "password": "123", "is_sudo": true}]
}
EOF
}

# --- [ 8. GHOST TYPING ENGINE ] ---
vm_type() {
    local STR=$1
    echo -e "${GOLD}[*] Injecting: $STR${NC}"
    for (( i=0; i<${#STR}; i++ )); do
        char="${STR:$i:1}"
        case "$char" in
            " ") char="spc" ;;
            "-") char="minus" ;;
            ".") char="dot" ;;
            "/") char="slash" ;;
            "_") char="shift-minus" ;;
        esac
        echo "sendkey $char" | nc -U "$MONITOR_SOCKET" -q 0
        sleep 0.1
    done
    echo "sendkey ret" | nc -U "$MONITOR_SOCKET" -q 0
}

# --- [ 9. VM LAB EXECUTION ] ---
launch_factory() {
    echo -e "${GOLD}[Phase 2] Launching Virtual Laboratory...${NC}"
    [ ! -f "$ISO_BASE" ] && wget -O "$ISO_BASE" "https://mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"
    [ ! -f "$VM_DISK" ] && qemu-img create -f qcow2 "$VM_DISK" 40G

    rm -f "$MONITOR_SOCKET" "$SERIAL_LOG"
    touch "$SERIAL_LOG"

    qemu-system-x86_64 \
        -m 4G -enable-kvm -cpu host -smp 4 \
        -drive file="$VM_DISK",if=virtio \
        -cdrom "$ISO_BASE" -boot d \
        -net nic -net user \
        -virtfs local,path="$OUT_DIR",mount_tag=hostshare,security_model=none,id=hostshare \
        -serial file:"$SERIAL_LOG" \
        -monitor unix:"$MONITOR_SOCKET",server,nowait \
        -vga virtio -display gtk &

    echo -e "${CYAN}[*] Monitoring Boot Logs (60s Safety Timeout)...${NC}"
    TIMER=0
    until grep -aqE "root@archiso|archiso login" "$SERIAL_LOG" || [ $TIMER -gt 60 ]; do
        sleep 2
        echo -n "."
        ((TIMER+=2))
    done

    echo -e "\n${GREEN}[!] PROMPT READY! Deploying Ghost Commands...${NC}"
    sleep 15
    vm_type "mount -t 9p -o trans=virtio hostshare /mnt"
    sleep 3
    vm_type "archinstall --config /mnt/
