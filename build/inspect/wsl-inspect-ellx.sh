#!/usr/bin/env bash
# Inspiziert den ELLX-Kernel-Tree: Packaging, Config, SL7-spezifische Aenderungen.
set -uo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7
cd "$K" || exit 1
echo "=== Makefile-Version"; head -5 Makefile
echo "=== Top-Level"; ls
echo "=== debian dirs"; ls -d debian* 2>/dev/null
echo "=== debian.master? / debian.qcom-x1e?"; ls debian.* 2>/dev/null | head -40
echo "=== debian/debian.env"; cat debian/debian.env 2>/dev/null
echo "=== debian/changelog (Kopf)"; head -12 debian/changelog 2>/dev/null
for d in debian.*; do
  [ -f "$d/changelog" ] && { echo "=== $d/changelog (Kopf)"; head -8 "$d/changelog"; }
  [ -d "$d/config" ] && { echo "=== $d/config"; ls "$d/config"; ls "$d/config"/* 2>/dev/null | head -20; }
  [ -f "$d/rules.d/arm64.mk" ] && { echo "=== $d/rules.d/arm64.mk"; cat "$d/rules.d/arm64.mk"; }
  [ -d "$d/rules.d" ] && { echo "=== $d/rules.d"; ls "$d/rules.d"; }
done
echo "=== .github workflows"; ls .github/workflows 2>/dev/null && for f in .github/workflows/*; do echo "--- $f"; cat "$f"; done
echo "=== SL7-relevante Treiber-Dateien"
ls drivers/hid/spi-hid 2>/dev/null && echo "spi-hid: vorhanden" || echo "spi-hid: FEHLT"
grep -n "return 0;" drivers/net/wireless/ath/ath12k/core.c | head -3
grep -n "rfkill" drivers/net/wireless/ath/ath12k/core.c | head -8
grep -rn "reinit-phy-on-resume\|reinit_phy_on_resume" drivers/usb/dwc3/*.c Documentation/devicetree/bindings/usb/snps,dwc3*.yaml 2>/dev/null | head -5
grep -n "ov02c10\|OV02C10" arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus.dtsi | head -5
grep -n "compatible\|model" arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dts | head -6
echo "=== romulus.dtsi Knoten (Ueberblick)"
grep -nE "^\s*&[a-z0-9_]+ \{|compatible = " arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus.dtsi | head -80
echo "=== Diff-Statistik zum Concept-Tree (wenn vorhanden)"
C=/work/sl7/kernel/concept-qcom-x1e-7.0
if [ -d "$C" ]; then diff -rq "$C" "$K" -x .git 2>/dev/null | grep -v "^Only in $C" | head -60; fi
