#!/usr/bin/env bash
# Kalibrierung des QEMU-Treibers am ORIGINAL-Fedora-ISO (Stock-Kernel): prueft EDK2/GRUB-Steuerung ueber seriell und die Erkennungsmuster.
set -uo pipefail; export LC_ALL=C
W=/work/sl7/fedora; ISO=$W/iso/Fedora-KDE-Desktop-Live-44-1.7.aarch64.iso; B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"
EFI=/usr/share/qemu-efi-aarch64/QEMU_EFI.fd; sed 's/\r$//' "$B/qemu-drive.py" > $W/qemu-drive.py
START=$(date +%s)
python3 $W/qemu-drive.py $W/qemu-calib.log 900 stock -- qemu-system-aarch64 -M virt -cpu cortex-a72 -smp 4 -m 4G -nographic -no-reboot -bios "$EFI" -device virtio-rng-pci \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 -drive "file=$ISO,media=cdrom,if=none,id=cd0,readonly=on" -device virtio-scsi-pci,id=scsi0 -device scsi-cd,drive=cd0; rc=$?
echo "rc=$rc nach $(( $(date +%s)-START )) s"
echo "--- GRUB/Driver-Marker:"; grep -aE 'qemu-drive|grub>|GNU GRUB|Start Fedora' $W/qemu-calib.log | tr -d '\r' | head -8
echo "--- Kernel/Live:"; grep -aE 'Linux version|Machine model|dmsquash|rd.live|squashfs|Reached target|login:|emergency|panic' $W/qemu-calib.log | tr -d '\r' | head -14
echo "--- letzte Zeilen:"; tail -c 1500 $W/qemu-calib.log | tr -d '\r' | tail -12
cp -f $W/qemu-calib.log "$B/out/"
