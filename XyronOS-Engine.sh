#!/bin/bash
# ==============================================================================
# PROJECT: XyronOS Build Engine
# ARCHITECT: $(whoami)
# VERSION:   1.0
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
    
    if [ "$EUID" -eq 0 ]; then 
        echo -e "${RED}[!] Critical: Do not run this engine as root directly.${NC}"
        exit 1
    fi
    
    FREE_SPACE=$(df -k . | awk 'NR==2 {print $4}')
    if [ "$FREE_SPACE" -lt 26214400 ]; then
        echo -e "${RED}[!] Error: Insufficient disk space. Need 25GB+ free.${NC}"
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
    "gnome" "GNOME Desktop (Standard)" \
    "kde" "KDE Plasma (Modern)" \
    "xfce" "XFCE (Lightweight)" \
    "sway" "Sway (Window Manager)" 3>&1 1>&2 2>&3)

    GREETER=$(whiptail --title "XyronOS Architect" --menu "Select Display Manager:" 15 60 3 \
    "gdm" "GDM (Standard for GNOME)" \
    "sddm" "SDDM (Standard for KDE)" \
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
    "locale_config": {"kbd_layout": "us", "sys_lang": "en_US"},
    "nic": "NetworkManager",
    "storage": {"disk_layouts": [{"device": "/dev/vda", "method": "wipe"}]},
    "users": [{"username": "xyron", "password": "123", "is_sudo": true}]
}
EOF

    cat <<EOF > "$OUT_DIR/finalize.sh"
#!/bin/bash
echo ">>> Starting ISO Compilation inside VM..."
sudo pacman -Sy --noconfirm archiso
mkdir -p ~/custom_iso && cp -r /usr/share/archiso/configs/releng/* ~/custom_iso/
echo "$DE" >> ~/custom_iso/packages.x86_64
echo "$GREETER" >> ~/custom_iso/packages.x86_64
cd ~/custom_iso && sudo mkarchiso -v -w /tmp/archiso-work -o /tmp/archiso-out .
sudo mount -t 9p -o trans=virtio hostshare /mnt
sudo cp /tmp/archiso-out/*.iso /mnt/XyronOS-Final-\$(date +%Y%m%d).iso
echo ">>> Success! Final ISO Pushed to Host."
EOF
    chmod +x "$OUT_DIR/finalize.sh"
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
    if [ ! -f "$ISO_BASE" ]; then
        wget -O "$ISO_BASE" "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
    fi
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
    while ! grep -q "archiso login:" "$SERIAL_LOG" 2>/dev/null; do
        sleep 5
        echo -n "."
    done

    echo -e "\n${GREEN}[!] ARCH PROMPT DETECTED! Deploying Ghost Commands...${NC}"
    sleep 8
    vm_type "mount -t 9p -o trans=virtio hostshare /mnt"
    sleep 2
    vm_type "archinstall --config /mnt/user_config.json --silent"
}

# --- [ 10. WRAP-UP & CLEANUP ] ---
wait_for_completion() {
    echo -e "${GOLD}[Phase 3] Awaiting Final ISO Product...${NC}"
    while [ ! -f "$OUT_DIR"/XyronOS-Final-*.iso ]; do
        sleep 15
    done
    
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${GREEN}SUCCESS: XyronOS ISO Build Complete!${NC}"
    echo -e "${GREEN}Developer: $REAL_USER${NC}"
    echo -e "${GREEN}====================================================${NC}"
    
    if (whiptail --title "Disk Cleanup" --yesno "Build finished. Delete temporary disk?" 10 60); then
        rm "$VM_DISK"
        echo -e "${CYAN}[*] Workspace cleaned.${NC}"
    fi
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

# Start the process
run_engine

echo -e "${BLUE}[*] XyronOS Engine Session Closed.${NC}"
# --- [ END OF FILE ] ---
