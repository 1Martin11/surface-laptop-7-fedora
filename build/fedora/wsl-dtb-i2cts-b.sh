#!/usr/bin/env bash
# Kernel B (Ubuntu 7.3 + ItsLucas): DTB-Variante romulus13-i2cts = ItsLucas-DT ohne GTCH-SPI-Touchscreen, dafuer I2C-Touchscreen (fQwQf).
set -euo pipefail; export LC_ALL=C
K=/work/sl7/kernel/ubuntu-7.3; export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
cd "$K"; D=arch/arm64/boot/dts/qcom
echo "--- ItsLucas romulus13.dts:"; cat $D/x1e80100-microsoft-romulus13.dts
# Variante: gtch-test-Include entfernen, I2C-Touchscreen anhaengen
sed -e 's|model = "Microsoft Surface Laptop 7 (13.8 inch)"|model = "Microsoft Surface Laptop 7 (13.8 inch) [SL7-Projekt: Touchscreen I2C]"|' \
  $D/x1e80100-microsoft-romulus13.dts > $D/x1e80100-microsoft-romulus13-i2cts.dts
grep -q 'interrupt-controller/irq.h' $D/x1e80100-microsoft-romulus13-i2cts.dts || sed -i '0,/^#include "x1e80100-microsoft-romulus.dtsi"/s||#include <dt-bindings/interrupt-controller/irq.h>\n#include "x1e80100-microsoft-romulus.dtsi"|' $D/x1e80100-microsoft-romulus13-i2cts.dts
cat >> $D/x1e80100-microsoft-romulus13-i2cts.dts <<'EOD'

/* SL7-Projekt: SPI-Touchscreen (GTCH) aus, stattdessen HID-over-I2C (ITCH MSHW0468, i2c8 @0x34) nach fQwQf, linux-input 2026-09-07 */
&gtch { status = "disabled"; };

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
		int-n-pins { pins = "gpio38"; function = "gpio"; drive-strength = <2>; bias-pull-up; };
		reset-n-pins { pins = "gpio31"; function = "gpio"; drive-strength = <2>; bias-disable; };
	};
};
EOD
grep -q 'romulus13-i2cts' $D/Makefile || sed -i 's|^dtb-\$(CONFIG_ARCH_QCOM)\s*+= x1e80100-microsoft-romulus13.dtb|&\ndtb-$(CONFIG_ARCH_QCOM)\t+= x1e80100-microsoft-romulus13-i2cts.dtb|' $D/Makefile
grep -n 'romulus13' $D/Makefile | head -5
make -s qcom/x1e80100-microsoft-romulus13-i2cts.dtb 2>&1 | grep -vi 'warning' | head -5 || true
ls -la $D/x1e80100-microsoft-romulus13-i2cts.dtb
T=$(dtc -I dtb -O dts $D/x1e80100-microsoft-romulus13-i2cts.dtb 2>/dev/null)
echo "    touchscreen@34=$(echo "$T" | grep -c 'touchscreen@34')  touchscreen@0(SPI)=$(echo "$T" | grep -c 'touchscreen@0 {')  touchpad@0=$(echo "$T" | grep -c 'touchpad@0')  gtch-power=$(echo "$T" | grep -c 'sl7-gtch-power')"
cp -f $D/x1e80100-microsoft-romulus13-i2cts.dtb "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora/out/7.3.0-rc3-sl7b-1/"
git add -A $D/x1e80100-microsoft-romulus13-i2cts.dts $D/Makefile; git -c user.email=a@b -c user.name=sl7 commit -q -m "romulus13-i2cts DTB-Variante" || true
echo fertig
