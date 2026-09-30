#!/usr/bin/env bash
# Kernel B (Ubuntu 26.10 linux-source 7.3.0-5.5 + ItsLucas-Serie r15.1, Tag sl7b) bauen und als Fedora-RPM paketieren.
# Vorher: wsl-prepare-kernel-73.sh + wsl-fix-kernel-73.sh (Tree /work/sl7/kernel/ubuntu-7.3, .config aus linux-buildinfo).
set -euo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ubuntu-7.3
OUT=/work/sl7/fedora/rpm-b
WINOUT="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora/out"
PKGREV=${PKGREV:-1}
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KBUILD_BUILD_USER=martin KBUILD_BUILD_HOST=sl7-build
export LOCALVERSION=-sl7b
J=$(nproc)
mkdir -p "$OUT" "$WINOUT"
cd "$K"
[ "$(git describe --tags --exact-match 2>/dev/null)" = sl7b ] || { echo "HEAD ist nicht Tag sl7b - erst wsl-fix-kernel-73.sh"; exit 1; }
echo "=== [1/5] Konfiguration"
make -s olddefconfig
KVER=$(make -s kernelrelease); echo "    Kernel-Release: $KVER"
for o in EFI_ZBOOT SPI_HID ATH12K DRM_MSM VIDEO_QCOM_IRIS QCOM_Q6V5_PAS MODULE_COMPRESS_ZSTD MODULE_SIG_ALL RUST; do printf '    %-24s %s\n' "$o" "$(grep -E "^CONFIG_$o=" .config | cut -d= -f2 || echo -)"; done
echo "=== [2/5] Build (make -j$J) - generic-Config, dauert"
START=$(date +%s)
make -j"$J" Image.gz vmlinuz.efi modules dtbs > "$OUT/build.log" 2>&1 || { echo "BUILD FEHLER, siehe $OUT/build.log"; grep -nE '\berror\b' "$OUT/build.log" | head; exit 1; }
echo "    Dauer: $(( ($(date +%s) - START) / 60 )) min   Warnungen: $(grep -c 'warning:' "$OUT/build.log" || true)"
ls -la arch/arm64/boot/Image.gz arch/arm64/boot/vmlinuz.efi arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb
echo "=== [3/5] RPM-Paketierung"
rm -rf "$OUT/rpmbuild"; mkdir -p "$OUT/rpmbuild"
make -j1 binrpm-pkg RPMOPTS="--define '_topdir $OUT/rpmbuild' --define '_rpmdir $OUT/rpmbuild/RPMS' --target aarch64-linux" > "$OUT/rpm.log" 2>&1 || { echo "RPM FEHLER, siehe $OUT/rpm.log"; tail -30 "$OUT/rpm.log"; exit 1; }
find "$OUT/rpmbuild" -name '*.rpm' -printf '%10s  %P\n'
echo "=== [4/5] RPM pruefen"
IMG=$(find "$OUT/rpmbuild" -name 'kernel-7*.aarch64.rpm' | grep -vE 'headers|devel' | head -1); echo "    Paket: $IMG"
rpm -qp --info "$IMG" 2>/dev/null | grep -E '^(Name|Version|Release|Architecture|Size)' | sed 's/^/    /'
echo "    Module gesamt: $(rpm -qpl "$IMG" 2>/dev/null | grep -c '\.ko' || true)   romulus-DTBs: $(rpm -qpl "$IMG" 2>/dev/null | grep -c 'romulus' || true)"
echo "=== [5/5] Ergebnis nach Windows"
D="$WINOUT/$KVER-$PKGREV"; mkdir -p "$D"
cp -f $(find "$OUT/rpmbuild" -name '*.rpm') "$D/"
cp -f arch/arm64/boot/vmlinuz.efi "$D/vmlinuz-$KVER.efi"; cp -f arch/arm64/boot/Image.gz "$D/Image.gz-$KVER"
cp -f arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus15.dtb "$D/"
cp -f .config "$D/config-$KVER"
(cd "$D" && sha256sum *.rpm *.dtb vmlinuz-*.efi > SHA256SUMS)
ls -la "$D"; echo "FERTIG: $D"
