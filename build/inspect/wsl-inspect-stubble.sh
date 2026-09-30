#!/usr/bin/env bash
# Wie kommen die DTBs in den Kernel? (Ubuntu "stubble"/.dtbauto) - Packaging-Regeln, Live-System der ISO, ELLX-Prebuilt pruefen.
set -uo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7
ISO="/mnt/c/Users/Martin/Downloads/questing-desktop-arm64+x1e.iso"
W=/work/sl7/iso-inspect
cd "$K"
echo "=== [1] debian/rules.d: stubble-Abschnitt"
grep -n -B3 -A25 'ifeq ($(do_stubble),true)' debian/rules.d/2-binary-arch.mk | head -60
echo "--- stubble in 0-common-vars / debian/scripts / control:"
grep -rn 'stubble' debian/rules.d/0-common-vars.mk debian/control.stub* debian.qcom-x1e/control.stub.in debian/scripts 2>/dev/null | head -10
ls debian/scripts | grep -i stub || true
echo "--- dtbauto im Kernel-Quelltext:"
grep -rn 'dtbauto\|dtb_override' drivers/firmware/efi/libstub/*.c arch/arm64/kernel/*.c 2>/dev/null | head -10
echo "--- stubble-Paket in Ubuntu?"
apt-cache policy stubble 2>/dev/null | head -3; apt-cache search stubble 2>/dev/null | head -3

echo
echo "=== [2] Live-System der ISO (squashfs): grub.d, kernel-Hooks, stubble, linux-image-Layout"
mkdir -p "$W/sq"
SQ=$(7z l -ba "$ISO" | awk '{print $NF}' | grep -E 'casper/.*\.squashfs$' | grep -vE 'installer|language|desktop-langs' | head -3)
echo "squashfs-Dateien: $SQ"
MAIN=$(echo "$SQ" | grep -E 'minimal.squashfs|filesystem.squashfs' | head -1)
[ -n "$MAIN" ] || MAIN=$(echo "$SQ" | head -1)
echo "verwende: $MAIN"
7z x -o"$W" "$ISO" "$MAIN" >/dev/null 2>&1
SQF="$W/$MAIN"
ls -la "$SQF"
7z l -ba "$SQF" 2>/dev/null | awk '{print $NF}' | grep -E '^(etc/grub.d/|etc/kernel/postinst.d/|etc/kernel/postrm.d/|usr/bin/stubble|usr/sbin/stubble|usr/share/stubble|boot/|usr/lib/linux-image|etc/default/grub|usr/lib/systemd/boot|lib/firmware/[0-9])' | head -60
echo "--- etc/grub.d/10_linux: devicetree/dtb-Logik"
7z x -so "$SQF" etc/grub.d/10_linux 2>/dev/null | grep -n -i -B2 -A6 'devicetree\|dtb' | head -60
echo "--- kernel postinst hooks:"
for h in $(7z l -ba "$SQF" 2>/dev/null | awk '{print $NF}' | grep -E '^etc/kernel/postinst.d/' ); do echo "  $h"; done
echo "--- stubble-Skript (falls vorhanden):"
for s in usr/bin/stubble usr/sbin/stubble usr/share/stubble/stubble; do 7z x -so "$SQF" "$s" 2>/dev/null | head -40; done
echo "--- installiertes linux-image Paket im Live-System:"
7z l -ba "$SQF" 2>/dev/null | awk '{print $NF}' | grep -E '^var/lib/dpkg/info/linux-image.*\.(postinst|list)$' | head
7z x -so "$SQF" $(7z l -ba "$SQF" 2>/dev/null | awk '{print $NF}' | grep -E '^var/lib/dpkg/info/linux-image.*\.list$' | head -1) 2>/dev/null | grep -E 'dtb|vmlinuz|/boot/' | head -20

echo
echo "=== [3] ELLX-Prebuilt: vmlinuz-Sektionen (.dtbauto?)"
mkdir -p "$W/ellx" && cd "$W/ellx"
curl -sL --fail -o linux-image-ellx.deb "https://public.hgci.org/software/ELLX/kernels/7.0.0-rc4-12/linux-image-7.0.0-rc4%2B_7.0.0~rc4-g0e9944fa4cf2-44_arm64.deb" && ls -la linux-image-ellx.deb
dpkg-deb -c linux-image-ellx.deb | awk '{print $6}' | grep -E 'boot/|/qcom/x1e80100-microsoft|postinst' | head -10
dpkg-deb -x linux-image-ellx.deb x >/dev/null 2>&1
VM=$(ls x/boot/vmlinuz-* 2>/dev/null | head -1); ls -la "$VM"
aarch64-linux-gnu-objdump -h "$VM" 2>/dev/null | grep -E 'dtbauto|Idx|\.linux|\.initrd|\.dtb' | head -20
strings -n 8 "$VM" | grep -E 'X1E80100-|dtbauto' | head -15
echo "--- eigenes vmlinuz.efi zum Vergleich:"
aarch64-linux-gnu-objdump -h "$K/arch/arm64/boot/vmlinuz.efi" 2>/dev/null | grep -E 'dtbauto|\.dtb' | head
echo "Sektionen eigen: $(aarch64-linux-gnu-objdump -h "$K/arch/arm64/boot/vmlinuz.efi" | grep -cE '^ +[0-9]+ ')  /  ELLX: $(aarch64-linux-gnu-objdump -h "$VM" | grep -cE '^ +[0-9]+ ')"
