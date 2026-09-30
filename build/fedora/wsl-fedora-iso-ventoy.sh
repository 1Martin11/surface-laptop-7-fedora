#!/usr/bin/env bash
# Ventoy-Nachruestung: aus dem fertigen SL7-ISO ein neues mit /boot/grub/grub.cfg (initrd-Liste fuer Ventoy) erzeugen. squashfs bleibt gleich.
set -uo pipefail; export LC_ALL=C
B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"; W=/work/sl7/fedora; OUT=$W/out
IN=$OUT/Fedora-KDE-Live-44-SL7-20260922.iso; NAME=Fedora-KDE-Live-44-SL7-20260930; NEW=$OUT/$NAME.iso
[ -f "$IN" ] || { echo "Ausgangs-ISO fehlt"; exit 1; }
sed 's/\r$//' "$B/ventoy-initrd.cfg" > $W/ventoy-initrd.cfg; rm -f "$NEW"
xorriso -indev "$IN" -outdev "$NEW" -boot_image any replay -volid Fedora-KDE-Live-44 -map $W/ventoy-initrd.cfg /boot/grub/grub.cfg -end > $W/xorriso-ventoy.log 2>&1 || { tail -15 $W/xorriso-ventoy.log; exit 1; }
implantisomd5 --force --supported-iso "$NEW" 2>&1 | tail -1; checkisomd5 "$NEW" >/dev/null 2>&1; echo "checkisomd5 rc=$?"
echo "--- Boot-Ausruestung alt/neu:"; for i in "$IN" "$NEW"; do xorriso -indev "$i" -report_el_torito plain 2>/dev/null | grep -E 'El Torito boot img' | tr '\n' ' '; echo; done
echo "--- neue Datei:"; xorriso -osirrox on -indev "$NEW" -extract /boot/grub/grub.cfg /tmp/vgrub.cfg 2>/dev/null; cat /tmp/vgrub.cfg
for f in initrd-sl7b initrd-sl7a initrd; do xorriso -indev "$NEW" -find /boot/aarch64/loader/$f 2>/dev/null | grep -c loader | sed "s|^|    $f vorhanden: |"; done
(cd $OUT && sha256sum $NAME.iso > $NAME.iso.sha256); cat $OUT/$NAME.iso.sha256; stat -c '%s B' "$NEW"
cp -f "$NEW" "$OUT/$NAME.iso.sha256" "$B/out/iso/" && echo "-> $B/out/iso/$NAME.iso"
