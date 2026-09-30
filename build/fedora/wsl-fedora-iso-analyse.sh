#!/usr/bin/env bash
# Fedora-KDE-Live-44-aarch64-ISO: nach WSL kopieren, Pruefsumme, Struktur (EFI, GRUB, LiveOS), Kernel/DTB/Firmware im Live-Rootfs.
# Aufruf (als root in WSL):  bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora/wsl-fedora-iso-analyse.sh"
set -uo pipefail
export LC_ALL=C
SRC="/mnt/z/Surface fedora/Fedora-KDE-Desktop-Live-44-1.7.aarch64.iso"
W=/work/sl7/fedora
ISO="$W/iso/Fedora-KDE-Desktop-Live-44-1.7.aarch64.iso"
mkdir -p "$W/iso" "$W/analyse"
# Z: ist in WSL nicht automatisch eingehaengt (Laufwerk kam nach dem WSL-Start dazu)
if [ ! -d /mnt/z ] || ! ls /mnt/z >/dev/null 2>&1; then mkdir -p /mnt/z; mount -t drvfs Z: /mnt/z 2>&1 | tail -1; fi
ls "/mnt/z/Surface fedora/" | head -3
if [ ! -s "$ISO" ]; then echo "=== ISO nach WSL kopieren (3 GB)"; cp "$SRC" "$ISO"; fi
ls -la "$ISO"
echo "=== Pruefsumme gegen Fedora-CHECKSUM"
cd "$W/iso"
curl -sL --fail --max-time 60 -o CHECKSUM "https://download.fedoraproject.org/pub/fedora/linux/releases/44/KDE/aarch64/iso/Fedora-KDE-44-1.7-aarch64-CHECKSUM" \
  || curl -sL --fail --max-time 60 -o CHECKSUM "https://download.fedoraproject.org/pub/fedora/linux/releases/44/KDE/aarch64/iso/Fedora-KDE-Desktop-Live-44-1.7-aarch64-CHECKSUM" || echo "CHECKSUM-Datei nicht gefunden (Name?)"
[ -s CHECKSUM ] && { grep -i 'Fedora-KDE-Desktop-Live-44-1.7.aarch64.iso' CHECKSUM | grep -E '^SHA256' | sed 's/SHA256 (\(.*\)) = \(.*\)/\2  \1/' | sha256sum -c - 2>&1 | tail -1; }

echo; echo "=== ISO-Inhalt (ohne squashfs-Innenleben)"
xorriso -indev "$ISO" -find / -type f -exec lsdl -- 2>/dev/null | awk '{print $5, $NF}' | grep -vE "^\s*$" | sort -k2 | head -60
echo; echo "=== Volume-Label"; xorriso -indev "$ISO" -pvd_info 2>/dev/null | grep -iE 'Volume id|Publisher|App id' | head -3

mkdir -p "$W/analyse/isofs"
xorriso -osirrox on -indev "$ISO" -extract /EFI "$W/analyse/isofs/EFI" -extract /boot "$W/analyse/isofs/boot" -extract /images "$W/analyse/isofs/images" 2>/dev/null
echo; echo "=== EFI/ und boot/"; find "$W/analyse/isofs" -type f -printf '%10s  %P\n' | sort -k2
echo; echo "=== EFI/BOOT/grub.cfg"; cat "$W/analyse/isofs/EFI/BOOT/grub.cfg" 2>/dev/null
echo; echo "=== boot/grub2/grub.cfg (falls vorhanden)"; cat "$W/analyse/isofs/boot/grub2/grub.cfg" 2>/dev/null | head -60
echo; echo "=== Kernel im ISO (images/pxeboot/vmlinuz): Typ"; file "$W/analyse/isofs/images/pxeboot/vmlinuz" 2>/dev/null; ls -la "$W/analyse/isofs/images/pxeboot/" 2>/dev/null
echo; echo "=== initrd: dracut-Module (Auszug)"; lsinitrd "$W/analyse/isofs/images/pxeboot/initrd.img" 2>/dev/null | sed -n '/dracut modules/,/^===/p' | head -40
lsinitrd "$W/analyse/isofs/images/pxeboot/initrd.img" 2>/dev/null | grep -E 'dmsquash|livenet|qcom|msm|ath12k|nvme|dtb' | head -20

