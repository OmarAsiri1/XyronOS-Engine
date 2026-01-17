#!/bin/bash
# XyronOS Engine - Professional ISO Architect
# Architect: OmarAsiri1 in 2026

# --- 1. SETUP & SELECTION ---
BASE_DIR="$HOME/XyronOS-Engine"
OUT_DIR="$BASE_DIR/ISO_Output"
VM_DISK="$BASE_DIR/build_disk.qcow2"
mkdir -p "$OUT_DIR"

# UI for User Choices
DE=$(whiptail --title "XyronOS Selection" --menu "Select your Desktop Environment:" 15 60 4 \
"gnome" "GNOME Desktop" \
"kde" "KDE Plasma" \
"xfce" "XFCE (Lightweight)" \
"sway" "Sway (Tiling WM)" 3>&1 1>&2 2>&3)

GREETER=$(whiptail --title "Greeter Selection" --menu "Select your Login Manager (Greeter):" 15 60 3 \
"gdm" "GDM (Standard for GNOME)" \
"sddm" "SDDM (Standard for KDE)" \
"lightdm" "LightDM (Universal)" 3>&1 1>&2 2>&3)

# --- 2. ASSET PREP ---
[ ! -f "$BASE_DIR/arch.iso" ] && wget -O "$BASE_DIR/arch.iso" "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
[ ! -f "$VM_DISK" ] && qemu-img create -f qcow2 "$VM_DISK" 40G

# --- 3. INTERNAL AUTOMATION SCRIPT (The Factory) ---
# This script is sent to the VM to build the ISO based on YOUR choices
cat <<EOF > "$OUT_DIR/finalize.sh"
#!/bin/bash
echo "--- Installing Build Tools ---"
sudo pacman -Sy --noconfirm archiso
mkdir -p ~/iso_build && cp -r /usr/share/archiso/configs/releng/* ~/iso_build/

echo "--- Customizing packages.x86_64 ---"
pacman -Qqn > ~/iso_build/packages.x86_64
echo "$DE" >> ~/iso_build/packages.x86_64
echo "$GREETER" >> ~/iso_build/packages.x86_64

echo "--- Enabling Services ---"
mkdir -p ~/iso_build/airootfs/etc/systemd/system/display-manager.service.d/
sudo systemctl enable $GREETER

echo "--- Compiling Final XyronOS ISO ---"
cd ~/iso_build && sudo mkarchiso -v -w /tmp/work -o /tmp/out .

echo "--- Pushing ISO to Host Folder ---"
sudo mount -t 9p -o trans=virtio hostshare /mnt
sudo cp /tmp/out/*.iso /mnt/XyronOS-Final.iso
EOF
chmod +x "$OUT_DIR/finalize.sh"

# --- 4. LAUNCHING THE ENVIRONMENT ---
whiptail --msgbox "Launching VM. \n1. Run 'archinstall' & select $DE.\n2. Customize everything.\n3. Run /mnt/finalize.sh to push the ISO." 12 60

qemu-system-x86_64 \
    -m 4G -enable-kvm -cpu host -smp 4 \
    -drive file="$VM_DISK",if=virtio \
    -cdrom "$BASE_DIR/arch.iso" -boot d \
    -net nic -net user \
    -virtfs local,path="$OUT_DIR",mount_tag=hostshare,security_model=none,id=hostshare \
    -device virtio-vga-gl -display gtk,gl=on &

# --- 5. THE WATCHER ---
echo "Waiting for $DE ISO production..."
while [ ! -f "$OUT_DIR/XyronOS-Final.iso" ]; do sleep 10; done

whiptail --title "Complete" --msgbox "Success! Your $DE ISO is ready in the XyronOS-Engine folder." 10 60
