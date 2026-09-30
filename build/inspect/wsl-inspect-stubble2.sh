#!/usr/bin/env bash
# Teil 2: stubble-Paket, Packaging-Regeln, GRUB-Logik im Live-System der x1e-ISO (unsquashfs).
set -uo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
K=/work/sl7/kernel/ellx-7.0-sl7
ISO="/mnt/c/Users/Martin/Downloads/questing-desktop-arm64+x1e.iso"
W=/work/sl7/iso-inspect
echo "=== [A] stubble-Paket"
mkdir -p "$W/stubble" && cd "$W/stubble"
apt-get download stubble >/dev/null 2>&1 && dpkg-deb -x stubble_*.deb x && find x -type f | head -20
for f in $(find x -type f -path '*bin*' | head -3); do echo "--- $f (Kopf)"; head -60 "$f"; done
echo
echo "=== [B] Packaging: stubble-Abschnitt in $K/debian/rules.d/2-binary-arch.mk"
grep -a -n -A22 'do_stubble),true' "$K/debian/rules.d/2-binary-arch.mk" | head -50
echo "--- Build-Depends stubble?"; grep -a -n 'stubble' "$K/debian.qcom-x1e/control.stub.in" "$K/debian/control.stub.in" "$K/debian/rules.d/0-common-vars.mk" 2>/dev/null | head
echo
echo "=== [C] Live-System: squashfs-Layer"
7z l -ba "$ISO" | awk '{print $4, $NF}' | grep -E 'squashfs$'
MAIN=$(7z l -ba "$ISO" | awk '{print $NF}' | grep -E 'casper/minimal\.squashfs$' | head -1)
echo "Haupt-Layer: $MAIN"
if [ ! -f "$W/$MAIN" ]; then 7z x -o"$W" "$ISO" "$MAIN" >/dev/null 2>&1; fi
ls -la "$W/$MAIN"
rm -rf "$W/sqroot"
unsquashfs -q -n -d "$W/sqroot" "$W/$MAIN" etc/grub.d etc/kernel etc/default var/lib/dpkg/info usr/lib/linux-image* boot usr/bin/stubble usr/lib/stubble usr/share/stubble usr/share/initramfs-tools/hooks 2>&1 | tail -2
echo "--- /boot im Live-System:"; ls -la "$W/sqroot/boot" 2>/dev/null
echo "--- usr/lib/linux-image-*:"; ls "$W/sqroot/usr/lib/" 2>/dev/null | grep linux-image; ls "$W/sqroot/usr/lib/linux-image-"*/qcom 2>/dev/null | grep -i romulus
echo "--- etc/grub.d:"; ls "$W/sqroot/etc/grub.d" 2>/dev/null
echo "--- 10_linux: devicetree/dtb-Stellen:"
grep -n -i -B3 -A10 'devicetree\|dtb' "$W/sqroot/etc/grub.d/10_linux" 2>/dev/null | head -80
echo "--- etc/default/grub + grub.d:"; cat "$W/sqroot/etc/default/grub" 2>/dev/null | grep -v '^#' | grep -v '^$'; ls "$W/sqroot/etc/default/grub.d" 2>/dev/null; cat "$W/sqroot/etc/default/grub.d/"* 2>/dev/null | head -20
echo "--- etc/kernel/postinst.d:"; ls "$W/sqroot/etc/kernel/postinst.d" 2>/dev/null
echo "--- linux-image-Pakete im Live-System (dpkg):"; ls "$W/sqroot/var/lib/dpkg/info/" 2>/dev/null | grep -E '^linux-image' | head
for l in "$W/sqroot/var/lib/dpkg/info/"linux-image-*.list; do [ -f "$l" ] && { echo "  $l:"; grep -E '/boot/|dtb' "$l" | head -12; }; done
echo "--- initramfs-hooks mit qcom/firmware-Bezug:"; ls "$W/sqroot/usr/share/initramfs-tools/hooks" 2>/dev/null | head -20
