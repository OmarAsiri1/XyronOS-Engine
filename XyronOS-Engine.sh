#!/bin/bash
# ==============================================================================
# XyronOS Engine - THE FULL ARCHITECT SUITE
# Architect: OmarAsiri1
# ==============================================================================

# --- 1. THE F***ING WELCOME SCREEN (PROPERLY IMPLEMENTED) ---
clear
echo -e "\e[1;34m"
echo "  __  ____                      ____   _____ "
echo "  \ \/ / /_  ______  ____  ____/ / /  / ___/ "
echo "   \  / __ \/ ___/ / / / __ \/ __  / /   \__ \  "
echo "   / / / / / /  / /_/ / /_/ / /_/ / /   ___/ /  "
echo "  /_/_/ /_/_/   \__, /\____/\__,_/_/   /____/   "
echo "               /____/  ENGINE v2026.1            "
echo -e "\e[0m"

# TUI Welcome Message
whiptail --title "XyronOS Architect Suite" --msgbox \
"Welcome, Omar. This is the Complete Automated Pipeline.

STAGES:
1. Host System Update (All Distros)
2. Dependency Installation (QEMU, Wget, etc.)
3. Virtual Environment Prep (40GB Disk)
4. Automated Arch Installation inside VM
5. GUI Customization & ISO 'Push' to Host" 18 60

# --- 2. HOST UPDATE & DEPENDENCY INSTALL ---
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

# --- 3. USER SELECTION (DE & GREETER) ---
DE=$(whiptail --title "Step 1: Desktop Environment" --menu "Select the interface for your ISO:" 15 60 4 \
"gnome" "GNOME Desktop" \
"kde" "KDE Plasma" \
"xfce" "XFCE Desktop" \
"sway" "Sway Manager" 3>&1 1>&2 2>&3)

GREETER=$(whiptail --title "Step 2: Display Manager" --menu "Select your Login Greeter:" 15 60 3 \
"gdm" "GDM (Standard for GNOME)" \
"sddm" "SDDM (Standard for KDE)" \
"lightdm" "LightDM (Universal)" 3>&1 1>&2 2>&3)

# --- 4. WORKSPACE PREPARATION ---
BASE_DIR="$HOME/XyronOS-Engine"
OUT_DIR="$BASE_DIR/ISO_Output"
VM_DISK="$BASE_DIR/build_disk.qcow2"
ISO_BASE="$BASE_DIR/arch_base.iso"

mkdir -p "$OUT_DIR"
cd "$BASE_DIR" || exit

echo "--- Phase 2: Preparing VM Assets ---"
[ ! -f "$ISO_BASE" ] && wget -O "$ISO_BASE" "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
[ ! -f "$VM_DISK" ] && qemu-img create -f qcow2 "$VM_DISK" 40G

# --- 5. INTERNAL VM FINALIZER (The 'Push' Tool) ---
cat <<EOF > "$OUT_DIR/finalize.sh"
#!/bin/bash
echo "--- Building XyronOS Final ISO ---"
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

# --- 6. VM INSTALLATION & GUI LAUNCH ---
whiptail --title "Builder Starting" --msgbox \
"The VM will open now. 
1. Use 'archinstall' inside to set up your system. 
2. Ensure you select $DE. 
3. After the install finishes, the VM will close and the Engine will open your NEW GUI." 15 60

# First Boot: Installation Phase
qemu-system-x86_64 \
    -m 4G -enable-kvm -cpu host -smp 4 \
    -drive file="$VM_DISK",if=virtio \
    -cdrom "$ISO_BASE" -boot d \
    -net nic -net user \
    -device virtio-vga-gl -display gtk,gl=on \
    -name "XyronOS - Automated Installer"

# Second Boot: Customization Phase (The GUI you wanted)
echo "--- Phase 3: Launching Your Customized GUI ---"
qemu-system-x86_64 \
    -m 4G -enable-kvm -cpu host -smp 4 \
    -drive file="$VM_DISK",if=virtio \
    -net nic -net user \
    -virtfs local,path="$OUT_DIR",mount_tag=hostshare,security_model=none,id=hostshare \
    -device virtio-vga-gl -display gtk,gl=on \
    -name "XyronOS Live Lab" &

# --- 7. THE SUCCESS WATCHER ---
echo "Engine is watching $OUT_DIR for the final ISO..."
while [ ! -f "$OUT_DIR/XyronOS-Final.iso" ]; do
    sleep 10
done

whiptail --title "Victory" --msgbox "Mission Complete, Omar!

Your custom XyronOS ISO has been generated and pushed to: 
$OUT_DIR/XyronOS-Final.iso" 12 60
