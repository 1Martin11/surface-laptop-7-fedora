#!/usr/bin/env bash
# Nur lesen: Anaconda BLS-/initrd-Neubau im Detail, Bootargs-Uebernahme, Live-Kernelliste; sl7-mac-Inhalt; xattr-Pruefung.
set -uo pipefail; export LC_ALL=C
R=/work/sl7/fedora/rootfs; A="$R/usr/lib64/python3.14/site-packages/pyanaconda"
command -v getfattr >/dev/null || apt-get install -y -qq attr >/dev/null 2>&1
echo "=== xattr"; getfattr --absolute-names -n security.selinux "$R/etc/passwd" "$R/usr/bin/bash" "$R/boot/vmlinuz-6.19.10-300.fc44.aarch64" 2>&1 | grep -v '^$'
echo "=== bootloader/utils.py 195-300"; sed -n '195,300p' "$A/modules/storage/bootloader/utils.py"
echo "=== base.py _preserve_some_boot_args"; grep -n '_preserve_some_boot_args' -A 25 "$A/modules/storage/bootloader/base.py" | sed -n '1,60p'
echo "=== Live-Kernelliste"; grep -rn 'def get_kernel_version_list' -A 12 "$A"/modules/payloads/payload/live_os/live_os.py "$A"/modules/payloads/base/utils.py "$A"/modules/payloads/payload/live_image/*.py 2>/dev/null | head -50
grep -rn 'def get_kernel_version_list\|def _get_kernel_version_list\|vmlinuz' "$A"/modules/payloads/base/utils.py "$A"/core/kernel.py 2>/dev/null | head
echo "=== Reihenfolge Install-Tasks (bootloader/installation.py 150-260)"; sed -n '150,260p' "$A/modules/storage/bootloader/installation.py" | grep -n 'class\|Task\|def run\|create_bls\|recreate\|kernel\|configure' | head -40
echo "=== sl7-mac Dateien"; for f in /tmp/sl7mac/usr/bin/sl7-mac /tmp/sl7mac/usr/lib/sl7-mac/mgmt-set-addr.py /tmp/sl7mac/usr/lib/systemd/system/sl7-bt-mac.service /tmp/sl7mac/usr/lib/systemd/system/sl7-wifi-mac.service /tmp/sl7mac/usr/lib/udev/rules.d/99-sl7-bt-mac.rules; do echo "----- $f"; head -80 "$f"; done
echo "=== grub2-editenv/grubby im Rootfs"; ls "$R"/usr/bin/grub2-editenv "$R"/usr/sbin/grubby "$R"/usr/sbin/grub2-mkconfig "$R"/usr/bin/systemd-detect-virt 2>&1
echo "=== Live-Cmdline-Handling Fedora (livesys, rd.live)"; grep -rn 'blacklist\|denylist' "$R/usr/libexec/livesys/"* "$R/usr/lib/systemd/system/livesys"* 2>/dev/null | head
