#!/bin/bash
# ==============================================================================
# XyronOS Engine 
# Architect: OmarAsiri1
# ==============================================================================

# --- 1. THE WELCOME SCREEN ---
clear
echo -e "\e[1;34m"
echo "  __  ____                      ____   _____ "
echo "  \ \/ / /_  ______  ____  ____/ / /  / ___/ "
echo "   \  / __ \/ ___/ / / / __ \/ __  / /   \__ \  "
echo "   / / / / / /  / /_/ / /_/ / /_/ / /   ___/ /  "
echo "  /_/_/ /_/_/   \__, /\____/\__,_/_/   /____/   "
echo "               /____/  ENGINE v2026.1            "
echo -e "\e[0m"

# Detecting Real User Name
REAL_USER=$(whoami)

whiptail --title "XyronOS Architect Suite" --msgbox \
"Welcome, $REAL_USER. 

The engine will now perform a Zero-Touch build:
1. Update Host & Install Deps (QEMU, Expect, etc.)
2. User Selection (DE/Greeter)
3. Boot Arch & Wait for prompt
4. AUTOMATICALLY type installation commands
5. Finalize and Push ISO to $HOME/XyronOS-Engine" 18 60

# --- 2. HOST UPDATE & DEP INSTALL ---
echo "--- Phase 1: Updating Host System for $REAL_USER ---"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case $ID in
        arch|manjaro) sudo pacman -Syu --noconfirm qemu-full wget expect libnewt netcat ;;
        debian|ubuntu|pop) sudo apt update && sudo apt upgrade -y && sudo apt install -y qemu-system-x86 wget expect whiptail netcat-openbsd ;;
        fedora) sudo dnf update -y && sudo dnf install -y qemu-system-x86 wget expect newt nc ;;
    esac
fi

# --- 3. USER SELECTION ---
DE=$(whiptail --title "Selection" --menu "Select Desktop Environment:" 15 60 4 \
"GNOME" "GNOME" "KDE" "KDE Plasma" "xfce" "XFCE" "sway" "Sway" 3>&1 1>&2 2>&3)

GREETER=$(whiptail --title "Selection" --menu "Select Login Greeter:" 15 60 3 \
"gdm" "GDM" "sddm" "SDDM" "lightdm" "LightDM" 3>&1 1>&2 2>&3)

# --- 4. WORKSPACE PREPARATION ---
BASE_DIR="$HOME/XyronOS-Engine"
OUT_DIR="$BASE_DIR/ISO_Output"
VM_DISK="$BASE_DIR/build_disk.qcow2"
ISO_BASE="$BASE_DIR/arch_base.iso"
MONITOR_SOCKET="$BASE_DIR/qemu-monitor.sock"
SERIAL_LOG="$BASE_DIR/vm_serial.log"

mkdir -p "$OUT_DIR"
cd "$BASE_DIR" || exit

echo "--- Phase 2: Preparing Virtual Assets ---"
[ ! -f "$ISO_BASE" ] && wget -O "$ISO_BASE" "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
[ ! -f "$VM_DISK" ] && qemu-img create -f qcow2 "$VM_DISK" 40G

# --- 5. AUTOMATION CONFIGS ---
cat <<EOF > "$OUT_DIR/user_config.json"
{
    "desktop-environment": "$DE",
    "display-manager": "$GREETER",
    "audio": "pipewire",
    "bootloader": "grub-install",
    "drive": "/dev/vda",
    "hostname": "xyronos",
    "nic": "NetworkManager",
    "storage": {"disk_layouts": [{"device": "/dev/vda", "method": "wipe"}]}
}
EOF

# --- 6. PHASE 3: THE AUTO-TYPING ENGINE ---
echo "--- Phase 3: Booting VM & Detecting Prompt ---"
rm -f "$SERIAL_LOG" "$MONITOR_SOCKET"



# Launch QEMU
qemu-system-x86_64 \
    -m 4G -enable-kvm -cpu host -smp 4 \
    -drive file="$VM_DISK",if=virtio \
    -cdrom "$ISO_BASE" -boot d \
    -net nic -net user \
    -virtfs local,path="$OUT_DIR",mount_tag=hostshare,security_model=none,id=hostshare \
    -serial file:"$SERIAL_LOG" \
    -monitor unix:"$MONITOR_SOCKET",server,nowait \
    -device virtio-vga-gl -display gtk,gl=on &

# Function to "Type" into the VM via Monitor
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

# Wait for Arch Prompt
echo "Listening for Archiso shell..."
until grep -q "archiso login:" "$SERIAL_LOG"; do sleep 2; done
echo -e "\n[!] Prompt Detected. Injecting Commands for $REAL_USER..."

sleep 5 
vm_type "mount -t 9p -o trans=virtio hostshare /mnt"
sleep 2
vm_type "archinstall --config /mnt/user_config.json --silent"

# --- 7. THE WATCHER ---
echo "Automated installation in progress. Do not close the QEMU window."
while [ ! -f "$OUT_DIR/XyronOS-Final.iso" ]; do sleep 10; done

whiptail --title "Success" --msgbox "Build Finished, $REAL_USER! 
The ISO is pushed to: $OUT_DIR/XyronOS-Final.iso" 10 60
