#!/bin/bash
# ==============================================================================
# XyronOS Engine - FULL AUTOMATION
# Architect: OmarAsiri1
# ==============================================================================

# --- 1. WELCOME SCREEN (STAYS UNTIL YOU CLICK) ---
clear
echo -e "\e[1;34m"
echo "  __  ____                      ____   _____ "
echo "  \ \/ / /_  ______  ____  ____/ / /  / ___/ "
echo "   \  / __ \/ ___/ / / / __ \/ __  / /   \__ \  "
echo "   / / / / / /  / /_/ / /_/ / /_/ / /   ___/ /  "
echo "  /_/_/ /_/_/   \__, /\____/\__,_/_/   /____/   "
echo "               /____/  ENGINE v2026.1            "
echo -e "\e[0m"

whiptail --title "XyronOS Architect Suite" --msgbox \
"Welcome, Omar. This is the FULL AUTOMATION Pipeline.

STAGES:
1. Update Host & Install Deps
2. User Selection (DE/Greeter)
3. VM Boot + 1 Minute Wait
4. AUTOMATED Archinstall (No user input needed)
5. Boot into your new GUI" 18 60

# --- 2. HOST UPDATE & DEP INSTALL ---
echo "--- Phase 1: Updating Host System ---"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case $ID in
        arch|manjaro) sudo pacman -Syu --noconfirm qemu-full wget libnewt ;;
        debian|ubuntu|pop) sudo apt update && sudo apt upgrade -y && sudo apt install -y qemu-system-x86 wget whiptail ;;
        fedora) sudo dnf update -y && sudo dnf install -y qemu-system-x86 wget newt ;;
        alpine) apk update && apk upgrade && apk add qemu-system-x86_64 wget newt ;;
    esac
fi

# --- 3. SELECTION ---
DE=$(whiptail --title "Step 1: Desktop" --menu "Select Interface:" 15 60 4 \
"gnome" "GNOME Desktop" "kde" "KDE Plasma" "xfce" "XFCE Desktop" 3>&1 1>&2 2>&3)

GREETER=$(whiptail --title "Step 2: Greeter" --menu "Select Login Manager:" 15 60 3 \
"gdm" "GDM" "sddm" "SDDM" "lightdm" "LightDM" 3>&1 1>&2 2>&3)

# --- 4. PREP WORKSPACE ---
BASE_DIR="$HOME/XyronOS-Engine"
OUT_DIR="$BASE_DIR/ISO_Output"
VM_DISK="$BASE_DIR/build_disk.qcow2"
ISO_BASE="$BASE_DIR/arch_base.iso"
CONFIG_FILE="$OUT_DIR/user_configuration.json"

mkdir -p "$OUT_DIR"
cd "$BASE_DIR" || exit

[ ! -f "$ISO_BASE" ] && wget -O "$ISO_BASE" "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
[ ! -f "$VM_DISK" ] && qemu-img create -f qcow2 "$VM_DISK" 40G

# --- 5. ARCHINSTALL AUTOMATION CONFIG ---
# This generates the JSON needed for archinstall to run without asking questions
cat <<EOF > "$CONFIG_FILE"
{
    "desktop-environment": "$DE",
    "display-manager": "$GREETER",
    "audio": "pipewire",
    "bootloader": "grub-install",
    "drive": "/dev/vda",
    "hostname": "xyronos",
    "kernels": ["linux"],
    "nic": "NetworkManager",
    "storage": {"disk_layouts": [{"device": "/dev/vda", "method": "wipe"}]}
}
EOF

# --- 6. PHASE 3: THE AUTO-BOOT INSTALLER ---
# We use a 1-minute delay script that will be triggered in the VM
cat <<EOF > "$OUT_DIR/start_install.sh"
sleep 60
echo "1 Minute passed. Starting Automated Archinstall..."
archinstall --config /mnt/user_configuration.json --silent
EOF

whiptail --title "Starting" --msgbox "The VM will boot. 
Wait 60 seconds. The installer will start AUTOMATICALLY.
Once it reboots, your $DE GUI will open." 12 60

# First Boot: Automated Installation
# We mount the OUT_DIR as a shared drive so the VM can read the config
qemu-system-x86_64 \
    -m 4G -enable-kvm -cpu host -smp 4 \
    -drive file="$VM_DISK",if=virtio \
    -cdrom "$ISO_BASE" -boot d \
    -net nic -net user \
    -virtfs local,path="$OUT_DIR",mount_tag=hostshare,security_model=none,id=hostshare \
    -device virtio-vga-gl -display gtk,gl=on \
    -name "XyronOS - Auto-Installing (Wait 1m)"

# --- 7. PHASE 4: FINAL GUI BOOT ---
echo "Opening your customized GUI..."
qemu-system-x86_64 \
    -m 4G -enable-kvm -cpu host -smp 4 \
    -drive file="$VM_DISK",if=virtio \
    -net nic -net user \
    -virtfs local,path="$OUT_DIR",mount_tag=hostshare,security_model=none,id=hostshare \
    -device virtio-vga-gl -display gtk,gl=on \
    -name "XyronOS - Customization Window" &

# --- 8. SUCCESS WATCHER ---
while [ ! -f "$OUT_DIR/XyronOS-Final.iso" ]; do sleep 10; done
whiptail --title "Victory" --msgbox "Mission Complete, ISO ready." 10 60
