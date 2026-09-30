#!/usr/bin/env bash
# Rootfs-Zustand pruefen; falls unvollstaendig: EROFS per Kernel mounten und mit cp -a nach /work/sl7/fedora/rootfs kopieren.
set -uo pipefail
export LC_ALL=C
W=/work/sl7/fedora; R=$W/rootfs; IMG=$W/analyse/isofs/LiveOS/squashfs.img
echo "=== Zustand von $R"; ls -la "$R" 2>/dev/null | head -8; echo "Dateien: $(find "$R" -type f 2>/dev/null | wc -l)"
if [ -f "$R/etc/os-release" ] && [ -d "$R/usr/lib/modules" ]; then echo "Rootfs sieht vollstaendig aus"; else
  echo "=== unvollstaendig -> EROFS mounten"
  rm -rf "$R"; mkdir -p "$R" "$W/mnt"
  modprobe erofs 2>/dev/null; grep -c erofs /proc/filesystems | sed 's/^/erofs im Kernel: /'
  if mount -t erofs -o loop,ro "$IMG" "$W/mnt" 2>/tmp/m.err; then
    echo "gemountet; kopiere (cp -a) ..."; START=$(date +%s)
    cp -a "$W/mnt/." "$R/" 2>&1 | tail -2
    echo "Dauer: $(( $(date +%s) - START ))s"; umount "$W/mnt"
  else
    cat /tmp/m.err
    echo "=== Mount nicht moeglich -> fsck.erofs --extract in frisches Verzeichnis (ohne vorheriges mkdir)"
    rm -rf "$R"; START=$(date +%s); fsck.erofs --extract="$R" "$IMG" 2>&1 | tail -3; echo "Dauer: $(( $(date +%s) - START ))s"
  fi
fi
echo "=== Ergebnis"; du -sh "$R" 2>/dev/null; cat "$R/etc/os-release" 2>/dev/null | head -2; ls "$R/usr/lib/modules/" 2>/dev/null
M=$(ls -d "$R"/usr/lib/modules/* 2>/dev/null | head -1)
[ -n "$M" ] && { echo "--- $(basename "$M"): vmlinuz=$(stat -c %s "$M/vmlinuz" 2>/dev/null) dtb-Ordner=$([ -d "$M/dtb" ] && echo ja || echo nein)"; ls "$M/dtb/qcom/" 2>/dev/null | grep -iE 'x1e80100-microsoft' | sed 's/^/      /'; echo "      qcom-DTBs: $(ls "$M/dtb/qcom/" 2>/dev/null | wc -l)"; }
echo "--- /boot:"; ls "$R/boot/" 2>/dev/null | tr '\n' ' '; echo; ls "$R/boot/loader/entries/" 2>/dev/null; cat "$R/boot/loader/entries/"*.conf 2>/dev/null | head -10
echo "--- kernel-install Plugins:"; ls "$R/usr/lib/kernel/install.d/" 2>/dev/null | tr '\n' ' '; echo
echo "--- devicetree in kernel-install/grubby/grub.d:"; grep -rln -i 'devicetree' "$R/usr/lib/kernel/install.d/" "$R/etc/grub.d/" "$R/usr/sbin/grubby" 2>/dev/null; grep -n 'devicetree\|DTB' "$R/etc/default/grub" 2>/dev/null; grep -rn -i 'dtb' "$R/usr/lib/kernel/install.d/"*.install 2>/dev/null | head -5
echo "--- Firmware:"; ls "$R/usr/lib/firmware/ath12k/WCN7850/hw2.0/" 2>/dev/null | tr '\n' ' '; echo; echo "qcom/x1e80100: $(ls "$R/usr/lib/firmware/qcom/x1e80100/" 2>/dev/null | wc -l) Eintraege: $(ls "$R/usr/lib/firmware/qcom/x1e80100/" 2>/dev/null | tr '\n' ' ' | cut -c1-300)"; ls "$R/usr/lib/firmware/qca/" 2>/dev/null | grep -i hmt | tr '\n' ' '; echo
echo "--- Pakete:"; rpm --root "$R" -qa 2>/dev/null | wc -l; for p in kernel-core kernel-dtb-loader linux-firmware qcom-firmware atheros-firmware iptsd libinput pipewire alsa-ucm-conf plymouth dracut grub2-efi-aa64 shim-aa64 grubby systemd-ukify systemd-boot-unsigned mesa-vulkan-drivers anaconda-live fedora-kiwi-descriptions; do printf '    %-24s %s\n' "$p" "$(rpm --root "$R" -q "$p" 2>/dev/null | head -1)"; done
