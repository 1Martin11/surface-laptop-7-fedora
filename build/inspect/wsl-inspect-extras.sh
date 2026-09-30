#!/usr/bin/env bash
# Stoppt laufende Builds und prueft: Thermal-Cooling, SAM-EC-Knoten, iris-Videoknoten im ELLX-Tree.
set -uo pipefail
export LC_ALL=C
pkill -f wsl-build-kernel.sh 2>/dev/null; pkill -f wsl-build-rev3.sh 2>/dev/null; pkill -f 'make -j' 2>/dev/null; sleep 1
pgrep -fa 'make|dpkg-buildpackage' | grep -v pgrep | head -3 || true
cd /work/sl7/kernel/ellx-7.0-sl7/arch/arm64/boot/dts/qcom
echo "=== thermal-zones (hamoa.dtsi): top-thermal-Zonen: $(grep -c 'top-thermal' hamoa.dtsi), cooling-cells: $(grep -c 'cooling-cells' hamoa.dtsi), cooling-maps: $(grep -c 'cooling-maps' hamoa.dtsi), passive-Trips: $(grep -c 'type = "passive"' hamoa.dtsi)"
grep -n 'cpu0-0-top-thermal\|cpu0-top-thermal\|cpu0_thermal\|cpu-thermal' hamoa.dtsi | head -3
grep -n -A12 'cpu0-0-top-thermal {' hamoa.dtsi | head -16
echo "=== surface-sam in romulus.dtsi:"
grep -n -B4 -A8 'surface-sam' x1e80100-microsoft-romulus.dtsi | head -24
echo "=== iris in hamoa.dtsi:"
grep -n 'iris: \|iris {\|iris@\|qcom,x1e80100-iris\|qcom,sm8550-iris\|video-codec@' hamoa.dtsi | head -5
grep -n -A4 '&iris' x1e80100-microsoft-romulus.dtsi x1e80100-*.dts x1-*.dtsi 2>/dev/null | head -20
echo "=== iris firmware-name Beispiele anderer Boards:"
grep -rn -B1 -A2 '&iris {' x1e80100-*.dts x1-*.dtsi x1e80100-*.dtsi 2>/dev/null | grep -i 'firmware\|iris' | head -10
echo "=== Config:"
grep -E '^CONFIG_VIDEO_QCOM_(IRIS|VENUS)|^CONFIG_THERMAL_GOV|^CONFIG_CPU_THERMAL|^CONFIG_QCOM_TSENS|^CONFIG_QCOM_LMH' /work/sl7/kernel/ellx-7.0-sl7/.config
echo "=== git status (Arbeitsbaum):"; cd /work/sl7/kernel/ellx-7.0-sl7 && git status --short | grep -v '^??' | head
