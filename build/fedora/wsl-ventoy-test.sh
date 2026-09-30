#!/usr/bin/env bash
# Ventoy-Kette im Emulator: Nachbau des Sticks (Ventoy-Dateien 1:1 von Martins Stick E:, Partition 1 exFAT mit dem ISO, MBR-Layout
# wie Ventoy) -> Ventoy (aa64) -> ISO-GRUB -> Kernel -> Ventoy-Hook im initrd muss das Live-Medium bereitstellen.
set -uo pipefail; export LC_ALL=C
pkill -x qemu-system-aar 2>/dev/null; sleep 1
fail() { echo "FEHLER: $*"; exit 1; }
W=/work/sl7/fedora; V=$W/ventoy; B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"; ISO=${1:-$W/out/Fedora-KDE-Live-44-SL7-20260930.iso}
EFI=/usr/share/qemu-efi-aarch64/QEMU_EFI.fd; IMG=$V/vt.img; P1S=2048; P1N=$((6*1024*2048)); P2S=$((P1S+P1N)); T=${T:-1500}
mkdir -p $V /mnt/e /mnt/vt1; mountpoint -q /mnt/e || mount -t drvfs E: /mnt/e || fail "E: (VTOYEFI) nicht einhaengbar"
[ -f /mnt/e/ventoy/ventoy.cpio ] && [ -f /mnt/e/EFI/BOOT/BOOTAA64.EFI ] || fail "Ventoy-Dateien auf E: fehlen"
echo "=== Stick-Nachbau  ISO=$(basename "$ISO")  Ventoy $(grep -aoE 'VENTOY_VERSION="[^"]+"' /mnt/e/grub/grub.cfg | head -1)"
mountpoint -q /mnt/vt1 && umount /mnt/vt1; losetup -j $IMG | cut -d: -f1 | xargs -r losetup -d; rm -f $IMG; truncate -s $(( (P2S+65536)*512 )) $IMG
printf 'label: dos\nstart=%d, size=%d, type=7, bootable\nstart=%d, size=65536, type=ef\n' $P1S $P1N $P2S | sfdisk -q $IMG || fail sfdisk
dd if=/dev/urandom of=$IMG bs=1 seek=$((0x180)) count=16 conv=notrunc status=none     # Ventoy-Disk-GUID (Hook sucht den Datentraeger darueber)
# Ventoys eigener MBR-Check (ventoy_cmd.c g_check_mbr_data): Bytes 0..0x2f und 0x190..0x19f muessen dem Ventoy-Bootcode entsprechen
printf '\xeb\x63\x90' | dd of=$IMG bs=1 conv=notrunc status=none; dd if=/dev/zero of=$IMG bs=1 seek=3 count=45 conv=notrunc status=none
printf 'VT\0Ge\0HD\0Rd\0 Er\r' | dd of=$IMG bs=1 seek=$((0x190)) conv=notrunc status=none
# Partition 2 (VTOYEFI, 32 MiB FAT16) mit den Dateien von Martins Stick
mformat -i "$IMG@@$((P2S*512))" -t 32 -h 64 -s 32 -c 2 -v VTOYEFI :: || fail mformat
mcopy -s -Q -i "$IMG@@$((P2S*512))" /mnt/e/EFI /mnt/e/grub /mnt/e/tool /mnt/e/ventoy ::/ || fail "mcopy (VTOYEFI voll?)"
command -v mkfs.exfat >/dev/null || apt-get install -y -qq exfatprogs >/dev/null 2>&1
L1=$(losetup -f --show -o $((P1S*512)) --sizelimit $((P1N*512)) $IMG) || fail losetup
if mkfs.exfat -L Ventoy "$L1" >/dev/null 2>&1 && mount -t exfat "$L1" /mnt/vt1 2>/dev/null; then FS=exfat
else mke2fs -q -F -t ext4 -L Ventoy -O ^metadata_csum,^64bit,^orphan_file,^metadata_csum_seed "$L1" && mount "$L1" /mnt/vt1 && FS=ext4 || fail "Partition 1"; fi
mkdir -p /mnt/vt1/ventoy; cp "$ISO" /mnt/vt1/ || fail "ISO kopieren"
printf '{ "control":[{"VTOY_MENU_TIMEOUT":"3"},{"VTOY_SECONDARY_BOOT_MENU":"0"}], "theme":{"display_mode":"CLI"} }\n' > /mnt/vt1/ventoy/ventoy.json
sync; umount /mnt/vt1; losetup -d "$L1"; echo "    Partition 1: $FS, Image $(du -h $IMG | cut -f1) belegt"; sfdisk -l $IMG | tail -3 | sed 's/^/    /'
sed 's/\r$//' "$B/qemu-drive.py" > $W/qemu-drive.py
QEMU=(qemu-system-aarch64 -M virt -cpu cortex-a72 -smp 8 -m 6G -nographic -no-reboot -bios "$EFI" -device virtio-rng-pci -device virtio-gpu-pci
      -netdev user,id=n0 -device virtio-net-pci,netdev=n0 -device qemu-xhci,id=xhci
      -drive "file=$IMG,if=none,id=u0,format=raw,snapshot=on" -device usb-storage,bus=xhci.0,drive=u0)
RES=""
for kern in ${KERNELS:-sl7b sl7a stock}; do log=$V/ventoy-$kern.log; echo "=== Ventoy -> ISO -> $kern"; START=$(date +%s)
  SL7_VENTOY=1 python3 $W/qemu-drive.py "$log" "$T" "$kern" -- "${QEMU[@]}"; rc=$?; RES="$RES $kern=$rc"
  echo "    rc=$rc ($(( $(date +%s)-START )) s)  Kernel: $(grep -aoE 'Linux version [^ ]+' "$log" | head -1)"
  grep -aiE 'ventoy|live-rw|dm-0|does not exist|emergency|Reached target.*(Graphical|Multi-User)|login:' "$log" | grep -av 'Command line\|qemu-drive' | tr -d '\r' | cut -c1-150 | sort -u | tail -12 | sed 's/^/    /'
  cp -f "$log" "$B/out/logs/qemu-ventoy-$kern.log" 2>/dev/null
done
echo "=== Ergebnis Ventoy-Test:$RES (0 = Erfolg)"
