#!/usr/bin/env bash
# Phase 3: Rootfs -> squashfs (zstd), Boot-Dateien (Kernel A/B, initrds, DTBs, grub.cfg) zusammenstellen,
# ISO per xorriso aus dem Original-ISO nachbauen (Boot-Ausruestung "replay"), Pruefsummen.
set -uo pipefail; export LC_ALL=C
B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"; WINOUT="$B/out/iso"
W=/work/sl7/fedora; R=$W/rootfs; ISO_IN=$W/iso/Fedora-KDE-Desktop-Live-44-1.7.aarch64.iso; S=$W/stage; OUT=$W/out
KA=7.0.0-rc4-sl7; KB=7.3.0-rc3-sl7b; ISONAME=${ISONAME:-Fedora-KDE-Live-44-SL7-$(date +%Y%m%d)}
fail() { echo "FEHLER: $*"; exit 1; }
[ -f "$R/lib/modules/$KB/vmlinuz-dtbloader.efi" ] && [ -f "$R/boot/initramfs-$KB.img" ] || fail "Phase 2 nicht abgeschlossen"
for m in proc sys dev/pts dev run; do mountpoint -q "$R/$m" && umount -l "$R/$m"; done
mkdir -p "$S/LiveOS" "$S/boot/aarch64/loader" "$S/boot/dtb/sl7a" "$S/boot/dtb/sl7b" "$S/boot/grub2" "$OUT" "$WINOUT"

