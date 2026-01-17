#!/bin/bash
# ==============================================================================
# PROJECT: XyronOS Build Engine
# ARCHITECT: $(whoami)
# VERSION: 1.0
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
                sudo apt update && sudo apt upgrade -y && sudo apt install -y qemu-system-x86 wget expect netcat-openbsd ovmf whiptail ;;
            fedora) 
                sudo dnf update -y && sudo dnf install -y qemu-system-x86 wget expect nc edk2-ovmf newt ;;
        esac
    fi
}

# --- [ 6. TUI CONFIGURATION ] ---
get_user_choices() {
    DE=$(whiptail --title "XyronOS Architect" --menu "Select Desktop Environment:" 15 60 4 \
    "gnome" "GNOME Desktop" \
    "kde" "KDE Plasma" \
    "xfce" "XFCE Desktop" \
    "sway" "Sway Manager" 3>&1 1>&2 2>&3)

    GREETER=$(whiptail --title "XyronOS Architect" --menu "Select Display Manager:" 15 60 3 \
    "gdm" "GDM (GNOME)" \
    "sddm" "SDDM (KDE)" \
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
echo ">>> Starting Final ISO Compilation inside VM..."
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
    if [ ! -f "$ISO_BASE"
