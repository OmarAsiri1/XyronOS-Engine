#!/bin/bash
# ==============================================================================
# PROJECT: XyronOS Build Engine
# ARCHITECT: $(whoami)
# VERSION: 2026.1.3
# DESCRIPTION: Zero-Touch Arch-based ISO Factory (Fixed Prompt Detection)
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
    if [ "$EUID" -eq 0 ]; then 
        echo -e "${RED}[!] Critical: Do not run this engine as root directly.${NC}"
        exit 1
    fi
    FREE_SPACE=$(df -k . | awk 'NR==2 {print $4}')
    if [ "$FREE_SPACE" -lt 26214400 ]; then
        echo -e "${RED}[!] Error: Insufficient disk space. Need 25GB+ free.${NC}"
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
            arch|manjaro) sudo pacman -Syu --noconfirm qemu-full wget expect netcat edk2-ovmf libnewt ;;
            debian|ubuntu|pop) sudo apt update && sudo apt install -y qemu-system-x86 wget expect netcat-openbsd ovmf whiptail ;;
        esac
    fi
}

# --- [ 6. TUI CONFIGURATION ] ---
get_user_choices() {
    DE=$(whiptail --title "XyronOS Architect" --menu "Select Desktop Environment:" 15 60 4 \
    "gnome" "GNOME Desktop" "kde" "KDE Plasma" "xfce" "XFCE Desktop" "sway" "Sway Manager" 3>&1 1>&2 2>&3)
    GREETER=$(whiptail --title "XyronOS Architect" --menu "Select Display Manager:" 15 60 3 \
    "gdm" "GDM (GNOME)" "sddm" "SDDM (KDE)" "lightdm" "LightDM (Universal)" 3>&1 1>&2 2>&3)
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
    "nic": "NetworkManager",
    "storage": {"disk_layouts": [{"device": "/dev/vda", "method": "wipe"}]},
    "users": [{"username": "xyron", "password": "123", "is_sudo": true}]
}
EOF
}

# --- [ 8. GHOST TYPING ENGINE ] ---
vm_type() {
    local STR=$1
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
        sleep 0.05
    done
    echo "sendkey ret" | nc -U "$MONITOR_SOCKET" -q 0
}

# --- [ 9. VM LAB EXECUTION ] ---
launch_factory() {
    echo -e "${GOLD}[Phase 2] Launching Virtual Laboratory...${NC}"
    [ ! -f "$ISO_BASE" ] && wget -O "$ISO_BASE" "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
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

    echo -e "${CYAN}[*] Monitoring Boot Logs...${NC}"
    # FIXED: Added root prompt detection to the loop
    while ! grep -qE "archiso login:|root@archiso" "$SERIAL_LOG" 2>/dev/null; do
        sleep 3
        echo -n "."
    done

    echo -e "\n${GREEN}[!] PROMPT DETECTED! Deploying Commands...${NC}"
    sleep 10
    vm_type "mount -t 9p -o trans=virtio hostshare /mnt"
    sleep 2
    vm_type "archinstall --config /mnt/user_config.json --silent"
}

# --- [ 10. WRAP-UP ] ---
wait_for_completion() {
    echo -e "${GOLD}[Phase 3] Awaiting Installation Completion...${NC}"
    # In a real run, you would monitor the disk or a 'done' file in OUT_DIR
    whiptail --title "Installation Started" --msgbox "The 'Ghost Typer' has injected the commands. Watch the QEMU window to see archinstall run!" 10 60
}

# --- [ 11. MAIN ENGINE FLOW ] ---
run_engine() {
    check_env
    update_host
    get_user_choices
    prepare_configs
    launch_factory
    wait_for_completion
}

run_engine
echo -e "${BLUE}[*] XyronOS Engine Session Closed.${NC}"
