#!/usr/bin/env bash
# Kernel A (ellx-7.0-sl7, Zweig sl7-fedora): dritte DTB-Variante romulus13-i2cts = konservativer DT + I2C-Touchscreen (fQwQf, 2026-09-07).
set -euo pipefail; export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7; export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
cd "$K"; [ "$(git rev-parse --abbrev-ref HEAD)" = sl7-fedora ] || { echo "nicht auf sl7-fedora"; exit 1; }
D=arch/arm64/boot/dts/qcom
cat > $D/x1e80100-microsoft-romulus13-i2cts.dts <<'EOD'
// SPDX-License-Identifier: BSD-3-Clause
/*
 * SL7-Projekt, Variante "i2cts": konservativer Romulus13-DT + Touchscreen als HID-over-I2C (ITCH MSHW0468, i2c8 @0x34).
 * Quelle: fQwQf, "[PATCH] arm64: dts: qcom: microsoft-romulus13: enable touchscreen" (linux-input, 2026-09-07),
 * "verified working on this machine". Alternative zur SPI-Variante (ItsLucas/Kernel B) - je nach Panel-Lieferant.
 */
/dts-v1/;
#include <dt-bindings/interrupt-controller/irq.h>
#include "x1e80100-microsoft-romulus.dtsi"

/ {
	model = "Microsoft Surface Laptop 7 (13.8 inch) [SL7-Projekt: Touchscreen I2C]";
	compatible = "microsoft,romulus13", "qcom,x1e80100";
};

&i2c8 {
	clock-frequency = <400000>;
	status = "okay";

	touchscreen@34 {
		compatible = "hid-over-i2c";
		reg = <0x34>;
		hid-descr-addr = <0x0000>;
		interrupts-extended = <&tlmm 38 IRQ_TYPE_LEVEL_LOW>;
		reset-gpios = <&tlmm 31 GPIO_ACTIVE_LOW>;
		pinctrl-0 = <&ts_i2c_default>;
		pinctrl-names = "default";
	};
};

&tlmm {
	ts_i2c_default: ts-i2c-default-state {
		int-n-pins {
			pins = "gpio38";
			function = "gpio";
			drive-strength = <2>;
			bias-pull-up;
		};
		reset-n-pins {
			pins = "gpio31";
			function = "gpio";
			drive-strength = <2>;
			bias-disable;
		};
	};
};
EOD
# Touchpad-Overrides wie in der exp-Variante uebernehmen (Regulator boot-on, Reset-Pin), falls in der safe-DTS nicht enthalten
grep -q 'romulus13-i2cts' $D/Makefile || sed -i 's|^dtb-\$(CONFIG_ARCH_QCOM)\s*+= x1e80100-microsoft-romulus13-exp.dtb|&\ndtb-$(CONFIG_ARCH_QCOM)\t+= x1e80100-microsoft-romulus13-i2cts.dtb|' $D/Makefile
grep -n 'romulus13' $D/Makefile
make -s qcom/x1e80100-microsoft-romulus13-i2cts.dtb 2>&1 | grep -vi 'warning' | head -5 || true
ls -la $D/x1e80100-microsoft-romulus13-i2cts.dtb
T=$(dtc -I dtb -O dts $D/x1e80100-microsoft-romulus13-i2cts.dtb 2>/dev/null)
echo "    touchscreen@34=$(echo "$T" | grep -c 'touchscreen@34')  hid-over-i2c=$(echo "$T" | grep -c 'hid-over-i2c')  touchpad@0=$(echo "$T" | grep -c 'touchpad@0')  model: $(echo "$T" | grep -m1 'model =')"
cp -f $D/x1e80100-microsoft-romulus13-i2cts.dtb "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora/out/7.0.0-rc4-sl7-1/"
cp -f $D/x1e80100-microsoft-romulus13-i2cts.dts "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/patches-upstream/"
git add -A $D/x1e80100-microsoft-romulus13-i2cts.dts $D/Makefile; git -c user.email=a@b -c user.name=sl7 commit -q -m "romulus13-i2cts DTB-Variante (fQwQf I2C-Touchscreen)" || true
echo fertig
