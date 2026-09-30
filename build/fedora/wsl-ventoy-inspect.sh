#!/usr/bin/env bash
set -uo pipefail; export LC_ALL=C
W=/work/sl7/fedora; ISO=$(ls -t $W/out/*.iso | head -1); echo "ISO: $ISO"
xorriso -indev "$ISO" -find / -maxdepth 3 -type d 2>/dev/null | grep -v '^xorriso' | head -40
echo "--- grub.cfg-Dateien im ISO:"; xorriso -indev "$ISO" -find / -name '*.cfg' 2>/dev/null | grep -v '^xorriso'
mkdir -p /tmp/vx; xorriso -osirrox on -indev "$ISO" -extract /EFI/BOOT/grub.cfg /tmp/vx/efi-grub.cfg 2>/dev/null; echo "--- /EFI/BOOT/grub.cfg:"; cat /tmp/vx/efi-grub.cfg 2>/dev/null | head -30
echo "--- Werkzeuge: $(which mformat mcopy sfdisk mke2fs mkfs.exfat qemu-system-aarch64 2>&1 | tr '\n' ' ')"
