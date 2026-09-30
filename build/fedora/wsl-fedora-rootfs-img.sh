#!/usr/bin/env bash
# Das aus dem EROFS extrahierte Objekt ist eine einzelne Datei (LiveOS/rootfs.img, ext4). Umbenennen, loop-mounten, analysieren.
set -uo pipefail
export LC_ALL=C
W=/work/sl7/fedora
if [ -f "$W/rootfs" ]; then mv "$W/rootfs" "$W/rootfs.img"; fi
IMG="$W/rootfs.img"
echo "=== Typ"; file "$IMG"; blkid -p "$IMG" 2>/dev/null | tr ' ' '\n' | grep -E 'TYPE|FSSIZE|UUID' | tr '\n' ' '; echo
mkdir -p "$W/mnt"
mountpoint -q "$W/mnt" && umount "$W/mnt"
mount -o loop,ro "$IMG" "$W/mnt" || { echo "Mount fehlgeschlagen"; exit 1; }
R="$W/mnt"
echo "=== Belegung im Image"; df -h "$R" | tail -1
echo "=== os-release"; head -3 "$R/etc/os-release"
echo "=== Kernel"; ls "$R/usr/lib/modules/"
M=$(ls -d "$R"/usr/lib/modules/* | head -1)
echo "--- $(basename "$M"): vmlinuz=$(stat -c %s "$M/vmlinuz" 2>/dev/null) Bytes; dtb-Ordner: $(ls -d "$M"/dtb 2>/dev/null || echo nein)"
echo "--- /boot:"; ls -la "$R/boot/" | head -12
echo "--- /boot/dtb*: "; ls -d "$R"/boot/dtb* 2>/dev/null; ls "$R"/boot/dtb-*/qcom/ 2>/dev/null | grep -iE 'x1e80100-microsoft' | sed 's/^/      /'; echo "      qcom-DTBs: $(ls "$R"/boot/dtb-*/qcom/ 2>/dev/null | wc -l)"
echo "--- BLS-Eintraege:"; ls "$R/boot/loader/entries/" 2>/dev/null; cat "$R/boot/loader/entries/"*.conf 2>/dev/null | head -12
echo "--- /etc/kernel/cmdline:"; cat "$R/etc/kernel/cmdline" 2>/dev/null
echo "--- kernel-install Plugins:"; ls "$R/usr/lib/kernel/install.d/" 2>/dev/null | tr '\n' ' '; echo
echo "--- devicetree/dtb-Logik:"; grep -rln -i 'devicetree' "$R/usr/lib/kernel/install.d/" "$R/etc/grub.d/" "$R/usr/sbin/grubby" 2>/dev/null; grep -n -i 'dtb\|devicetree' "$R/etc/default/grub" 2>/dev/null; grep -rn -i 'dtb' "$R/usr/lib/kernel/install.d/"*.install 2>/dev/null | head -6
echo "--- grub2 10_linux devicetree:"; grep -n -i 'devicetree\|dtb' "$R/etc/grub.d/10_linux" 2>/dev/null | head -5
echo "--- dracut-Konfiguration:"; ls "$R/usr/lib/dracut/dracut.conf.d/" "$R/etc/dracut.conf.d/" 2>/dev/null; cat "$R/etc/dracut.conf.d/"*.conf "$R/usr/lib/dracut/dracut.conf.d/"*.conf 2>/dev/null | grep -v '^#' | grep -v '^$' | head -12
echo "=== Firmware"; ls "$R/usr/lib/firmware/ath12k/WCN7850/hw2.0/" 2>/dev/null | tr '\n' ' '; echo
echo "qcom/x1e80100: $(ls "$R/usr/lib/firmware/qcom/x1e80100/" 2>/dev/null | wc -l): $(ls "$R/usr/lib/firmware/qcom/x1e80100/" 2>/dev/null | tr '\n' ' ' | cut -c1-400)"
ls -d "$R"/usr/lib/firmware/qcom/x1e80100/*/ 2>/dev/null | sed "s|$R/usr/lib/firmware/||" | tr '\n' ' '; echo
echo "qca hmt: $(ls "$R/usr/lib/firmware/qca/" 2>/dev/null | grep -i hmt | tr '\n' ' ')"
echo "gen70500: $(ls "$R/usr/lib/firmware/qcom/" 2>/dev/null | grep -iE 'gen70500|a740' | tr '\n' ' ')"
echo "=== Pakete"; rpm --root "$R" -qa 2>/dev/null | wc -l | sed 's/^/    gesamt: /'
for p in kernel-core kernel-dtb-loader linux-firmware qcom-firmware atheros-firmware iptsd libinput pipewire wireplumber alsa-ucm-conf plymouth dracut grub2-efi-aa64 shim-aa64 grubby systemd-udev systemd-ukify systemd-boot-unsigned mesa-vulkan-drivers mesa-dri-drivers anaconda-live plasma-desktop sddm; do printf '    %-24s %s\n' "$p" "$(rpm --root "$R" -q "$p" 2>/dev/null | head -1)"; done
echo "=== Kernel-Config-Auszug (Live-Kernel): EROFS/SQUASHFS/SPI_HID/ATH12K"
grep -E '^CONFIG_(EROFS_FS|EROFS_FS_ZIP|EROFS_FS_ZIP_LZMA|EROFS_FS_ZIP_ZSTD|SQUASHFS|SQUASHFS_ZSTD|SQUASHFS_XZ|SPI_HID|ATH12K|DRM_MSM|VIDEO_QCOM_IRIS)=' "$R/usr/lib/modules/"*/config 2>/dev/null | sed "s|.*/config:||" | tr '\n' ' '; echo
echo "=== Unser Kernel: EROFS/SQUASHFS-Optionen"
grep -E '^CONFIG_(EROFS_FS|EROFS_FS_ZIP|EROFS_FS_ZIP_LZMA|EROFS_FS_ZIP_ZSTD|EROFS_FS_ZIP_DEFLATE|SQUASHFS|SQUASHFS_ZSTD|SQUASHFS_XZ|SQUASHFS_LZ4|OVERLAY_FS|DM_SNAPSHOT|BLK_DEV_LOOP)=' /work/sl7/kernel/ellx-7.0-sl7/.config | tr '\n' ' '; echo
umount "$R"
echo "=== ItsLucas-Quelle"; ls -la "$W/src/" 2>/dev/null
