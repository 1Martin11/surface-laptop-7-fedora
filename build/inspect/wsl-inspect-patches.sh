#!/usr/bin/env bash
# Prueft, welche Community-Patches im ELLX-Tag schon enthalten sind, und was ELLX gegenueber dem Concept-Tree aendert.
set -uo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7
C=/work/sl7/kernel/concept-qcom-x1e-7.0
cd "$K" || exit 1
echo "=== HEAD"; git log -1 --format='%h %cd %s' --date=short
echo "=== Concept-Tree"; git -C "$C" log -1 --format='%h %cd %s' --date=short; sed -n '2,5p' "$C/Makefile" | tr '\n' ' '; echo; head -3 "$C/debian.qcom-x1e/changelog"
echo
echo "=== dwc3 reinit-phy-on-resume im Tag?"
grep -n "reinit.phy.on.resume\|reinit_phy_on_resume" drivers/usb/dwc3/core.c drivers/usb/dwc3/core.h arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus.dtsi Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml 2>/dev/null | head
echo "=== ov02c10 im romulus.dtsi?"
grep -n -i "ov02c10\|camera\|cci\|camss" arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus.dtsi | head -12
echo "=== ov02c10.c: Metadata-Patch (0005) Merkmale?"
grep -n "V4L2_CID\|metadata\|MEDIA_PAD_FL_META\|embedded" drivers/media/i2c/ov02c10.c | head -8
echo
echo "=== patch --dry-run der Community-Patches"
for p in /work/sl7/patches/community/outgoing/dwc3-usb/*.patch /work/sl7/patches/community/outgoing/ov02c10/*.patch; do
  echo "--- $(basename "$p")"
  patch -p1 --dry-run -N -F3 < "$p" 2>&1 | tail -6
done
echo
echo "=== ELLX-Tag vs Concept-Tree: geaenderte Dateien (ohne debian/, Documentation, tools)"
diff -rq "$C" "$K" -x .git -x debian -x debian.master -x debian.qcom-x1e 2>/dev/null | grep -vE "^Only in $C" | sed "s|$C/||; s|$K/||" | head -60
echo "=== Anzahl Unterschiede gesamt: $(diff -rq "$C" "$K" -x .git 2>/dev/null | wc -l)"
echo
echo "=== spi-hid im Concept-Tree?"; ls "$C/drivers/hid/spi-hid" 2>/dev/null && echo ja || echo nein
echo "=== rfkill-hack im Concept-Tree?"; grep -c "Enumeration hack" "$C/drivers/net/wireless/ath/ath12k/core.c"
