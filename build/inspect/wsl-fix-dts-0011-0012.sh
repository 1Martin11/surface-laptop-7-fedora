#!/usr/bin/env bash
# Stellt romulus13.dts sauber her: HEAD -> 0010 (Touchscreen i2c8) -> 0011-Block (Touchscreen spi10) -> 0012-Block (iris + Thermal),
# prueft die romulus.dtsi-Aenderungen (Touchpad-Wedge-Fix), baut den DTB testweise und sichert den Gesamt-Diff des Trees.
set -euo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7
P="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/patches-upstream"
Q="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/docs/quellen/x1e-nixos/surface-laptop-7-thermal.dts"
F=arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dts
D=arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus.dtsi
cd "$K"
git checkout -q -- debian debian.master debian.qcom-x1e 2>/dev/null || true

echo "=== [1] romulus13.dts auf HEAD, dann 0010 anwenden"
git checkout -q -- "$F"
sed 's/\r$//' "$P/0010-romulus13-touchscreen-hid-over-i2c.patch" | patch -p1 -N -s -f
grep -q 'touchscreen@34' "$F" && echo "    0010 ok ($(wc -l < "$F") Zeilen)"

echo "=== [2] romulus.dtsi: Touchpad-Wedge-Fix pruefen/anwenden"
if ! grep -q 'regulator-boot-on;' <(sed -n '/vreg_ts_5p0: ts-5p0-regulator/,/};/p' "$D"); then
  sed -i '/vreg_ts_5p0: ts-5p0-regulator {/,/};/ s|\t\tenable-active-high;|\t\tenable-active-high;\n\t\tregulator-boot-on;|' "$D"
fi
sed -i '/spi19_hid0_reset_deassert: /,/};/ s|pins = "gpio65", "gpio120";|pins = "gpio120";|' "$D"
sed -i '/spi19_hid0_reset_assert: /,/};/ s|pins = "gpio65", "gpio120";|pins = "gpio120";|' "$D"
sed -n '/vreg_ts_5p0: ts-5p0-regulator/,/};/p' "$D" | grep -c 'regulator-boot-on' | sed 's/^/    regulator-boot-on: /'
grep -n -A1 'spi19_hid0_reset_.*assert: ' "$D" | grep pins | sed 's/^/    /'

echo "=== [3] 0011-Block (Touchscreen spi10) anhaengen"
grep -q 'dt-bindings/dma/qcom-gpi.h' "$F" || sed -i 's|#include <dt-bindings/interrupt-controller/irq.h>|#include <dt-bindings/dma/qcom-gpi.h>\n#include <dt-bindings/interrupt-controller/irq.h>\n#include <dt-bindings/thermal/thermal.h>|' "$F"
cat >> "$F" <<'EOF'

/* Touchscreen (HID over SPI, ACPI GTCH / PNP0C51 an QUP_1_SE2 = spi10); Quellen: linux-surface#1590 (horizontblau 2026-08-25), orvitpng/nix1e touchscreen.dtsi */
/ {
	vreg_ts2_5p0: ts2-5p0-regulator {
		compatible = "regulator-fixed";
		regulator-name = "vreg_ts2_5p0";
		regulator-min-microvolt = <5000000>;
		regulator-max-microvolt = <5000000>;
		gpio = <&tlmm 64 GPIO_ACTIVE_HIGH>;
		enable-active-high;
		regulator-boot-on;
		startup-delay-us = <100000>;
	};
};

&gpi_dma1 {
	status = "okay";
};

&tlmm {
	qup_qspi10_data23: qup-qspi10-data23-state {
		pins = "gpio49", "gpio50";
		function = "qup1_se2";
		drive-strength = <6>;
		bias-disable;
	};

	spi10_hid0_reset_deassert: spi10-hid0-reset-deassert-state {
		pins = "gpio48";
		function = "gpio";
		drive-strength = <16>;
		bias-disable;
		output-high;
	};

	spi10_hid0_reset_assert: spi10-hid0-reset-assert-state {
		pins = "gpio48";
		function = "gpio";
		drive-strength = <16>;
		bias-disable;
		output-low;
	};

	spi10_hid0_int_bias: spi10-hid0-int-bias-state {
		pins = "gpio51";
		function = "gpio";
		input-enable;
		bias-pull-up;
	};
};

