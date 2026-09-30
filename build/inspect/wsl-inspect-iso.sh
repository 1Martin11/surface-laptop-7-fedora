#!/usr/bin/env bash
# Schaut in die Ubuntu-x1e-ISO: wie werden DTB und Kernel geladen (GRUB-Config, dtbloader, dtb-Dateien)?
set -uo pipefail
export LC_ALL=C
ISO="/mnt/c/Users/Martin/Downloads/questing-desktop-arm64+x1e.iso"
ISO2="/mnt/s/Surface fedora/Fedora-KDE-SurfaceLaptop7-44.aarch64.iso"
for iso in "$ISO" "$ISO2"; do
  echo "################ $(basename "$iso") ($(stat -c %s "$iso") Bytes)"
  echo "=== Dateien (dtb / EFI / grub / casper)"
  7z l -ba "$iso" 2>/dev/null | awk '{print $NF}' | grep -iE 'dtb|\.efi$|grub\.cfg|casper/(vmlinuz|initrd)|\.dtb$|dtbloader|loader' | head -40
  echo "=== boot/grub/grub.cfg"
  7z x -so "$iso" boot/grub/grub.cfg 2>/dev/null | head -80
  echo "=== EFI/boot/grub.cfg"
  7z x -so "$iso" EFI/boot/grub.cfg 2>/dev/null | head -20
  echo "=== .disk/info"; 7z x -so "$iso" .disk/info 2>/dev/null; echo
done
