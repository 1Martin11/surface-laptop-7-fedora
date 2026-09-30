#!/usr/bin/env bash
# Kernel-Tree fuer das Fedora-ISO neu aufsetzen: ELLX-Tag + KONSERVATIVER Patch-Satz (dwc3-Resume, Speaker-Limit,
# hamoa-USB-PHY-Fix) fuer den Standard-DTB romulus13, plus ein zweiter, EXPERIMENTELLER DTB
# x1e80100-microsoft-romulus13-exp.dtb (Touchscreen spi10, Touchpad-Reset-Fix, iris-Video, CPU-Thermal-Trips)
# als eigene dts-Datei. Ein Kernel, zwei DTBs, im Bootmenue waehlbar. Nur DTB-Testbuild, kein voller Kernel-Build.
set -euo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7
P="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/patches-upstream"
C="/work/sl7/patches/community/outgoing/dwc3-usb"
Q="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/docs/quellen/x1e-nixos/surface-laptop-7-thermal.dts"
TAG=7.0.0-rc4-12
cd "$K"
echo "=== [1] Tree auf Tag $TAG zuruecksetzen (alle lokalen Aenderungen verwerfen)"
git checkout -q -- . 2>/dev/null || true
git clean -q -fd arch/arm64/boot/dts 2>/dev/null || true
git -c advice.detachedHead=false checkout -q -B sl7-fedora "$TAG"
git checkout -q -- debian debian.master debian.qcom-x1e
sed -n '2,5p' Makefile | tr '\n' ' '; echo

echo "=== [2] Konservativer Patch-Satz"
apply() { local f=$1; sed 's/\r$//' "$f" > /tmp/p.patch; patch -p1 -N -s -f < /tmp/p.patch && echo "    ok  $(basename "$f")"; }
for f in "$C"/0001-*.patch "$C"/0002-*.patch "$C"/0003-*.patch; do apply "$f"; done
apply "$P/ubuntu-speaker-limit.patch"
apply "$P/hamoa-usb-qmp-phy-supplies-romulus-only.patch"
git diff --stat | tail -1

echo "=== [3] Experimenteller DTB als eigene Datei"
DTS=arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13-exp.dts
cat > "$DTS" <<'EOF'
// SPDX-License-Identifier: BSD-3-Clause
/*
 * Surface Laptop 7 (13.8 inch) - EXPERIMENTELLE Variante fuer das Projekt Linux SL7.
 * Identisch mit x1e80100-microsoft-romulus13.dts plus:
 *  - Touchscreen als HID-over-SPI auf spi10 (QUP1 SE2, QSPI) nach linux-surface#1590 / orvitpng/nix1e
 *  - Touchpad: Regulator vreg_ts_5p0 boot-on, Reset-States nur gpio120 (horizontblau 2026-08-29)
 *  - iris Hardware-Videodecoder mit Microsoft-Firmware qcvss8380.mbn
 *  - CPU-Thermal-Drosselung (passive Trips 85 C) nach scuggo/x1e-nixos
 * Wird im Bootmenue als eigener Eintrag angeboten. Standard bleibt der unveraenderte romulus13-DTB.
 */

/dts-v1/;

#include <dt-bindings/dma/qcom-gpi.h>
#include <dt-bindings/interrupt-controller/irq.h>
#include <dt-bindings/thermal/thermal.h>
#include "x1e80100-microsoft-romulus.dtsi"

/ {
	model = "Microsoft Surface Laptop 7 (13.8 inch) [SL7-Projekt experimentell]";
	compatible = "microsoft,romulus13", "qcom,x1e80100";

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

/* Touchpad-Aufraeumen: ein Pin, ein Besitzer */
&vreg_ts_5p0 {
	regulator-boot-on;
};

&spi19_hid0_reset_deassert {
	pins = "gpio120";
};

&spi19_hid0_reset_assert {
	pins = "gpio120";
};

/* Touchscreen (HID over SPI, ACPI GTCH / PNP0C51 an QUP_1_SE2 = spi10) */
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

/* Hardware-Videodecoder/-encoder (iris) */
&iris {
	firmware-name = "qcom/x1e80100/microsoft/Romulus/qcvss8380.mbn";
	status = "okay";
};

/* CPU-Thermal-Drosselung: cpufreq-Cooling + passive Trips bei 85 C */
EOF
sed 's/\r$//' "$Q" | awk 'BEGIN{skip=1} /^&cpu0 /{skip=0} skip==0{print}' >> "$DTS"
echo "    $DTS: $(wc -l < "$DTS") Zeilen"
# In das Makefile eintragen (direkt hinter romulus13)
MK=arch/arm64/boot/dts/qcom/Makefile
grep -q 'x1e80100-microsoft-romulus13-exp.dtb' "$MK" || sed -i 's|^\(dtb-\$(CONFIG_ARCH_QCOM)\s*+= x1e80100-microsoft-romulus13.dtb\)|\1\ndtb-$(CONFIG_ARCH_QCOM)\t+= x1e80100-microsoft-romulus13-exp.dtb|' "$MK"
grep -n 'romulus13' "$MK"

echo "=== [4] DTB-Testbuild beider Varianten"
make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/x1e80100-microsoft-romulus13.dtb qcom/x1e80100-microsoft-romulus13-exp.dtb 2>&1 | grep -vi warning | head -10 || true
for d in romulus13 romulus13-exp; do
  F=arch/arm64/boot/dts/qcom/x1e80100-microsoft-$d.dtb
  [ -s "$F" ] || { echo "FEHLER: $F fehlt"; exit 1; }
  T=$(dtc -I dtb -O dts "$F" 2>/dev/null)
  printf '    %-16s %7s Bytes  touchscreen@0=%s  cooling-device=%s  qcvss=%s  model=%s\n' "$d" "$(stat -c %s "$F")" "$(echo "$T" | grep -c 'touchscreen@0 {')" "$(echo "$T" | grep -c cooling-device)" "$(echo "$T" | grep -c qcvss8380)" "$(echo "$T" | grep -m1 'model =' | cut -d'"' -f2)"
done

echo "=== [5] Patch-Staende sichern"
git diff HEAD -- . ':(exclude)debian' ':(exclude)debian.master' ':(exclude)debian.qcom-x1e' ':(exclude)arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13-exp.dts' ':(exclude)arch/arm64/boot/dts/qcom/Makefile' > "$P/sl7-tree-safe.diff"
cp "$DTS" "$P/x1e80100-microsoft-romulus13-exp.dts"
git diff HEAD -- "$MK" > "$P/sl7-makefile-exp-dtb.diff"
echo "    sl7-tree-safe.diff: $(wc -l < "$P/sl7-tree-safe.diff") Zeilen, $(grep -c '^diff --git' "$P/sl7-tree-safe.diff") Dateien"
echo "    x1e80100-microsoft-romulus13-exp.dts + sl7-makefile-exp-dtb.diff gesichert"
echo "=== fertig (Zweig sl7-fedora)"
