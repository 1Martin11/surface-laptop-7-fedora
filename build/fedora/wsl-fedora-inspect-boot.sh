#!/usr/bin/env bash
# Nur lesen: wie bootet das Live-ISO, wie legt Fedora BLS/DTB an, was macht Anaconda beim Live-Install (Kernel-Liste, BLS, Cmdline).
set -uo pipefail; export LC_ALL=C
R=/work/sl7/fedora/rootfs; I=/work/sl7/fedora/analyse/isofs
echo "=== Kernel-Pakete im Live-Rootfs"; rpm --root "$R" -qa 'kernel*' 2>/dev/null | sort
echo "=== SELinux-xattr"; getfattr -n security.selinux "$R/etc/passwd" 2>&1 | grep -v '^#' | grep . ; getfattr -n security.selinux "$R/usr/bin/bash" 2>&1 | grep -v '^#' | grep .
echo "=== ISO grub.cfg"; cat "$I/boot/grub2/grub.cfg" 2>/dev/null; echo "--- EFI/BOOT:"; ls -la "$I/EFI/BOOT/"; cat "$I/EFI/BOOT/grub.cfg" 2>/dev/null | head -30
echo "--- images/:"; ls -la "$I/images/" 2>/dev/null; echo "--- boot/aarch64:"; find "$I/boot" -maxdepth 3 | head -20; ls -la "$I/boot/aarch64/loader/" 2>/dev/null
echo "--- efiboot.img Inhalt:"; mdir -i "$I/images/efiboot.img" -/ :: 2>/dev/null | head -20
echo "=== Original-initrd: dracut-Module + Konfiguration"; lsinitrd "$I/boot/aarch64/loader/initrd" 2>/dev/null | sed -n '1,12p'; echo "--- Module:"; lsinitrd --mod "$I/boot/aarch64/loader/initrd" 2>/dev/null | tr '\n' ' '; echo
echo "--- Kernel-Module qcom im initrd: $(lsinitrd "$I/boot/aarch64/loader/initrd" 2>/dev/null | grep -c 'kernel/drivers/.*\.ko')  (spi-hid: $(lsinitrd "$I/boot/aarch64/loader/initrd" 2>/dev/null | grep -c 'spi-hid'))"
echo "--- dracut-Config im Rootfs:"; for f in "$R"/etc/dracut.conf.d/*.conf "$R"/usr/lib/dracut/dracut.conf.d/*.conf; do echo "[$f]"; grep -v '^#' "$f" | grep .; done 2>/dev/null
echo "=== loader/linux (PE) Sektionen"; objdump -h "$I/boot/aarch64/loader/linux" 2>/dev/null | awk '/^ +[0-9]+ /{print $2, $3}' | tr '\n' ' '; echo
echo "=== 20-grub.install (devicetree/cmdline-Logik)"; grep -n -i 'devicetree\|GRUB_DEVICETREE\|DEFAULT_DTB\|/etc/kernel/cmdline\|proc/cmdline\|GRUB_CMDLINE' "$R/usr/lib/kernel/install.d/20-grub.install" | head -30
echo "--- 95-set-boot-entry.install:"; grep -v '^#' "$R/usr/lib/kernel/install.d/95-set-boot-entry.install" | grep . | head -20
echo "--- 10-devicetree.install (Kern):"; sed -n '1,60p' "$R/usr/lib/kernel/install.d/10-devicetree.install" | grep -v '^\s*#' | grep . | head -40
echo "=== grub2 blscfg: devicetree-Umgebungsvariable"; strings "$R/usr/lib/grub/arm64-efi/blscfg.mod" 2>/dev/null | grep -i 'devicetree\|dtb' | head; strings "$R/boot/efi/EFI/fedora/grubaa64.efi" 2>/dev/null | grep -i 'devicetree' | head -5
echo "--- /etc/grub.d/10_linux DTB-Logik:"; sed -n '295,306p;515,530p' "$R/etc/grub.d/10_linux"
echo "=== Anaconda: Live-Payload / BLS / Kernel-Liste / Cmdline-Uebernahme"
A=$(ls -d "$R"/usr/lib64/python3*/site-packages/pyanaconda "$R"/usr/lib/python3*/site-packages/pyanaconda 2>/dev/null | head -1); echo "pyanaconda: $A  anaconda: $(rpm --root "$R" -q anaconda-core 2>/dev/null)"
grep -rn -i 'class UpdateBLSConfigurationTask' -A 40 "$A"/modules/payloads/ 2>/dev/null | grep -i 'def run\|kernel-install\|kernel_install\|entries\|rm\|remove\|execWithRedirect\|_get_kernel\|for ' | head -25
echo "--- Kernel-Versionsliste:"; grep -rn 'def get_kernel_version_list' -A 25 "$A"/core/kernel.py 2>/dev/null | head -40
echo "--- Bootargs-Uebernahme (preserve):"; grep -rn -i 'preserve_args\|preserved_args\|modprobe.blacklist\|rd.driver' "$A"/modules/storage/bootloader/base.py "$A"/modules/storage/bootloader/*.py 2>/dev/null | head -12
echo "--- anaconda-denylist:"; grep -rn 'anaconda-denylist\|denylist.conf' "$A" 2>/dev/null | head -5
echo "--- initrd-Neubau nach Install:"; grep -rn -i 'dracut\|recreate_initrd\|RecreateInitrdsTask' "$A"/modules/payloads/payload/live_os/*.py "$A"/modules/payloads/base/*.py "$A"/modules/payloads/payload/live_image/*.py 2>/dev/null | head -12
echo "=== Groessen"; ls -la /work/sl7/fedora/iso/*.iso "$I/LiveOS/squashfs.img"
echo "=== 20-grub.install Zeilen 100-130"; sed -n '100,130p' "$R/usr/lib/kernel/install.d/20-grub.install"
echo "=== sl7-mac deb"; O="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out"; dpkg-deb -I "$O/sl7-mac_1.0.2_all.deb" | grep -E 'Depends|Version|Description' ; dpkg-deb -c "$O/sl7-mac_1.0.2_all.deb" | awk '{print $1, $6}'
mkdir -p /tmp/sl7mac && dpkg-deb -x "$O/sl7-mac_1.0.2_all.deb" /tmp/sl7mac && dpkg-deb -e "$O/sl7-mac_1.0.2_all.deb" /tmp/sl7mac/DEBIAN; for f in $(find /tmp/sl7mac -type f); do echo "----- $f"; head -60 "$f"; done
echo "=== ellx-fixes"; for f in $(find "$O/ellx-fixes" -type f); do echo "----- $f"; sed 's/$//' "$f" | head -50; done
