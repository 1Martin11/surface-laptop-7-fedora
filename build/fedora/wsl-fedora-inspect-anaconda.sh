#!/usr/bin/env bash
# Nur lesen: Anaconda-Live-Install-Verhalten (Kernel-Liste, BLS, Bootargs), DTB-Ablage der Fedora-Kernel, ISO-Boot-Ausruestung.
set -uo pipefail; export LC_ALL=C
R=/work/sl7/fedora/rootfs; A="$R/usr/lib64/python3.14/site-packages/pyanaconda"; ISO=/work/sl7/fedora/iso/Fedora-KDE-Desktop-Live-44-1.7.aarch64.iso
echo "=== [A] Anaconda: kernel-install / BLS / Kernelversionen"
grep -rn 'kernel-install\|loader/entries\|new-kernel-pkg' "$A" --include=*.py | grep -v '^\s*#' | head -20
echo "--- get_kernel_version_list:"; grep -rn 'def get_kernel_version_list' -A 30 "$A"/core/kernel.py "$A"/*.py "$A"/modules/*/*.py 2>/dev/null | grep -v '^\s*$' | head -45
echo "--- Live-Payload post-install (Tasks):"; grep -rn 'class .*Task\b\|class .*Task(' "$A"/modules/payloads/payload/live_os/installation.py "$A"/modules/payloads/base/installation.py "$A"/modules/payloads/installation.py 2>/dev/null | head -20
echo "--- initrd/dracut:"; grep -rn 'dracut\|initrd' "$A"/modules/payloads/payload/live_os/*.py "$A"/modules/payloads/base/*.py "$A"/modules/payloads/installation.py 2>/dev/null | grep -v '^\s*#' | head -15
echo "--- Bootloader-Args aus Live-Cmdline uebernommen (preserve):"; grep -rn 'preserve\|_preserved_boot_args\|boot_args\b' "$A"/modules/storage/bootloader/base.py 2>/dev/null | head -12; grep -rn '"modprobe.blacklist"\|rd.driver\|"inst\.' "$A"/modules/storage/bootloader/*.py "$A"/core/kernel.py 2>/dev/null | head -8
echo "--- Denylist-Task:"; sed -n '55,90p' "$A/modules/payloads/installation.py"
echo "--- BLS-Update:"; grep -rn -i 'bls' "$A"/modules/payloads/installation.py "$A"/modules/payloads/base/installation.py "$A"/modules/payloads/payload/live_os/installation.py "$A"/modules/storage/bootloader/installation.py 2>/dev/null | head -12
F=$(grep -rln 'class UpdateBLS\|def update_bls\|_update_bls' "$A" 2>/dev/null | head -1); echo "BLS-Datei: $F"; [ -n "$F" ] && grep -n 'UpdateBLS\|update_bls\|kernel-install\|remove\|conf\b' "$F" | head -20
F2=$(grep -rln 'kernel-install' "$A" 2>/dev/null | head -3); for f in $F2; do echo "----- $f"; grep -n -B12 -A6 'kernel-install' "$f" | head -60; done
echo "=== [B] DTB-Ablage Fedora-Kernel"; ls -la "$R/boot/" | grep dtb; ls "$R/boot/dtb-6.19.10-300.fc44.aarch64/qcom/" 2>/dev/null | grep -c dtb; rpm --root "$R" -ql kernel-core 2>/dev/null | grep -E 'dtb' | head -3; rpm --root "$R" -ql kernel-uki-dtbloader 2>/dev/null | head; rpm --root "$R" -q --scripts kernel-uki-dtbloader 2>/dev/null | head -30
echo "--- kernel-install Konfiguration:"; cat "$R/usr/lib/kernel/install.conf" "$R/etc/kernel/install.conf" 2>/dev/null; ls "$R/etc/kernel/" 2>/dev/null; cat "$R/etc/machine-id" 2>/dev/null
echo "--- 20-grub.install Eintrag-Vorlage (30-70):"; sed -n '30,70p' "$R/usr/lib/kernel/install.d/20-grub.install"
echo "--- 50-dracut.install (hostonly?):"; grep -n 'dracut\b.*-' "$R/usr/lib/kernel/install.d/50-dracut.install" | head -5
echo "=== [C] ISO-Boot-Ausruestung (xorriso)"; xorriso -indev "$ISO" -report_el_torito plain -report_system_area plain 2>/dev/null | grep -v '^xorriso' | head -30
echo "--- Volume-ID:"; xorriso -indev "$ISO" -pvd_info 2>/dev/null | grep -E 'Volume Id|Volume id|App Id' | head -3
echo "=== [D] Original-initrd: Firmware + relevante Module"; lsinitrd /work/sl7/fedora/analyse/isofs/boot/aarch64/loader/initrd 2>/dev/null | grep -E 'lib/firmware/(ath12k|qcom|qca)' | wc -l | sed 's/^/    firmware-Dateien ath12k\/qcom\/qca: /'; lsinitrd /work/sl7/fedora/analyse/isofs/boot/aarch64/loader/initrd 2>/dev/null | grep -oE 'kernel/drivers/(spi|hid|phy/qualcomm|soc/qcom|pinctrl|clk/qcom|remoteproc|ufs|nvme|usb/dwc3|regulator|i2c/busses|input/touchscreen|gpu/drm/msm)[^ ]*\.ko[^ ]*' | sed 's|.*/||' | sort | tr '\n' ' ' | cut -c1-1500; echo
echo "=== [E] Live-Rootfs Boot-Dateien"; ls -la "$R/boot/" | head -20; ls -la "$R/boot/efi/EFI/fedora/" 2>/dev/null | head; cat "$R/boot/loader/entries/"*6.19*.conf 2>/dev/null
echo "=== [F] Plymouth/Theme/Live-User"; grep -rn 'liveuser\|livesys' "$R/etc/passwd" | head -2; ls "$R/usr/lib/systemd/system/" | grep -i 'livesys\|liveinst' ; cat "$R/etc/sysconfig/livesys" 2>/dev/null
