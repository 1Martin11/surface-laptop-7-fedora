#!/usr/bin/env bash
# Live-Rootfs (EROFS) per erofsfuse mounten, DTB-/Boot-Logik pruefen, dann komplett nach /work/sl7/fedora/rootfs kopieren (Remaster-Basis).
set -uo pipefail
export LC_ALL=C
W=/work/sl7/fedora; IMG="$W/analyse/isofs/LiveOS/squashfs.img"; R="$W/rootfs"; F="$W/efs"
rm -f "$W/rootfs.img"
mkdir -p "$F"; mountpoint -q "$F" || erofsfuse "$IMG" "$F" || { echo "erofsfuse fehlgeschlagen"; exit 1; }
echo "=== Live-System"; head -2 "$F/etc/os-release"; ls "$F/usr/lib/modules/"
M=$(ls -d "$F"/usr/lib/modules/* | head -1)
echo "vmlinuz: $(stat -c %s "$M/vmlinuz") Bytes  dtb: $([ -d "$M/dtb" ] && echo "$M/dtb" || echo nein)"
ls "$M"/dtb/qcom/ 2>/dev/null | grep -iE 'x1e80100-microsoft' | sed 's/^/   /'; echo "   qcom-DTBs: $(ls "$M"/dtb/qcom/ 2>/dev/null | wc -l)"
echo "--- /boot:"; ls "$F/boot/" | tr '\n' ' '; echo; ls -d "$F"/boot/dtb* 2>/dev/null
echo "--- BLS:"; ls "$F/boot/loader/entries/" 2>/dev/null; cat "$F/boot/loader/entries/"*.conf 2>/dev/null | head -10
echo "--- /etc/kernel/cmdline: $(cat "$F/etc/kernel/cmdline" 2>/dev/null)"
echo "--- /etc/default/grub:"; grep -v '^#' "$F/etc/default/grub" 2>/dev/null
echo "--- kernel-install Plugins: $(ls "$F/usr/lib/kernel/install.d/" 2>/dev/null | tr '\n' ' ')"
echo "--- devicetree in 90-loaderentry / 20-grub / grubby:"; grep -n -i 'devicetree\|dtb' "$F/usr/lib/kernel/install.d/"*.install 2>/dev/null | head -12
echo "--- grub.d 10_linux devicetree/DTB:"; grep -n -i 'devicetree\|DEFAULT_DTB\|dtb' "$F/etc/grub.d/10_linux" 2>/dev/null | head -10; ls "$F/etc/grub.d/"
echo "--- grub2-Version: $(rpm --root "$F" -q grub2-common 2>/dev/null)  systemd: $(rpm --root "$F" -q systemd 2>/dev/null)  dracut: $(rpm --root "$F" -q dracut 2>/dev/null)"
echo "--- dracut conf:"; ls "$F/etc/dracut.conf.d/" "$F/usr/lib/dracut/dracut.conf.d/" 2>/dev/null | tr '\n' ' '; echo; cat "$F/etc/dracut.conf.d/"*.conf "$F/usr/lib/dracut/dracut.conf.d/"*.conf 2>/dev/null | grep -v '^#' | grep -v '^$' | head -12
echo "--- Firmware: ath12k=$(ls "$F/usr/lib/firmware/ath12k/WCN7850/hw2.0/" 2>/dev/null | tr '\n' ' ')"; echo "    qcom/x1e80100: $(ls "$F/usr/lib/firmware/qcom/x1e80100/" 2>/dev/null | tr '\n' ' ' | cut -c1-300)"; echo "    qca hmt: $(ls "$F/usr/lib/firmware/qca/" 2>/dev/null | grep -ci hmt)  gen70500: $(ls "$F/usr/lib/firmware/qcom/" 2>/dev/null | grep -c gen70500)"
echo "--- Pakete: $(rpm --root "$F" -qa 2>/dev/null | wc -l)"; for p in kernel-core kernel-dtb-loader linux-firmware qcom-firmware atheros-firmware iptsd libinput pipewire alsa-ucm-conf plymouth dracut grub2-efi-aa64 shim-aa64 grubby systemd-ukify mesa-vulkan-drivers anaconda-live plasma-desktop kiwi-systemdeps; do printf '    %-22s %s\n' "$p" "$(rpm --root "$F" -q "$p" 2>/dev/null | head -1)"; done
echo "--- Live-Kernel-Config: $(grep -E '^CONFIG_(EROFS_FS|EROFS_FS_ZIP_LZMA|SQUASHFS|SQUASHFS_ZSTD|SPI_HID|ATH12K|VIDEO_QCOM_IRIS)=' "$M/config" 2>/dev/null | tr '\n' ' ')"
echo
echo "=== Kopie nach $R (cp -a, dauert)"; rm -rf "$R"; mkdir -p "$R"; START=$(date +%s)
cp -a "$F/." "$R/" 2>&1 | grep -v 'Operation not supported' | tail -3
echo "Dauer: $(( $(date +%s) - START ))s"; du -sh "$R"; ls "$R"
fusermount -u "$F" 2>/dev/null || umount "$F" 2>/dev/null
echo "=== fertig"
