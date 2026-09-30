#!/usr/bin/env bash
# Wendet die zusaetzlichen Patches (build/patches-upstream) auf den ELLX-Arbeitszweig an:
#   - 0010 Touchscreen romulus13 (hid-over-i2c @0x34, linux-input 2026-09-07, + pinctrl)
#   - hamoa USB-QMP-PHY-Supply-Fix (upstream 4458dcd, 2026-08-03), nur romulus.dtsi-Hunk
#   - ubuntu-speaker-limit.patch (SAUCE: ASoC: qcom: x1e80100: limit speaker volumes), falls vorhanden
# Danach: bash wsl-build-kernel.sh (inkrementell) fuer neue Pakete + stubble-Image.
set -uo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7
P="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/patches-upstream"
cd "$K" || exit 1
git checkout -q -- debian debian.master debian.qcom-x1e 2>/dev/null || true
apply() {
  local f=$1
  [ -f "$f" ] || { echo "    (fehlt) $(basename "$f")"; return; }
  sed 's/\r$//' "$f" > /tmp/p.patch
  if patch -p1 -R --dry-run -s -f < /tmp/p.patch >/dev/null 2>&1; then echo "    bereits drin: $(basename "$f")"
  elif patch -p1 -N --dry-run -s -f < /tmp/p.patch >/dev/null 2>&1; then patch -p1 -N -s -f < /tmp/p.patch && echo "    angewendet:   $(basename "$f")"
  else echo "    KONFLIKT:     $(basename "$f")"; patch -p1 -N --dry-run -f < /tmp/p.patch 2>&1 | tail -4 | sed 's/^/        /'; fi
}
echo "=== Patches anwenden"
apply "$P/0010-romulus13-touchscreen-hid-over-i2c.patch"
apply "$P/hamoa-usb-qmp-phy-supplies-romulus-only.patch"
apply "$P/ubuntu-speaker-limit.patch"
# Touchscreen spi10 / iris / Thermal: siehe sl7-tree-full.diff (wsl-apply-sl7-patches.sh)
echo "=== DTB-Testbuild (romulus13)"
make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/x1e80100-microsoft-romulus13.dtb 2>&1 | grep -vi 'warning' | head -20
ls -la arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb
echo "--- Touchscreen-Knoten im DTB:"
dtc -I dtb -O dts arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb 2>/dev/null | grep -n -A8 'touchscreen@34' | head -12
echo "--- USB-PHY-Supplies (ss0):"
dtc -I dtb -O dts arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb 2>/dev/null | grep -n -B2 -A6 'phy@fd5000\|vdda-phy-supply' | head -20
echo "=== git diff --stat"
git diff --stat | tail -8
