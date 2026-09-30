#!/usr/bin/env bash
# Baut den Surface-Laptop-7-Kernel (ELLX-Tree, Tag 7.0.0-rc4-12) als arm64-.deb per Cross-Compile in WSL2.
# Aufruf (als root in WSL):  bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-build-kernel.sh"
# Umgebungsvariablen: TAG (Standard 7.0.0-rc4-12), PKGREV (Standard 1), NOBUILD=1 (nur konfigurieren)
set -euo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7
OUT=/work/sl7/out
WINOUT="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out"
TAG=${TAG:-7.0.0-rc4-12}
PKGREV=${PKGREV:-1}
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export KBUILD_BUILD_USER=martin KBUILD_BUILD_HOST=sl7-build
export LOCALVERSION=-sl7   # als Umgebungsvariable gesetzt -> setlocalversion haengt kein "+" an
J=$(nproc)
mkdir -p "$OUT" "$WINOUT"
cd "$K"

echo "=== [1/6] Arbeitszweig sl7-build auf Tag $TAG"
if [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" != "sl7-build" ]; then
  git -c advice.detachedHead=false checkout -q -B sl7-build "$TAG"
else
  echo "    bereits auf sl7-build (lokale Patches bleiben erhalten)"
fi
git log -1 --format='    %h %cd %s' --date=short
sed -n '2,5p' Makefile | tr '\n' ' '; echo

echo "=== [2/6] Community-Patches pruefen/anwenden"
# Nur die dwc3-Resume-Patches (USB nach Standby). Kamera-DT (0004) ist im Tag 7.0.0-rc4-12 schon enthalten,
# 0005 (Metadata) ist als Patchdatei defekt und ELLX hat ov02c10.c bereits angepasst.
sed -i 's/\r$//' /work/sl7/patches/community/outgoing/dwc3-usb/*.patch   # CRLF von Windows entfernen
for p in /work/sl7/patches/community/outgoing/dwc3-usb/*.patch; do
  [ -f "$p" ] || continue
  if patch -p1 -R --dry-run -s -f < "$p" >/dev/null 2>&1; then
    echo "    bereits enthalten: $(basename "$p")"
  elif patch -p1 -N --dry-run -s -f < "$p" >/dev/null 2>&1; then
    patch -p1 -N -s -f < "$p" && echo "    angewendet:        $(basename "$p")"
  else
    echo "    KONFLIKT/uebersprungen: $(basename "$p")"
  fi
done
grep -q "reinit-phy-on-resume" arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus.dtsi && echo "    dwc3 reinit-phy-on-resume: im DTS" || echo "    dwc3 reinit-phy-on-resume: FEHLT im DTS"
grep -q "Surface Laptop 7 Enumeration hack" drivers/net/wireless/ath/ath12k/core.c && echo "    rfkill-hack: im Tree" || echo "    rfkill-hack: FEHLT"
[ -d drivers/hid/spi-hid ] && echo "    spi-hid: im Tree" || echo "    spi-hid: FEHLT"

echo "=== [3/6] .config aus Ubuntu-Annotations (Flavour qcom-x1e)"
# 'make bindeb-pkg' ersetzt das Ubuntu-debian/-Verzeichnis durch ein eigenes -> aus git wiederherstellen
git checkout -q -- debian debian.master debian.qcom-x1e 2>/dev/null || true
if [ ! -f .config ] || [ "${RECONFIG:-0}" = "1" ]; then
  make -s mrproper
  git checkout -q -- debian debian.master debian.qcom-x1e 2>/dev/null || true
  python3 debian/scripts/misc/annotations --arch arm64 --flavour qcom-x1e --export > .config
  echo "    Optionen aus Annotations: $(grep -c '^CONFIG_' .config)"
  # Anpassungen fuer Build ausserhalb der Ubuntu-Packaging-Infrastruktur
  scripts/config --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS "" \
    --disable MODULE_SIG_FORCE \
    --disable DEBUG_INFO --disable DEBUG_INFO_DWARF5 --disable DEBUG_INFO_BTF --enable DEBUG_INFO_NONE \
    --set-str LOCALVERSION "" --disable LOCALVERSION_AUTO \
    --enable SPI_HID --module VIDEO_OV02C10 2>/dev/null || true
  make -s olddefconfig
else
  echo "    .config vorhanden -> wird weiterverwendet (RECONFIG=1 erzwingt Neuerzeugung)"
  make -s olddefconfig
fi
echo "    Kernel-Release: $(make -s kernelrelease)"
for o in ARCH_QCOM ATH12K SPI_HID HID_MULTITOUCH DRM_MSM VIDEO_OV02C10 SND_SOC_QCOM QCOM_PMIC_GLINK BATTERY_QCOM_BATTMGR EFI_ZBOOT MODULE_SIG MODULE_SIG_FORCE RUST DEBUG_INFO_NONE ARM64_4K_PAGES HZ_1000 PREEMPT_DYNAMIC ARM64_PSEUDO_NMI ENERGY_MODEL CPU_FREQ_DEFAULT_GOV_SCHEDUTIL MODULE_COMPRESS_ZSTD; do
  printf '    %-32s %s\n' "CONFIG_$o" "$(grep -E "^CONFIG_$o=" .config | cut -d= -f2 || echo '(nicht gesetzt)')"
done
if [ "${NOBUILD:-0}" = "1" ]; then echo "NOBUILD=1 -> Ende nach Konfiguration"; exit 0; fi

echo "=== [4/6] Build (make -j$J) -- Log: $OUT/build.log"
START=$(date +%s)
make -j"$J" Image.gz vmlinuz.efi modules dtbs 2>&1 | tee "$OUT/build.log" | grep -E "error|Error|warning: unmet|^  (LD|OBJCOPY)  .*(vmlinuz|Image)" || true
echo "    Build-Dauer: $(( ($(date +%s) - START) / 60 )) min"
ls -la arch/arm64/boot/Image.gz arch/arm64/boot/vmlinuz.efi arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb

echo "=== [5/6] Debian-Pakete (bindeb-pkg)"
KVER=$(make -s kernelrelease)
# DPKG_FLAGS=-d: keine Build-Dependency-Pruefung (die verlangt sonst libssl-dev:arm64 auf dem x86-Host)
# -j1: dtbs_install hat mit -j32 eine mkdir-Race-Condition (Kompilieren ist schon fertig, hier nur Paketieren)
rm -rf debian/linux-image-* debian/linux-headers-* debian/linux-libc-dev 2>/dev/null || true
make -j1 bindeb-pkg DPKG_FLAGS=-d KDEB_PKGVERSION="$(echo "$KVER" | sed 's/-rc/~rc/')-$PKGREV" 2>&1 | tee -a "$OUT/build.log" | grep -E "dpkg-deb|error" || true
mkdir -p "$OUT/$KVER-$PKGREV"
mv -f ../linux-*"$KVER"*.deb ../linux-*"$KVER"*.buildinfo ../linux-*"$KVER"*.changes "$OUT/$KVER-$PKGREV/" 2>/dev/null || true
cp -f arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus15.dtb .config "$OUT/$KVER-$PKGREV/"
cp -f .config "$OUT/$KVER-$PKGREV/config-$KVER"
ls -la "$OUT/$KVER-$PKGREV/"

echo "=== [6/6] Ergebnis nach Windows kopieren: $WINOUT/$KVER-$PKGREV"
mkdir -p "$WINOUT/$KVER-$PKGREV"
cp -f "$OUT/$KVER-$PKGREV"/* "$WINOUT/$KVER-$PKGREV/"
sha256sum "$WINOUT/$KVER-$PKGREV"/*.deb > "$WINOUT/$KVER-$PKGREV/SHA256SUMS"
git checkout -q -- debian debian.master debian.qcom-x1e 2>/dev/null || true   # Ubuntu-Packaging wiederherstellen

echo "=== [7/7] stubble-Image (Kernel + eingebettete DTBs mit SMBIOS-HWIDs, wie Ubuntus linux-qcom-x1e)"
PKGREV=$PKGREV bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-build-stubble.sh" | tail -4
echo "FERTIG."
