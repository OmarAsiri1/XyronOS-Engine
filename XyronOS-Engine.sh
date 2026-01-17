#!/bin/bash
# XyronOS Short Engine - Architect: Omar Asiri

BASE_DIR="$HOME/XyronOS-Engine"
OUT_DIR="$BASE_DIR/ISO_Output"
MONITOR_SOCKET="$BASE_DIR/qemu-monitor.sock"
SERIAL_LOG="$BASE_DIR/vm_serial.log"

# 1. الدالة المسؤولة عن الكتابة التلقائية
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
        sleep 0.1
    done
    echo "sendkey ret" | nc -U "$MONITOR_SOCKET" -q 0
}

# 2. تشغيل الـ VM
echo "[*] Launching XyronOS Lab..."
qemu-system-x86_64 \
    -m 4G -enable-kvm -cpu host -smp 4 \
    -drive file="$BASE_DIR/build_disk.qcow2",if=virtio \
    -cdrom "$BASE_DIR/arch_base.iso" -boot d \
    -virtfs local,path="$OUT_DIR",mount_tag=hostshare,security_model=none,id=hostshare \
    -serial file:"$SERIAL_LOG" \
    -monitor unix:"$MONITOR_SOCKET",server,nowait \
    -vga virtio -display gtk &

# 3. نظام الانتظار الذكي (لو ما لقى الكلمة بيبدأ بعد 60 ثانية تلقائياً)
echo "[*] Waiting for Archiso (60s Timeout)..."
COUNT=0
while [ $COUNT -lt 30 ]; do
    if grep -aq "root@archiso" "$SERIAL_LOG" 2>/dev/null; then
        echo "[!] Prompt Detected!"
        break
    fi
    sleep 2
    echo -n "."
    ((COUNT++))
done

# 4. إرسال الأوامر فوراً
echo -e "\n[*] Injecting Commands now..."
sleep 10
vm_type "mount -t 9p -o trans=virtio hostshare /mnt"
sleep 2
vm_type "archinstall --config /mnt/user_config.json --silent"

echo "[DONE] Check the QEMU window, Omar!"