&spi10 {
	status = "okay";
	compatible = "qcom,geni-spi-qspi";
	spi-max-frequency = <40000000>;
	qcom,qspi-read-opcode = <0xEB>;
	qcom,qspi-read-dummy-clocks = <8>;
	qcom,qspi-read-cmd-bytes = <4>;

	pinctrl-0 = <&qup_spi10_data_clk>, <&qup_spi10_cs>,
		    <&qup_qspi10_data23>,
		    <&spi10_hid0_int_bias>;
	pinctrl-names = "default";

	dmas = <&gpi_dma1 0 2 QCOM_GPI_QSPI>,
	       <&gpi_dma1 1 2 QCOM_GPI_QSPI>;
	dma-names = "tx", "rx";

	touchscreen: touchscreen@0 {
		compatible = "hid-over-spi";
		reg = <0>;
		spi-max-frequency = <40000000>;

		interrupt-parent = <&tlmm>;
		interrupts = <51 IRQ_TYPE_LEVEL_LOW>;

		vdd-supply = <&vreg_ts2_5p0>;

		pinctrl-0 = <&spi10_hid0_reset_deassert>;
		pinctrl-1 = <&spi10_hid0_reset_assert>;
		pinctrl-names = "active", "reset";

		input-report-header-address = <0x1000>;
		input-report-body-address = <0x1004>;
		output-report-address = <0x2000>;
		read-opcode = <0xEB>;
		write-opcode = <0xE2>;
	};
};
EOF

echo "=== [4] 0012-Block (iris + CPU-Thermal) anhaengen"
{
  echo
  echo "/* Hardware-Videodecoder/-encoder (iris) mit Microsoft-Firmware qcvss8380.mbn (wie x1e80100-dell-*.dts; orvitpng/nix1e video.dtsi) */"
  echo "&iris {"
  echo "	firmware-name = \"qcom/x1e80100/microsoft/Romulus/qcvss8380.mbn\";"
  echo "	status = \"okay\";"
  echo "};"
  echo
  echo "/* CPU-Thermal-Drosselung: cpufreq-Cooling + passive Trips bei 85 C (5 C Hysterese); Vorbild scuggo/x1e-nixos surface-laptop-7-thermal.dts */"
  sed 's/\r$//' "$Q" | awk 'BEGIN{skip=1} /^&cpu0 /{skip=0} skip==0{print}'
} >> "$F"
echo "    romulus13.dts: $(wc -l < "$F") Zeilen"

echo "=== [5] DTB-Testbuild"
rm -f arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb
make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/x1e80100-microsoft-romulus13.dtb 2>&1 | grep -v -i 'warning' | head -20 || true
[ -s arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb ] || { echo "FEHLER: DTB nicht gebaut"; exit 1; }
DTS=$(dtc -I dtb -O dts arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb 2>/dev/null)
echo "    touchscreen@0: $(echo "$DTS" | grep -c 'touchscreen@0 {')  touchscreen@34: $(echo "$DTS" | grep -c 'touchscreen@34 {')  cooling-device: $(echo "$DTS" | grep -c 'cooling-device')  iris-firmware: $(echo "$DTS" | grep -c 'qcvss8380')"
ls -la arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb

echo "=== [6] Gesamt-Diff des Trees sichern (reproduzierbar): sl7-tree-full.diff"
git diff HEAD -- . ':(exclude)debian' ':(exclude)debian.master' ':(exclude)debian.qcom-x1e' > "$P/sl7-tree-full.diff"
git diff --stat HEAD -- . ':(exclude)debian' ':(exclude)debian.master' ':(exclude)debian.qcom-x1e' | tail -12
echo "    $(wc -l < "$P/sl7-tree-full.diff") Zeilen in sl7-tree-full.diff"
