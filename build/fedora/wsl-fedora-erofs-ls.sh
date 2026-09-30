#!/usr/bin/env bash
# EROFS-Image korrekt lesen: Wurzelverzeichnis listen, LiveOS/rootfs.img per erofsfuse herausholen, dann ext4 loop-mounten.
set -uo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
W=/work/sl7/fedora; IMG="$W/analyse/isofs/LiveOS/squashfs.img"
echo "=== erofs-utils Version"; dump.erofs --version 2>&1 | head -1; dpkg -l erofs-utils 2>/dev/null | awk '/^ii/{print $3}'
echo "=== Was ist die extrahierte 4,6-GB-Datei?"; file "$W/rootfs.img" 2>/dev/null | cut -c1-160; head -c 1100 "$W/rootfs.img" 2>/dev/null | od -A d -t x1 | sed -n '65,70p'
echo "=== Wurzelverzeichnis des EROFS"; dump.erofs --ls --path=/ "$IMG" 2>&1 | head -12
echo "=== LiveOS/"; dump.erofs --ls --path=/LiveOS "$IMG" 2>&1 | head -6
echo "=== rootfs.img Inode-Info"; dump.erofs --path=/LiveOS/rootfs.img "$IMG" 2>&1 | head -12
echo "=== erofsfuse verfuegbar?"; command -v erofsfuse || apt-get install -y -qq erofsfuse >/dev/null 2>&1; command -v erofsfuse && ls -la /dev/fuse
mkdir -p "$W/efs"
if command -v erofsfuse >/dev/null 2>&1 && erofsfuse "$IMG" "$W/efs" 2>/tmp/fuse.err; then
  echo "erofsfuse gemountet:"; ls -la "$W/efs" "$W/efs/LiveOS" 2>/dev/null
  if [ -f "$W/efs/LiveOS/rootfs.img" ]; then
    echo "=== rootfs.img kopieren (ext4, $(stat -c %s "$W/efs/LiveOS/rootfs.img") Bytes)"; START=$(date +%s)
    rm -f "$W/rootfs.img"; cp "$W/efs/LiveOS/rootfs.img" "$W/rootfs.img"; echo "Dauer: $(( $(date +%s) - START ))s"
  fi
  fusermount -u "$W/efs" 2>/dev/null || umount "$W/efs" 2>/dev/null
else cat /tmp/fuse.err 2>/dev/null; fi
echo "=== rootfs.img pruefen + mounten"; file "$W/rootfs.img" | cut -c1-120
mkdir -p "$W/mnt"; mountpoint -q "$W/mnt" && umount "$W/mnt"
if mount -o loop,ro "$W/rootfs.img" "$W/mnt"; then
  R="$W/mnt"; df -h "$R" | tail -1; head -2 "$R/etc/os-release"; ls "$R/usr/lib/modules/"
  M=$(ls -d "$R"/usr/lib/modules/* | head -1); echo "vmlinuz=$(stat -c %s "$M/vmlinuz" 2>/dev/null) dtb-Ordner=$(ls -d "$M"/dtb 2>/dev/null || echo nein)"
  ls -d "$R"/boot/dtb* 2>/dev/null; ls "$R"/boot/dtb-*/qcom/ 2>/dev/null | grep -iE 'x1e80100-microsoft' | sed 's/^/   /'
  echo "--- BLS:"; ls "$R/boot/loader/entries/" 2>/dev/null; cat "$R/boot/loader/entries/"*.conf 2>/dev/null | head -10
  echo "--- /etc/kernel/cmdline: $(cat "$R/etc/kernel/cmdline" 2>/dev/null)"; echo "--- install.d: $(ls "$R/usr/lib/kernel/install.d/" 2>/dev/null | tr '\n' ' ')"
  echo "--- devicetree-Logik:"; grep -rln -i 'devicetree' "$R/usr/lib/kernel/install.d/" "$R/etc/grub.d/" "$R/usr/sbin/grubby" 2>/dev/null; grep -n -i 'dtb\|devicetree' "$R/etc/default/grub" 2>/dev/null
  echo "--- dracut conf:"; cat "$R/etc/dracut.conf.d/"*.conf "$R/usr/lib/dracut/dracut.conf.d/"*.conf 2>/dev/null | grep -v '^#' | grep -v '^$' | head -10
  echo "--- Firmware ath12k: $(ls "$R/usr/lib/firmware/ath12k/WCN7850/hw2.0/" 2>/dev/null | tr '\n' ' ')"; echo "    qcom/x1e80100 ($(ls "$R/usr/lib/firmware/qcom/x1e80100/" 2>/dev/null | wc -l)): $(ls "$R/usr/lib/firmware/qcom/x1e80100/" 2>/dev/null | tr '\n' ' ' | cut -c1-300)"; echo "    Vendor-Dirs: $(ls -d "$R"/usr/lib/firmware/qcom/x1e80100/*/ 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"; echo "    qca hmt: $(ls "$R/usr/lib/firmware/qca/" 2>/dev/null | grep -ci hmt)  gen70500: $(ls "$R/usr/lib/firmware/qcom/" 2>/dev/null | grep -c gen70500)"
  echo "--- Pakete: $(rpm --root "$R" -qa 2>/dev/null | wc -l)"; for p in kernel-core kernel-dtb-loader linux-firmware qcom-firmware atheros-firmware iptsd libinput pipewire alsa-ucm-conf plymouth dracut grub2-efi-aa64 shim-aa64 grubby systemd-ukify mesa-vulkan-drivers anaconda-live plasma-desktop; do printf '    %-22s %s\n' "$p" "$(rpm --root "$R" -q "$p" 2>/dev/null | head -1)"; done
  echo "--- Live-Kernel-Config: $(grep -E '^CONFIG_(EROFS_FS|EROFS_FS_ZIP_LZMA|SQUASHFS|SQUASHFS_ZSTD|SPI_HID|ATH12K)=' "$M/config" 2>/dev/null | tr '\n' ' ')"
  umount "$R"
fi
echo "--- unser Kernel: $(grep -E '^CONFIG_(EROFS_FS|EROFS_FS_ZIP|EROFS_FS_ZIP_LZMA|EROFS_FS_ZIP_ZSTD|SQUASHFS|SQUASHFS_ZSTD|SQUASHFS_XZ|OVERLAY_FS|DM_SNAPSHOT)=' /work/sl7/kernel/ellx-7.0-sl7/.config | tr '\n' ' ')"
