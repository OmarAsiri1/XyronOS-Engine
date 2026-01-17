#!/bin/bash
# XyronOS Engine - Professional ISO Architect
# Architect: OmarAsiri1

# --- 1. BRANDED WELCOME SCREEN ---
clear
echo -e "\e[1;34m"
echo "  __  ____                      ____   _____ "
echo "  \ \/ / /_  ______  ____  ____/ / /  / ___/ "
echo "   \  / __ \/ ___/ / / / __ \/ __  / /   \__ \  "
echo "   / / / / / /  / /_/ / /_/ / /_/ / /   ___/ /  "
echo "  /_/_/ /_/_/   \__, /\____/\__,_/_/   /____/   "
echo "               /____/  ENGINE v26.0             "
echo -e "\e[0m"

whiptail --title "XyronOS Architect Suite" --msgbox \
"Welcome, \n\nThis engine will guide you through creating a custom XyronOS ISO. \n\nYou will choose your Desktop, customize the system in a Live VM, and then 'Push' the final product back to your host folder." 15 60

# --- 2. CONFIGURATION & SELECTION ---
BASE_DIR="$HOME/XyronOS-Engine"
OUT_DIR="$BASE_DIR/ISO_Output"
VM_DISK="$BASE_DIR/build_disk.qcow2"
mkdir -p "$OUT_DIR"

DE=$(whiptail --title "Step 1: Desktop Environment" --menu "Choose your primary interface:" 15 60 4 \
"gnome" "GNOME Desktop (Modern)" \
"kde" "KDE Plasma (Customizable)" \
"xfce" "XFCE (Fast & Light)" \
"sway" "Sway (Tiling Wayland)" 3>&1 1>&2 2>&3)

GREETER=$(whiptail --title "Step 2: Display Manager" --menu "Select your login screen (Greeter):" 15 60 3 \
"gdm" "GDM (GNOME's native)" \
"sddm" "SDDM (KDE's native)" \
"lightdm" "LightDM (Universal)" 3>&1 1>&2 2>&3)

# --- 3. PREPARING ASSETS ---
echo "Preparing base assets..."
[ ! -f "$BASE_DIR/arch.iso" ] && wget -O "$BASE_DIR/arch.iso" "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
[ ! -f "$VM_DISK" ] && qemu-img create -f qcow2 "$VM_DISK" 40G

# --- 4. THE INTERNAL BUILDER (Injected into VM) ---
cat <<EOF > "$OUT_DIR/finalize.sh"
#!/bin/bash
# Finalization script inside the VM
sudo pacman -Sy --noconfirm archiso
mkdir -p ~/iso_build && cp -r /usr/share/archiso/configs/releng/* ~/iso_build/
pacman -Qqn > ~/iso_build/packages.x86_64
echo "$DE" >> ~/iso_build/packages.x86_64
echo "$GREETER" >> ~/iso_build/packages.x86_64
sudo systemctl enable $GREETER
cd ~/iso_build && sudo mkarchiso -v -w /tmp/work -o /tmp/out .
sudo mount -t 9p -o trans=virtio hostshare /mnt
sudo cp /tmp/out/*.iso /mnt/XyronOS-Final.iso
echo "BUILD COMPLETE. ISO PUSHED TO HOST."
EOF
chmod +x "$OUT_DIR/finalize.sh"

# --- 5. LAUNCHING THE LAB ---
whiptail --title "Lab Ready" --msgbox \
"The VM is starting. \n\n1. Use 'archinstall' inside. \n2. When finished customizing, run: \n   sudo mount -t 9p -o trans=virtio hostshare /mnt \n3. Execute: /mnt/finalize.sh" 12 60

qemu-system-x86_64 \
    -m 4G -enable-kvm -cpu host -smp 4 \
    -drive file="$VM_DISK",if=virtio \
    -cdrom "$BASE_DIR/arch.iso" -boot d \
    -net nic -net user \
    -virtfs local,path="$OUT_DIR",mount_tag=hostshare,security_model=none,id=hostshare \
    -device virtio-vga-gl -display gtk,gl=on &

# --- 6. SUCCESS WATCHER ---
echo "Engine is watching $OUT_DIR for the finished ISO..."
while [ ! -f "$OUT_DIR/XyronOS-Final.iso" ]; do sleep 10; done

whiptail --title "Victory" --msgbox "Operation Successful. \n\nYour customized XyronOS ISO has been pushed to: \n$OUT_DIR/XyronOS-Final.iso" 10 60
