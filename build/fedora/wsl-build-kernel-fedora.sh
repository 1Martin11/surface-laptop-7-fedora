#!/usr/bin/env bash
# Kernel fuer das Fedora-ISO bauen (Zweig sl7-fedora: ELLX-Tag + konservative Patches + exp-DTB) und als RPM paketieren
# (make binrpm-pkg, Cross-Compile). Ergebnis nach /work/sl7/fedora/rpm und build/fedora/out.
# Aufruf (als root in WSL):  bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora/wsl-build-kernel-fedora.sh"
# Variablen: PKGREV (Standard 1), NOBUILD=1 (nur Konfiguration), RECONFIG=1 (Config neu aus Annotations)
set -euo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7
OUT=/work/sl7/fedora/rpm
WINOUT="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora/out"
PKGREV=${PKGREV:-1}
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KBUILD_BUILD_USER=martin KBUILD_BUILD_HOST=sl7-build
export LOCALVERSION=-sl7
J=$(nproc)
mkdir -p "$OUT" "$WINOUT"
cd "$K"
[ "$(git rev-parse --abbrev-ref HEAD)" = sl7-fedora ] || { echo "nicht auf Zweig sl7-fedora - erst wsl-tree-safe-exp.sh laufen lassen"; exit 1; }
git checkout -q -- debian debian.master debian.qcom-x1e 2>/dev/null || true

echo "=== [1/5] Konfiguration"
if [ ! -f .config ] || [ "${RECONFIG:-0}" = 1 ]; then
  python3 debian/scripts/misc/annotations --arch arm64 --flavour qcom-x1e --export > .config
  scripts/config --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS "" \
    --disable MODULE_SIG_FORCE --disable DEBUG_INFO --disable DEBUG_INFO_DWARF5 --disable DEBUG_INFO_BTF --enable DEBUG_INFO_NONE \
    --set-str LOCALVERSION "" --disable LOCALVERSION_AUTO --enable SPI_HID --module VIDEO_OV02C10 2>/dev/null || true
fi
make -s olddefconfig
KVER=$(make -s kernelrelease)
echo "    Kernel-Release: $KVER"
for o in EFI_ZBOOT SPI_HID ATH12K DRM_MSM VIDEO_QCOM_IRIS BATTERY_QCOM_BATTMGR QCOM_CPUCP_MBOX ARM_SCMI_CPUFREQ MODULE_COMPRESS_ZSTD; do
  printf '    %-24s %s\n' "$o" "$(grep -E "^CONFIG_$o=" .config | cut -d= -f2 || echo -)"
done
[ "${NOBUILD:-0}" = 1 ] && { echo "NOBUILD=1 -> Ende"; exit 0; }

echo "=== [2/5] Build (make -j$J)"
START=$(date +%s)
make -j"$J" Image.gz vmlinuz.efi modules dtbs > "$OUT/build.log" 2>&1 || { echo "BUILD FEHLER, siehe $OUT/build.log"; grep -nE 'error' "$OUT/build.log" | head; exit 1; }
echo "    Dauer: $(( ($(date +%s) - START) / 60 )) min"
ls -la arch/arm64/boot/Image.gz arch/arm64/boot/vmlinuz.efi arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13-exp.dtb

echo "=== [3/5] RPM-Paketierung (make binrpm-pkg, Cross)"
command -v rpmbuild >/dev/null || { echo "rpmbuild fehlt (apt install rpm)"; exit 1; }
rm -rf "$OUT/rpmbuild"; mkdir -p "$OUT/rpmbuild"
# RPMOPTS: Zielarchitektur und Ausgabeort; -j1 wegen Paketier-Races
make -j1 binrpm-pkg RPMOPTS="--define '_topdir $OUT/rpmbuild' --define '_rpmdir $OUT/rpmbuild/RPMS' --target aarch64-linux" > "$OUT/rpm.log" 2>&1 || { echo "RPM FEHLER, siehe $OUT/rpm.log"; tail -30 "$OUT/rpm.log"; exit 1; }
find "$OUT/rpmbuild" -name '*.rpm' -printf '%10s  %P\n'

echo "=== [4/5] RPM-Inhalt pruefen"
IMG=$(find "$OUT/rpmbuild" -name "kernel-${KVER//-/_}*.rpm" -o -name "kernel-7*.aarch64.rpm" | grep -vE 'headers|devel' | head -1)
[ -n "$IMG" ] || IMG=$(find "$OUT/rpmbuild" -name 'kernel-*.rpm' | grep -vE 'headers|devel' | head -1)
echo "    Paket: $IMG"
rpm -qp --info "$IMG" 2>/dev/null | grep -E '^(Name|Version|Release|Architecture)' | sed 's/^/    /'
echo "    --- Dateien (ohne Module):"; { rpm -qpl "$IMG" 2>/dev/null | grep -vE '/lib/modules/[^/]+/kernel/|/boot/dtb-[^/]+/(?!qcom)' | grep -E 'vmlinuz|romulus|System.map|config-|/lib/modules/[^/]+$' || true; } | head -20 || true
echo "    --- Skripte:"; { rpm -qp --scripts "$IMG" 2>/dev/null || true; } | head -40 || true
echo "    --- Module gesamt: $(rpm -qpl "$IMG" 2>/dev/null | grep -c '\.ko' || true)"
git checkout -q -- debian debian.master debian.qcom-x1e 2>/dev/null || true

echo "=== [5/5] Ergebnis nach Windows kopieren"
D="$WINOUT/$KVER-$PKGREV"; mkdir -p "$D"
cp -f "$OUT"/rpmbuild/RPMS/*/*.rpm "$D/" 2>/dev/null || cp -f $(find "$OUT/rpmbuild" -name '*.rpm') "$D/"
cp -f arch/arm64/boot/vmlinuz.efi "$D/vmlinuz-$KVER.efi"
cp -f arch/arm64/boot/Image.gz "$D/Image.gz-$KVER"
cp -f arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13-exp.dtb arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus15.dtb "$D/"
cp -f .config "$D/config-$KVER"
(cd "$D" && sha256sum *.rpm *.dtb vmlinuz-*.efi > SHA256SUMS)
ls -la "$D"
echo "FERTIG: $D"