echo; echo "=== LiveOS/squashfs.img"
xorriso -osirrox on -indev "$ISO" -extract /LiveOS "$W/analyse/isofs/LiveOS" 2>/dev/null
ls -la "$W/analyse/isofs/LiveOS/"
SQ="$W/analyse/isofs/LiveOS/squashfs.img"
unsquashfs -s "$SQ" 2>/dev/null | head -12
echo "--- Top-Level im squashfs:"; unsquashfs -l "$SQ" 2>/dev/null | head -20
if unsquashfs -l "$SQ" 2>/dev/null | grep -q 'LiveOS/rootfs.img'; then
  echo "--- Variante: rootfs.img (ext4) im squashfs -> extrahieren + loop-mounten"
  unsquashfs -q -f -d "$W/analyse/sq" "$SQ" LiveOS/rootfs.img
  mkdir -p "$W/analyse/root"; mount -o loop,ro "$W/analyse/sq/LiveOS/rootfs.img" "$W/analyse/root" && ROOT="$W/analyse/root"
else
  echo "--- Variante: reines squashfs-Rootfs"
  mkdir -p "$W/analyse/root"; mount -t squashfs -o loop,ro "$SQ" "$W/analyse/root" && ROOT="$W/analyse/root"
fi
if [ -n "${ROOT:-}" ]; then
  echo; echo "=== Live-Rootfs"; cat "$ROOT/etc/os-release" | head -3
  echo "--- Kernel:"; ls "$ROOT/usr/lib/modules/"; ls -la "$ROOT/usr/lib/modules/"*/vmlinuz 2>/dev/null; ls "$ROOT/boot/" 2>/dev/null
  echo "--- DTBs qcom/x1e80100* im Kernelpaket:"; ls "$ROOT"/usr/lib/modules/*/dtb/qcom/ 2>/dev/null | grep -iE 'x1e80100|romulus' | head; ls "$ROOT"/usr/lib/modules/*/dtb/qcom/ 2>/dev/null | wc -l | sed 's/^/    qcom-DTBs gesamt: /'
  echo "--- kernel-install / BLS:"; ls "$ROOT/boot/loader/entries/" 2>/dev/null; cat "$ROOT/boot/loader/entries/"*.conf 2>/dev/null | head -12; cat "$ROOT/etc/kernel/cmdline" 2>/dev/null; ls "$ROOT/usr/lib/kernel/install.d/" 2>/dev/null
  echo "--- grub2 auf aarch64: devicetree-Logik in 10_linux / blscfg?"; grep -n -i 'devicetree\|dtb' "$ROOT/etc/grub.d/10_linux" 2>/dev/null | head -8; ls "$ROOT/etc/grub.d/" 2>/dev/null
  echo "--- Firmware: ath12k WCN7850 / qcom x1e80100:"; ls "$ROOT/usr/lib/firmware/ath12k/WCN7850/hw2.0/" 2>/dev/null; ls "$ROOT/usr/lib/firmware/qcom/x1e80100/" 2>/dev/null | head; ls "$ROOT/usr/lib/firmware/qca/" 2>/dev/null | grep -i hmt
  echo "--- dracut config:"; cat "$ROOT/etc/dracut.conf.d/"*.conf 2>/dev/null | head -20; ls "$ROOT/usr/lib/dracut/dracut.conf.d/" 2>/dev/null
  echo "--- iptsd / libinput / pipewire vorhanden?"; for p in iptsd libinput pipewire wireplumber alsa-ucm-conf plymouth dracut grub2-efi-aa64 shim-aa64 grubby; do rpm --root "$ROOT" -q "$p" 2>/dev/null || echo "  (kein rpm-Query moeglich: $p)"; done
  echo "--- rpm-Datenbank lesbar?"; rpm --root "$ROOT" -qa 2>/dev/null | wc -l; rpm --root "$ROOT" -q kernel kernel-core 2>/dev/null
  echo "--- Plattengroesse Rootfs:"; du -sh "$ROOT" 2>/dev/null
  umount "$ROOT" 2>/dev/null
fi
echo "=== fertig"
