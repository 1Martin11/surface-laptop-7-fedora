#!/usr/bin/env bash
# Fertige Kernel-RPMs pruefen (Skripte, Layout) und nach build/fedora/out kopieren.
set -uo pipefail
export LC_ALL=C
OUT=/work/sl7/fedora/rpm; K=/work/sl7/kernel/ellx-7.0-sl7
WINOUT="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora/out"
KVER=$(cd "$K" && LOCALVERSION=-sl7 make -s kernelrelease ARCH=arm64)
IMG=$(find "$OUT/rpmbuild/RPMS" -name 'kernel-7*.aarch64.rpm' | grep -vE 'headers|devel' | head -1)
echo "Paket: $IMG ($(stat -c %s "$IMG") Bytes)"
echo "=== Info"; rpm -qp --info "$IMG" 2>/dev/null | grep -E '^(Name|Version|Release|Architecture|Summary)'
echo "=== Nicht-Modul-Dateien (Auszug)"; rpm -qpl "$IMG" 2>/dev/null | grep -vE '/lib/modules/[^/]+/kernel/|/boot/dtb-[^/]+/[a-z]+/' | grep -vE '^/boot/dtb-[^/]+/[a-z-]+$' | head -25
echo "=== romulus-DTBs"; rpm -qpl "$IMG" 2>/dev/null | grep -i romulus
echo "=== Skripte"; rpm -qp --scripts "$IMG" 2>/dev/null
echo "=== Module: $(rpm -qpl "$IMG" 2>/dev/null | grep -c '\.ko')"
echo "=== Requires"; rpm -qp --requires "$IMG" 2>/dev/null | head -8
D="$WINOUT/$KVER-1"; mkdir -p "$D"
cp -f "$OUT"/rpmbuild/RPMS/aarch64/*.rpm "$D/"
cp -f "$K/arch/arm64/boot/vmlinuz.efi" "$D/vmlinuz-$KVER.efi"; cp -f "$K/arch/arm64/boot/Image.gz" "$D/Image.gz-$KVER"
cp -f "$K"/arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb "$K"/arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13-exp.dtb "$K"/arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus15.dtb "$D/"
cp -f "$K/.config" "$D/config-$KVER"
(cd "$D" && sha256sum *.rpm *.dtb vmlinuz-*.efi > SHA256SUMS)
ls -la "$D"
