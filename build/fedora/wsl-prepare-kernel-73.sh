#!/usr/bin/env bash
# Kernel B vorbereiten: Ubuntu-26.10-Quelle (linux-source-7.3.0 aus dem ItsLucas-Release) entpacken, ItsLucas-Patches
# (0001, variants/7.3/0002, 0003-0005, 0006 wenn anwendbar) + unser Speaker-Limit anwenden, Config aus den Ubuntu-Annotations
# (Flavour generic, arm64) exportieren, DTB testbauen. Kein voller Build hier.
set -uo pipefail
export LC_ALL=C
S=/work/sl7/fedora/src; K=/work/sl7/kernel/ubuntu-7.3
P="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/gits/ItsLucas_surface-laptop-7-ubuntu-kernel/patches"
U="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/patches-upstream"
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
if [ ! -f "$K/Makefile" ]; then
  echo "=== [1] Quelle entpacken"
  mkdir -p "$S/deb" && dpkg-deb -x "$S"/linux-source-7.3.0_*.deb "$S/deb"
  TB=$(find "$S/deb" -name 'linux-source-7.3.0.tar.bz2' | head -1); ls -la "$TB"
  mkdir -p "$K"; START=$(date +%s); tar -xjf "$TB" -C "$K" --strip-components=1; echo "    entpackt in $(( $(date +%s) - START ))s"
fi
cd "$K"
echo "=== Version: $(sed -n '2,5p' Makefile | tr '\n' ' ')"
ls debian* -d 2>/dev/null; cat debian/debian.env 2>/dev/null
git init -q 2>/dev/null; git add -A >/dev/null 2>&1; git -c user.email=a@b -c user.name=sl7 commit -q -m "Ubuntu linux-source 7.3.0-5.5 (unveraendert)" 2>/dev/null; git tag -f base >/dev/null 2>&1

echo "=== [2] Patches"
apply() { local f=$1; sed 's/\r$//' "$f" > /tmp/p.patch
  if patch -p1 -N --dry-run -s -f --fuzz=0 < /tmp/p.patch >/dev/null 2>&1; then patch -p1 -N -s -f --fuzz=0 < /tmp/p.patch && echo "    ok        $(basename "$f")"
  elif patch -p1 -R --dry-run -s -f < /tmp/p.patch >/dev/null 2>&1; then echo "    schon drin $(basename "$f")"
  else echo "    KONFLIKT  $(basename "$f")"; patch -p1 -N --dry-run -f --fuzz=0 < /tmp/p.patch 2>&1 | grep -E 'FAILED|Hunk|can.t find' | head -4 | sed 's/^/        /'; fi; }
apply "$P/0001-ath12k-romulus13-rfkill-workaround.patch"
apply "$P/variants/7.3/0002-romulus13-qspi-touchpad.patch"
apply "$P/0003-romulus13-gtch-spi-touchscreen.patch"
apply "$P/0004-spi-hid-power-lifecycle.patch"
apply "$P/0005-romulus13-gpio-panel-power.patch"
echo "--- 0006 (QRTR-Revert) nur wenn der problematische Upstream-Commit enthalten ist:"
if grep -q 'qrtr_node_assign\|HELLO' net/qrtr/af_qrtr.c && patch -p1 -N --dry-run -s -f --fuzz=0 < <(sed 's/\r$//' "$P/0006-revert-qrtr-register-only-hello.patch") >/dev/null 2>&1; then apply "$P/0006-revert-qrtr-register-only-hello.patch"; else echo "    0006 nicht anwendbar/noetig"; fi
echo "--- unser Speaker-Limit:"; apply "$U/ubuntu-speaker-limit.patch"
echo "--- dwc3 reinit-phy-on-resume (Community) - in 7.3 evtl. durch upstream needs_full_reinit abgedeckt:"
for f in /work/sl7/patches/community/outgoing/dwc3-usb/000{1,2,3}-*.patch; do apply "$f"; done
git add -A >/dev/null 2>&1; git -c user.email=a@b -c user.name=sl7 commit -q -m "SL7-Patches (ItsLucas 0001-0006 + Speaker-Limit + dwc3)" 2>/dev/null
git diff --stat base HEAD | tail -1

echo "=== [3] Config (Ubuntu generic arm64 aus Annotations)"
python3 debian/scripts/misc/annotations --arch arm64 --flavour generic --export > .config 2>/tmp/ann.err || { tail -3 /tmp/ann.err; }
echo "    Optionen: $(grep -c '^CONFIG_' .config)"
scripts/config --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS "" --disable MODULE_SIG_FORCE \
  --disable DEBUG_INFO --disable DEBUG_INFO_DWARF5 --disable DEBUG_INFO_BTF --enable DEBUG_INFO_NONE \
  --set-str LOCALVERSION "" --disable LOCALVERSION_AUTO --module SPI_HID --module VIDEO_OV02C10 --module VIDEO_QCOM_IRIS 2>/dev/null || true
LOCALVERSION=-sl7b make -s olddefconfig 2>&1 | tail -2
echo "    Kernel-Release: $(LOCALVERSION=-sl7b make -s kernelrelease)"
for o in SPI_HID ATH12K DRM_MSM VIDEO_QCOM_IRIS BATTERY_QCOM_BATTMGR QCOM_CPUCP_MBOX ARM_SCMI_CPUFREQ EFI_ZBOOT SQUASHFS SQUASHFS_ZSTD EROFS_FS OVERLAY_FS SURFACE_AGGREGATOR SND_SOC_WSA884X; do printf '    %-22s %s\n' "$o" "$(grep -E "^CONFIG_$o=" .config | cut -d= -f2 || echo -)"; done
echo "=== [4] DTB-Testbuild romulus13"
make -s qcom/x1e80100-microsoft-romulus13.dtb 2>&1 | grep -vi warning | head -8
ls -la arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb 2>/dev/null
T=$(dtc -I dtb -O dts arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb 2>/dev/null)
echo "    touchscreen@0=$(echo "$T" | grep -c 'touchscreen@0 {')  touchpad@0=$(echo "$T" | grep -c 'touchpad@0 {')  surface-sam=$(echo "$T" | grep -c surface-sam)  domain_ss3=$(echo "$T" | grep -c 'domain-ss3\|domain_ss3')"
echo "=== fertig ($K)"
