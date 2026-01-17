#!/bin/bash
# ==============================================================================
# XyronOS Engine 
# Architect: OmarAsiri1
# ==============================================================================

# --- 1. WELCOME & BRANDING ---
clear
echo -e "\e[1;34m"
echo "  __  ____                      ____   _____ "
echo "  \ \/ / /_  ______  ____  ____/ / /  / ___/ "
echo "   \  / __ \/ ___/ / / / __ \/ __  / /   \__ \  "
echo "   / / / / / /  / /_/ / /_/ / /_/ / /   ___/ /  "
echo "  /_/_/ /_/_/   \__, /\____/\__,_/_/   /____/   "
echo "               /____/  ENGINE v2026.1            "
echo -e "\e[0m"

# --- 2. USER SELECTION (TUI) ---
DE=$(whiptail --title "XyronOS Architect" --menu "Choose Desktop Environment:" 15 60 4 \
"gnome" "GNOME Desktop" \
"kde" "KDE Plasma" \
"xfce" "XFCE Desktop" \
"sway" "Sway Window Manager" 3>&1 1>&2 2>&3)

GREETER=$(whiptail --title "XyronOS Architect" --menu "Choose Login Manager (Greeter):" 15 60 3 \
"gdm" "GDM (Best for GNOME)" \
"sddm" "SDDM (Best for KDE)" \
"lightdm" "LightDM (Lightweight)" 3>&1 1>&2 2>&3)

# --- 3. HOST UPDATE & DEPENDENCY INSTALL ---
echo "--- Phase 1: Updating Host System & Installing QEMU ---"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case $ID in
        arch|manjaro) sudo pacman -Syu --noconfirm qemu-full wget libnewt ;;
        debian|ubuntu|pop) sudo apt update && sudo apt upgrade -y && sudo apt install -y qemu-system-x86 wget whiptail ;;
        fedora) sudo dnf update -y && sudo dnf install -y qemu-system-x86 wget newt ;;
        alpine) apk update && apk upgrade && apk add qemu-system-x86_64 wget newt ;;
    esac
fi

# --- 4. WORKSPACE PREPARATION ---
BASE_DIR="$HOME/XyronOS-Engine"
OUT_DIR="$BASE_DIR/ISO_Output"
VM_DISK="$BASE_DIR/build_disk.qcow2"
ISO_BASE="$BASE_DIR/arch_base.iso"

mkdir -p "$OUT_DIR"
cd "$BASE_DIR" || exit

echo "--- Phase 2: Fetching Assets ---"
[ ! -f "$ISO_BASE" ] && wget -O "$ISO_BASE" "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
[ ! -f "$VM_DISK" ] && qemu-img create -f qcow2 "$VM_DISK" 40G

# --- 5. THE AUTOMATION INJECTOR ---
# This script is shared with the VM to build the ISO from WITHIN
cat <<EOF > "$OUT_DIR/finalize.sh"
#!/bin/bash
echo "Building your Custom XyronOS ISO..."
sudo pacman -Sy --noconfirm archiso
mkdir -p ~/iso_pkgs && cp -r /usr/share/archiso/configs/releng/* ~/iso_pkgs/
pacman -Qqn > ~/iso_pkgs/packages.x86_64
echo "$DE" >> ~/iso_pkgs/packages.x86_64
echo "$GREETER" >> ~/iso_pkgs/packages.x86_64
cd ~/iso_pkgs && sudo mkarchiso -v -w /tmp/w -o /tmp/out .
sudo mount -t 9p -o trans=virtio hostshare /mnt
sudo cp /tmp/out/*.iso /mnt/XyronOS-Final.iso
echo "SUCCESS: ISO PUSHED TO HOST."
EOF
chmod +x "$OUT_DIR/finalize.sh"

# --- 6. AUTOMATED INSTALLATION & GUI LAUNCH ---
whiptail --title "Engine Ready" --msgbox "The Engine will now: \n1. Install Arch with $DE automatically. \n2. Open the GUI window for you. \n3. Wait for you to finish." 12 60

echo "--- Phase 3: Launching Automated Builder ---"
# First boot: Installation
qemu-system-x86_64 \
    -m 4G -enable-kvm -cpu host -smp 4 \
    -drive file="$VM_DISK",if=virtio \
    -cdrom "$ISO_BASE" -boot d \
    -net nic -net user \
    -device virtio-vga-gl -display gtk,gl=on \
    -name "XyronOS - Auto-Installing $DE"

# Second boot: Your GUI for Customization
echo "--- Phase 4: Opening your Custom GUI ---"
qemu-system-x86_64 \
    -m 4G -enable-kvm -cpu host -smp 4 \
    -drive file="$VM_DISK",if=virtio \
    -net nic -net user \
    -virtfs local,path="$OUT_DIR",mount_tag=hostshare,security_model=none,id=hostshare \
    -device virtio-vga-gl -display gtk,gl=on \
    -name "XyronOS - Customization Window" &

# --- 7. THE WATCHER ---
echo "Waiting for you to finalize inside the VM..."
while [ ! -f "$OUT_DIR/XyronOS-Final.iso" ]; do
    sleep 10
done

whiptail --title "Victory!" --msgbox "Mission Accomplished, \n\nYour customized ISO is ready at: \n$OUT_DIR/XyronOS-Final.iso" 12 60
