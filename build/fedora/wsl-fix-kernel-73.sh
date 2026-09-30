#!/usr/bin/env bash
# Kernel B reparieren: linux-buildinfo (offizielle Ubuntu-generic-Config) holen, Tree auf base zuruecksetzen,
# nur ItsLucas 0001-0006 anwenden (dwc3-Community-Patches weglassen: 7.3 hat die dwc3-Knoten flach -> usb_mp_dwc3 fehlt),
# Config = buildinfo/config + ItsLucas-Tweaks (SPI_HID=m) + unsere Tweaks, DTB-Testbuild.
set -uo pipefail
export LC_ALL=C
S=/work/sl7/fedora/src; K=/work/sl7/kernel/ubuntu-7.3
P="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/gits/ItsLucas_surface-laptop-7-ubuntu-kernel/patches"
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
REL="https://github.com/ItsLucas/surface-laptop-7-ubuntu-kernel/releases/download/ubuntu-7.3.0-5.5-pa179322ad9e2ac22-r15.1"
echo "=== [1] linux-buildinfo holen"
cd "$S"
[ -f linux-buildinfo-7.3.0-5-generic_7.3.0-5.5_arm64.deb ] || curl -fsSL -o linux-buildinfo-7.3.0-5-generic_7.3.0-5.5_arm64.deb "$REL/linux-buildinfo-7.3.0-5-generic_7.3.0-5.5_arm64.deb"
[ -f RELEASE-SHA256SUMS ] || curl -fsSL -o RELEASE-SHA256SUMS "$REL/RELEASE-SHA256SUMS"
grep -E 'buildinfo|linux-source' RELEASE-SHA256SUMS | sha256sum -c - 2>&1 | sed 's/^/    /'
rm -rf buildinfo && mkdir buildinfo && dpkg-deb -x linux-buildinfo-7.3.0-5-generic_7.3.0-5.5_arm64.deb buildinfo
find buildinfo -type f | sed 's/^/    /'
CFG=$(find buildinfo -type f -name config | head -1); [ -n "$CFG" ] || { echo "keine config im buildinfo"; exit 1; }
echo "    Optionen: $(grep -c '^CONFIG_' "$CFG")  $(grep -E '^CONFIG_(GCC_VERSION|RUSTC_VERSION_TEXT)=' "$CFG" | tr '\n' ' ')"

echo "=== [2] Tree zuruecksetzen + ItsLucas-Serie"
cd "$K"; git reset -q --hard base; git clean -qfdx -e .config
apply() { local f=$1; sed 's/\r$//' "$f" > /tmp/p.patch
  if patch -p1 -N -s -f --fuzz=0 < /tmp/p.patch >/dev/null 2>&1; then echo "    ok        $(basename "$f")"; else echo "    FEHLER    $(basename "$f")"; patch -p1 -N --dry-run -f --fuzz=0 < /tmp/p.patch 2>&1 | grep -E 'FAILED|can.t find' | head -3; return 1; fi; }
apply "$P/0001-ath12k-romulus13-rfkill-workaround.patch"
apply "$P/variants/7.3/0002-romulus13-qspi-touchpad.patch"
apply "$P/0003-romulus13-gtch-spi-touchscreen.patch"
apply "$P/0004-spi-hid-power-lifecycle.patch"
apply "$P/0005-romulus13-gpio-panel-power.patch"
apply "$P/0006-revert-qrtr-register-only-hello.patch"
echo "--- Speaker-Limit in Ubuntu 7.3 vorhanden? $(grep -c 'snd_soc_limit_volume' sound/soc/qcom/x1e80100.c) Treffer in sound/soc/qcom/x1e80100.c"
grep -n -B1 -A2 'snd_soc_limit_volume' sound/soc/qcom/x1e80100.c | head -12 | sed 's/^/    /'
echo "--- dwc3 in 7.3: reinit-Handling upstream?"; grep -n -i 'reinit\|needs_full_reinit\|phy_power_off' drivers/usb/dwc3/core.c | head -6 | sed 's/^/    /'
git add -A >/dev/null 2>&1; git -c user.email=a@b -c user.name=sl7 commit -q -m "ItsLucas 0001-0006 (r15.1)" 2>/dev/null; git tag -f sl7b >/dev/null 2>&1
git diff --stat base HEAD | tail -1

echo "=== [3] Config aus buildinfo + Tweaks"
cp "$S/$CFG" .config
scripts/config --module SPI_HID --module VIDEO_QCOM_IRIS \
  --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS "" --disable MODULE_SIG_FORCE --disable MODULE_SIG_ALL \
  --disable DEBUG_INFO --disable DEBUG_INFO_DWARF5 --disable DEBUG_INFO_BTF --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT --enable DEBUG_INFO_NONE \
  --set-str LOCALVERSION "" --disable LOCALVERSION_AUTO --disable RUST 2>/dev/null
LOCALVERSION=-sl7b make -s olddefconfig 2>&1 | tail -2
echo "    Kernel-Release: $(LOCALVERSION=-sl7b make -s kernelrelease)"
for o in SPI_HID ATH12K DRM_MSM VIDEO_QCOM_IRIS BATTERY_QCOM_BATTMGR QCOM_CPUCP_MBOX ARM_SCMI_CPUFREQ EFI_ZBOOT SQUASHFS SQUASHFS_ZSTD EROFS_FS OVERLAY_FS SURFACE_AGGREGATOR SND_SOC_WSA884X MODULE_SIG MODULE_COMPRESS_ZSTD RUST; do printf '    %-22s %s\n' "$o" "$(grep -E "^CONFIG_$o=" .config | cut -d= -f2 || echo -)"; done
diff <(grep '^CONFIG_' "$S/$CFG" | sort) <(grep '^CONFIG_' .config | sort) | grep '^[<>]' | wc -l | sed 's/^/    Config-Abweichungen ggue. Ubuntu generic: /'
echo "=== [4] DTB-Testbuild romulus13"
make -s qcom/x1e80100-microsoft-romulus13.dtb 2>&1 | grep -vi warning | head -8
ls -la arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb 2>/dev/null
T=$(dtc -I dtb -O dts arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb 2>/dev/null)
echo "    touchscreen@0=$(echo "$T" | grep -c 'touchscreen@0 {')  touchpad@0=$(echo "$T" | grep -c 'touchpad@0 {')  hid-over-spi=$(echo "$T" | grep -c 'hid-over-spi')  panel-power=$(echo "$T" | grep -ci 'panel')"
echo "=== fertig"
