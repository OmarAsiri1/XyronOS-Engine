#!/bin/bash
# ==============================================================================
# XyronOS Engine - THE COMPLETE AUTOMATED ARCHITECT SUITE
# Version: 2026.1 | Architect: $(whoami)
# ==============================================================================

# --- 1. BRANDING & WELCOME (PERSISTENT) ---
clear
echo -e "\e[1;34m"
echo "  __  ____                      ____   _____ "
echo "  \ \/ / /_  ______  ____  ____/ / /  / ___/ "
echo "   \  / __ \/ ___/ / / / __ \/ __  / /   \__ \  "
echo "   / / / / / /  / /_/ / /_/ / /_/ / /   ___/ /  "
echo "  /_/_/ /_/_/   \__, /\____/\__,_/_/   /____/   "
echo "               /____/  ENGINE v2026.1            "
echo -e "\e[0m"

REAL_USER=$(whoami)

whiptail --title "XyronOS Architect Suite" --msgbox \
"Welcome, $REAL_USER. This is the ZERO-TOUCH Pipeline.

This script will:
1. Update Host & Install Dependencies (QEMU, Expect, NC)
2. Generate automated Arch configurations
3. Detect the VM boot prompt via Serial Log
4. Automatically type installation commands
5. Finalize the ISO and push it back to the host." 18 60

# --- 2. WORKSPACE PREPARATION ---
BASE_DIR="$HOME/XyronOS-Engine"
OUT_DIR="$BASE_DIR/ISO_Output"
VM_DISK="$BASE_DIR/build_disk.qcow2"
ISO_BASE="$BASE_DIR/arch_base.iso"
MONITOR_SOCKET="$BASE_DIR/qemu-monitor.sock"
SERIAL_LOG="$BASE_DIR/vm_serial.log"

mkdir -p "$OUT_DIR"
touch "$SERIAL_LOG"
cd "$BASE_DIR" || exit

# --- 3. HOST UPDATE & DEPENDENCY INSTALL ---
echo "--- Phase 1: Updating Host System for $REAL_USER ---"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case $ID in
        arch|manjaro) 
            sudo pacman -Syu --noconfirm qemu-full wget expect libnewt netcat edk2-ovmf ;;
        debian|ubuntu|pop) 
            sudo apt update && sudo apt upgrade -y && sudo apt install -y qemu-system-x86 wget expect whiptail netcat-openbsd ovmf ;;
        fedora) 
            sudo dnf update -y && sudo dnf install -y qemu-system-x86 wget expect newt nc edk2-ovmf ;;
    esac
fi

# --- 4. USER SELECTION ---
DE=$(whiptail --title "Step 1: Interface" --menu "Select Desktop Environment:" 15 60 4 \
"gnome" "GNOME Desktop" \
"kde" "KDE Plasma" \
"xfce" "XFCE Desktop" \
"sway" "Sway Manager" 3>&1 1>&2 2>&3)

GREETER=$(whiptail --title "Step 2: Login" --menu "Select Display Manager:" 15 60 3 \
"gdm" "GDM (GNOME)" \
"sddm" "SDDM (KDE)" \
"lightdm" "LightDM (Universal)" 3>&1 1>&2 2>&3)

# --- 5. ASSET PREPARATION ---
echo "--- Phase 2: Preparing Virtual Assets ---"
[ ! -f "$ISO_BASE" ] && wget -O "$ISO_BASE" "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
if [ ! -f "$VM_DISK" ]; then
    echo "Creating 40GB Virtual Disk..."
    qemu-img create -f qcow2 "$VM_DISK" 40G
fi

# --- 6. ARCHINSTALL AUTOMATION CONFIG ---
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

# --- 7. VM INTERNAL FINALIZER ---
cat <<EOF > "$OUT_DIR/finalize.sh"
#!/bin/bash
echo "Building Final XyronOS ISO..."
sudo pacman -Sy --noconfirm archiso
mkdir -p ~/iso_build && cp -r /usr/share/archiso/configs/releng/* ~/iso_build/
pacman -Qqn > ~/iso_build/packages.x86_64
echo "$DE" >> ~/iso_build/packages.x86_64
echo "$GREETER" >> ~/iso_build/packages.x86_64
cd ~/iso_build && sudo mkarchiso -v -w /tmp/w -o /tmp/out .
sudo mount -t 9p -o trans=virtio hostshare /mnt
sudo cp /tmp/out/*.iso /mnt/XyronOS-Final.iso
EOF
chmod +x "$OUT_DIR/finalize.sh"

# --- 8. THE GHOST TYPER ENGINE ---
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

# --- 9. PHASE 3: VM EXECUTION ---
echo "--- Phase 3: Launching VM (Stability Mode) ---"
rm -f "$MONITOR_SOCKET" # Clean old socket

qemu-system-x86_64 \
    -m 4G -enable-kvm -cpu host -smp 4 \
    -drive file="$VM_DISK",if=virtio \
    -cdrom "$ISO_BASE" -boot d \
    -net nic -net user \
    -virtfs local,path="$OUT_DIR",mount_tag=hostshare,security_model=none,id=hostshare \
    -serial file:"$SERIAL_LOG" \
    -monitor unix:"$MONITOR_SOCKET",server,nowait \
    -vga virtio -display gtk &

# --- 10. PROMPT DETECTION & AUTO-INSTALL ---
echo "Waiting for Archiso shell (Monitoring Log)..."
while ! grep -q "archiso login:" "$SERIAL_LOG" 2>/dev/null; do
    sleep 3
    echo -n "."
done

echo -e "\n[!] PROMPT DETECTED. INJECTING COMMANDS..."
sleep 5
vm_type "mount -t 9p -o trans=virtio hostshare /mnt"
sleep 2
vm_type "archinstall --config /mnt/user_config.json --silent"

# --- 11. SUCCESS WATCHER ---
echo "--- Phase 4: Monitoring for Final ISO ---"
while [ ! -f "$OUT_DIR/XyronOS-Final.iso" ]; do
    sleep 10
done

whiptail --title "Mission Success" --msgbox \
"Congratulations, $REAL_USER! 

Your customized XyronOS ISO has been built and pushed to:
$OUT_DIR/XyronOS-Final.iso" 12 60