echo "=== [1] squashfs (zstd 19) aus $R - Ziel < 4 GiB (keine Multi-Extent-Dateien im ISO)"
# Rescue-Kernel/-initramfs des kiwi-Builds sind im Live-System nutzlos (Anaconda erzeugt Rescue-Eintraege neu) -> raus
rm -f "$R"/boot/vmlinuz-0-rescue-* "$R"/boot/initramfs-0-rescue-* "$R"/boot/loader/entries/*-0-rescue.conf
rm -f "$S/LiveOS/squashfs.img"; START=$(date +%s)
mksquashfs "$R" "$S/LiveOS/squashfs.img" -comp zstd -Xcompression-level 19 -b 1M -noappend -xattrs -no-recovery -processors "$(nproc)"   -wildcards -e 'proc/*' 'sys/*' 'dev/*' 'run/*' 'tmp/*' 'var/tmp/*' 'etc/resolv.conf.sl7' > "$W/mksquashfs.log" 2>&1 || { tail -5 "$W/mksquashfs.log"; fail "mksquashfs"; }
SZ=$(stat -c %s "$S/LiveOS/squashfs.img"); echo "    $SZ B in $(( $(date +%s)-START )) s"; grep -E 'Filesystem size' "$W/mksquashfs.log" | sed 's/^/    /'
[ "$SZ" -lt 4294967296 ] || echo "    WARNUNG: squashfs >= 4 GiB (Multi-Extent im ISO9660)"
rm -rf /tmp/sqx && unsquashfs -q -n -d /tmp/sqx "$S/LiveOS/squashfs.img" usr/bin/sl7-mac etc/sl7-release >/dev/null 2>&1
echo "    xattr-Probe im Image: $(getfattr --absolute-names --only-values -n security.selinux /tmp/sqx/usr/bin/sl7-mac 2>/dev/null || echo FEHLT)  sl7-release: $(head -1 /tmp/sqx/etc/sl7-release 2>/dev/null)"; rm -rf /tmp/sqx

echo "=== [2] Boot-Dateien"
cp -f "$R/lib/modules/$KA/vmlinuz-dtbloader.efi" "$S/boot/aarch64/loader/linux-sl7a"; cp -f "$R/lib/modules/$KA/vmlinuz" "$S/boot/aarch64/loader/vmlinuz-sl7a"; cp -f "$R/boot/initramfs-$KA.img" "$S/boot/aarch64/loader/initrd-sl7a"
cp -f "$R/lib/modules/$KB/vmlinuz-dtbloader.efi" "$S/boot/aarch64/loader/linux-sl7b"; cp -f "$R/lib/modules/$KB/vmlinuz" "$S/boot/aarch64/loader/vmlinuz-sl7b"; cp -f "$R/boot/initramfs-$KB.img" "$S/boot/aarch64/loader/initrd-sl7b"
cp -f "$R"/lib/modules/$KA/dtb/qcom/x1e80100-microsoft-romulus1[35]*.dtb "$S/boot/dtb/sl7a/"; cp -f "$R"/lib/modules/$KB/dtb/qcom/x1e80100-microsoft-romulus1[35]*.dtb "$S/boot/dtb/sl7b/"
sed 's/\r$//' "$B/grub-sl7.cfg" > "$S/boot/grub2/grub.cfg"
grub-script-check "$S/boot/grub2/grub.cfg" 2>/dev/null && echo "    grub.cfg: Syntax ok" || echo "    (grub-script-check nicht verfuegbar oder Fehler)"
[ -f "$W/analyse/isofs/boot/aarch64/loader/grub2/fonts/unicode.pf2" ] && echo "    gfxterm-Font auf dem ISO: ja" || echo "    WARNUNG: unicode.pf2 fehlt auf dem ISO (gfxterm-Block faellt auf console zurueck)"
for f in $(grep -oE '\$L/[a-z0-9-]+|\$D/sl7[ab]/[a-z0-9.-]+' "$S/boot/grub2/grub.cfg" | sort -u); do p=${f/\$L/boot/aarch64/loader}; p=${p/\$D/boot/dtb}; [ -f "$S/$p" ] || [ "$p" = boot/aarch64/loader/linux ] || [ "$p" = boot/aarch64/loader/initrd ] || echo "    FEHLT im Stage: $p"; done
ls -la "$S/boot/aarch64/loader/" "$S/boot/dtb/sl7a/" "$S/boot/dtb/sl7b/" | sed 's/^/    /'

echo "=== [3] ISO bauen (xorriso, Boot-Ausruestung des Originals uebernehmen)"
ISO_OUT="$OUT/$ISONAME.iso"; rm -f "$ISO_OUT"; START=$(date +%s)
xorriso -indev "$ISO_IN" -outdev "$ISO_OUT" -boot_image any replay -volid Fedora-KDE-Live-44 -overwrite on \
  -update "$S/LiveOS/squashfs.img" /LiveOS/squashfs.img \
  -update "$S/boot/grub2/grub.cfg" /boot/grub2/grub.cfg \
  -map "$S/boot/aarch64/loader/linux-sl7a" /boot/aarch64/loader/linux-sl7a \
  -map "$S/boot/aarch64/loader/vmlinuz-sl7a" /boot/aarch64/loader/vmlinuz-sl7a \
  -map "$S/boot/aarch64/loader/initrd-sl7a" /boot/aarch64/loader/initrd-sl7a \
  -map "$S/boot/aarch64/loader/linux-sl7b" /boot/aarch64/loader/linux-sl7b \
  -map "$S/boot/aarch64/loader/vmlinuz-sl7b" /boot/aarch64/loader/vmlinuz-sl7b \
  -map "$S/boot/aarch64/loader/initrd-sl7b" /boot/aarch64/loader/initrd-sl7b \
  -map "$S/boot/dtb" /boot/dtb \
  -map "$B/SL7-Hinweise.txt" /SL7-Hinweise.txt \
  -map "$B/ventoy-initrd.cfg" /boot/grub/grub.cfg \
  -end > "$W/xorriso.log" 2>&1 || { tail -15 "$W/xorriso.log"; fail "xorriso"; }
echo "    $(stat -c %s "$ISO_OUT") B in $(( $(date +%s)-START )) s"
echo "--- Medien-Pruefsumme einpflanzen (implantisomd5, fuer 'Medium pruefen' / rd.live.check)"
command -v implantisomd5 >/dev/null || apt-get install -y -qq isomd5sum >/dev/null 2>&1
implantisomd5 --supported-iso "$ISO_OUT" 2>&1 | tail -1 | sed 's/^/    /'; checkisomd5 --verbose "$ISO_OUT" 2>&1 | tail -2 | sed 's/^/    /'
echo "=== [4] Pruefung"
xorriso -indev "$ISO_OUT" -report_el_torito plain -pvd_info 2>/dev/null | grep -E 'El Torito boot img|Volume Id' | sed 's/^/    /'
xorriso -indev "$ISO_OUT" -find /boot/aarch64/loader /boot/dtb /LiveOS /boot/grub2/grub.cfg -exec lsdl 2>/dev/null | grep -v '^xorriso' | sed 's/^/    /' | head -40
echo "=== [5] Pruefsummen + Kopie nach Windows"
(cd "$OUT" && sha256sum "$ISONAME.iso" > "$ISONAME.iso.sha256"); cat "$OUT/$ISONAME.iso.sha256"
cp -f "$ISO_OUT" "$OUT/$ISONAME.iso.sha256" "$WINOUT/" && echo "    -> $WINOUT/$ISONAME.iso"
echo "=== Phase 3 fertig: $ISO_OUT"
