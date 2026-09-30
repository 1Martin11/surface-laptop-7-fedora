#!/usr/bin/env bash
# Testinstallation des selbstgebauten Kernel-.deb im arm64-Chroot (qemu-user): prueft postinst, DTB-Pfade,
# initramfs-Erzeugung und ob die wichtigen Module im Paket sind. Aendert nichts am Laptop.
set -uo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
CH=/work/sl7/chroot-arm64
DEB=$(ls -t /work/sl7/out/*/linux-image-*_arm64.deb 2>/dev/null | grep -v dbg | head -n1)
[ -n "$DEB" ] || { echo "kein linux-image .deb in /work/sl7/out"; exit 1; }
KVER=$(basename "$DEB" | sed -E 's/^linux-image-([^_]+)_.*/\1/')
echo "=== Paket: $DEB  (Kernel $KVER)"
for m in proc sys dev dev/pts; do mountpoint -q "$CH/$m" || mount --bind "/$m" "$CH/$m"; done
cp "$DEB" "$CH/tmp/"
cat > "$CH/tmp/test.sh" <<EOF
set -u
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
echo "--- arch: \$(uname -m) / dpkg: \$(dpkg --print-architecture)"
dpkg -l initramfs-tools kmod zstd 2>/dev/null | awk '/^ii/{print "    "\$2, \$3}'
echo "--- dpkg -i"
dpkg -i /tmp/$(basename "$DEB") 2>&1 | tail -8
echo "--- /boot:"; ls -la /boot | sed 's/^/    /'
echo "--- DTB im Paket:"; ls -la /usr/lib/linux-image-$KVER/qcom/x1e80100-microsoft-romulus13.dtb /usr/lib/linux-image-$KVER/qcom/x1e80100-microsoft-romulus15.dtb 2>&1 | sed 's/^/    /'
echo "--- Module (Anzahl): \$(find /lib/modules/$KVER -name '*.ko*' | wc -l)"
for m in ath12k spi-hid qcom_q6v5_pas msm phy-qcom-qmp-pcie pcie-qcom qcom_battmgr ucsi_glink snd-soc-x1e80100 snd-soc-wcd9385 snd-soc-wsa884x ov02c10 qcom-camss hid-multitouch pmic_glink_altmode; do
  f=\$(find /lib/modules/$KVER -name "\$m.ko*" | head -n1); printf '    %-22s %s\n' "\$m" "\${f:-FEHLT}"
done
echo "--- initramfs bauen (update-initramfs -c -k $KVER, unter qemu langsam)"
time update-initramfs -c -k $KVER 2>&1 | tail -3
ls -la /boot/initrd.img-$KVER 2>&1 | sed 's/^/    /'
echo "--- initramfs-Inhalt (qcom/msm/ath12k/hid Module):"
lsinitramfs /boot/initrd.img-$KVER 2>/dev/null | grep -E 'ath12k|qcom|msm|spi.hid|hid-multitouch|firmware/qcom' | head -25 | sed 's/^/    /'
echo "--- Firmware im initramfs:"
lsinitramfs /boot/initrd.img-$KVER 2>/dev/null | grep -E '^usr/lib/firmware|^lib/firmware' | grep -E 'qcom|ath12k' | head -15 | sed 's/^/    /'
EOF
chroot "$CH" bash /tmp/test.sh
echo "=== fertig"
