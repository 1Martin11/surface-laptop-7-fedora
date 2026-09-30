#!/usr/bin/env bash
# Reproduzierbarer Patch-Stand: frischer Checkout des ELLX-Tags und Anwendung des Gesamt-Diffs
# build/patches-upstream/sl7-tree-full.diff (enthaelt: dwc3-Resume 0001-0003, Ubuntu-Speaker-Limit,
# hamoa-USB-PHY-Fix (romulus), Touchscreen i2c8 (0010) + spi10, Touchpad-Wedge-Fix, iris-Video, CPU-Thermal).
# Aufruf (als root in WSL):  bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-apply-sl7-patches.sh"
# Danach:  PKGREV=<n> bash .../wsl-build-kernel.sh
set -euo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7
P="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/patches-upstream"
TAG=${TAG:-7.0.0-rc4-12}
cd "$K"
echo "=== frischer Stand: Tag $TAG (lokale Aenderungen werden verworfen!)"
git checkout -q -- . 2>/dev/null || true
git clean -q -fd arch/arm64/boot/dts 2>/dev/null || true
git -c advice.detachedHead=false checkout -q -B sl7-build "$TAG"
git checkout -q -- debian debian.master debian.qcom-x1e
echo "=== sl7-tree-full.diff anwenden"
sed 's/\r$//' "$P/sl7-tree-full.diff" > /tmp/sl7-tree-full.diff
git apply --check /tmp/sl7-tree-full.diff && git apply /tmp/sl7-tree-full.diff
git diff --stat | tail -8
echo "=== DTB-Test"
make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/x1e80100-microsoft-romulus13.dtb 2>&1 | grep -vi warning | head -5 || true
ls -la arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb
echo "OK - jetzt: PKGREV=<n> bash wsl-build-kernel.sh"
