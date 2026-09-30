#!/usr/bin/env bash
# Phase 4: Boot-Tests im Emulator (qemu-system-aarch64 -M virt, EDK2, seriell).
#   Test 1: ISO per UEFI -> shim/GRUB -> GRUB-Menue (unsere Eintraege sichtbar) -> Kernel B (dtbloader-Image) + initrd-sl7b
#           -> dmsquash-live findet CDLABEL -> squashfs -> systemd -> sddm/graphical.target.  (GRUB per serieller Konsole gesteuert)
#   Test 2: wie Test 1 mit Kernel A.
#   Test 3: Fedora-Original-Kernel aus demselben ISO (Referenz).
# Testkommandozeile mit plymouth.enable=0 (ohne Anzeige haengt plymouth-quit-wait sonst und die serielle getty kommt nie).
# In QEMU findet der DTB-Stub keine passende HWID -> Firmware-DTB (erwartet). Die X1E-Treiber werden hier nicht geprueft.
set -uo pipefail; export LC_ALL=C
pkill -x qemu-system-aar 2>/dev/null; sleep 1   # Reste frueherer Laeufe
W=/work/sl7/fedora; OUT=$W/out; ISO=$(ls -t "$OUT"/*.iso | head -1); B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"
EFI=/usr/share/qemu-efi-aarch64/QEMU_EFI.fd
[ -n "$EFI" ] || { echo "QEMU_EFI.fd fehlt"; exit 1; }
sed 's/\r$//' "$B/qemu-drive.py" > /work/sl7/fedora/qemu-drive.py
T=${T:-900}
echo "ISO: $ISO  EFI: $EFI  Timeout je Test: ${T}s"
QEMU=(qemu-system-aarch64 -M virt -cpu cortex-a72 -smp 8 -m 6G -nographic -no-reboot -bios "$EFI" -device virtio-rng-pci -device virtio-gpu-pci
      -netdev user,id=n0 -device virtio-net-pci,netdev=n0
      -drive "file=$ISO,media=cdrom,if=none,id=cd0,readonly=on" -device virtio-scsi-pci,id=scsi0 -device scsi-cd,drive=cd0)
runtest() { local name=$1 log=$2 kern=$3; echo "=== $name"; START=$(date +%s)
  python3 /work/sl7/fedora/qemu-drive.py "$log" "$T" "$kern" -- "${QEMU[@]}"; rc=$?
  case $rc in 0) echo "    ERFOLG ($(( $(date +%s)-START )) s)";; 1) echo "    FEHLER erkannt ($(( $(date +%s)-START )) s)";; 2) echo "    TIMEOUT";; *) echo "    GRUB nicht erreicht/Fehler in GRUB";; esac
  echo "    Kernel: $(grep -aoE 'Linux version [^ ]+' "$log" | head -1)   Modell: $(grep -aoE 'Machine model: .*' "$log" | head -1 | tr -d '\r')"
  grep -aE 'dmsquash|rd.live|squashfs|overlayfs' "$log" | grep -avE 'systemd\[1\]: (Starting|Started|Finished)|Command line' | head -5 | tr -d '\r' | sed 's/^/    /'
  grep -aE 'Reached target|login:|emergency|panic|Failed to start|error:' "$log" | tail -8 | tr -d '\r' | sed 's/^/    /'
  return $rc; }
runtest "Test 1: UEFI/GRUB -> Kernel B (dtbloader) + Live-Rootfs" "$W/qemu-test1.log" sl7b; R1=$?
runtest "Test 2: UEFI/GRUB -> Kernel A (dtbloader) + Live-Rootfs" "$W/qemu-test2.log" sl7a; R2=$?
runtest "Test 3: UEFI/GRUB -> Fedora-Original-Kernel (Referenz)" "$W/qemu-test3.log" stock; R3=$?
echo "=== GRUB-Menue aus Test 1 (Eintraege sichtbar?):"; grep -aoE 'SL7: [^|]{0,80}|Touchscreen-Varianten[^|]{0,40}|Diagnose / [^|]{0,30}' "$W/qemu-test1.log" | tr -d '\r' | sort -u | head -8 | sed 's/^/    /'
cp -f "$W"/qemu-test[123].log "$B/out/" 2>/dev/null
echo "=== Ergebnis: Test1=$R1 Test2=$R2 Test3=$R3 (0 = Erfolg)"
echo "=== Phase 4 fertig"
