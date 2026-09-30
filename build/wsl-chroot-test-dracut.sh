#!/usr/bin/env bash
# Testet im arm64-Chroot, ob dracut (Ubuntu 26.04 Standard-Initramfs) fuer den selbstgebauten Kernel ein initrd baut.
set -uo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
CH=/work/sl7/chroot-arm64
KVER=${KVER:-7.0.0-rc4-sl7}
for m in proc sys dev dev/pts; do mountpoint -q "$CH/$m" || mount --bind "/$m" "$CH/$m"; done
cat > "$CH/tmp/dracut-test.sh" <<EOF
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq dracut dracut-core 2>&1 | tail -2
dpkg -l initramfs-tools dracut dracut-core 2>/dev/null | grep '^ii' | awk '{print "    "\$2, \$3}'
echo "--- dracut --force --kver $KVER (unter qemu, dauert)"
time dracut --force --kver $KVER /boot/initrd.img-$KVER 2>&1 | tail -5
ls -la /boot/
echo "--- Inhalt (qcom/msm/ath12k/spi-hid/firmware):"
lsinitrd /boot/initrd.img-$KVER 2>/dev/null | grep -E 'ath12k|qcom|msm|spi.hid|firmware/qcom|\.dtb' | head -30
echo "--- dracut-Module:"
lsinitrd /boot/initrd.img-$KVER 2>/dev/null | sed -n '/dracut modules/,/^=====/p' | head -40
EOF
chroot "$CH" bash /tmp/dracut-test.sh
