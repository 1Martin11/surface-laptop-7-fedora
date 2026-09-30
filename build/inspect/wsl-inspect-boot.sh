#!/usr/bin/env bash
# Teil 4: cutmem/cmdline im installierten Ubuntu-x1e-System, STUBBLEDTBS-Berechnung, ELLX-Paket-Details.
set -uo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7
R=/work/sl7/iso-inspect/sqroot
echo "=== [1] cutmem / Snapdragon / nopauth / clk_ignore_unused in etc/grub.d, etc/default, boot/grub des Live-Systems"
grep -rn -i 'cutmem\|snapdragon\|nopauth\|clk_ignore_unused\|pd_ignore_unused\|efi=noruntime' "$R/etc/grub.d" "$R/etc/default" "$R/boot/grub" 2>/dev/null | cut -c1-220 | head -20
echo "--- 00_header Kontext (falls Treffer):"
grep -n -B4 -A12 'cutmem' "$R/etc/grub.d/00_header" 2>/dev/null | head -50
echo "--- boot/grub Inhalt:"; ls "$R/boot/grub" 2>/dev/null | head
echo
echo "=== [2] STUBBLEDTBS in den Packaging-Regeln"
git -C "$K" show HEAD:debian/rules.d/0-common-vars.mk | grep -a -n -B2 -A8 'STUBBLEDTBS' | head -40
git -C "$K" show HEAD:debian/rules.d/2-binary-arch.mk | grep -a -n -B3 -A3 'STUBBLEDTBS\|finddtbs' | head -30
echo "--- finddtbs.py:"; cat /work/sl7/iso-inspect/stubble/x/usr/libexec/stubble/finddtbs.py | head -80
echo
echo "=== [3] ELLX-Prebuilt: Nicht-Modul-Dateien + postinst"
cd /work/sl7/iso-inspect/ellx
dpkg-deb -c linux-image-ellx.deb | awk '{print $6}' | grep -v '/lib/modules/' | head -30
dpkg-deb -e linux-image-ellx.deb ctl 2>/dev/null; ls ctl; echo "--- postinst:"; cat ctl/postinst 2>/dev/null | head -40
echo
echo "=== [4] ukify verfuegbar?"
which ukify; ukify --version 2>&1 | head -1; apt-cache policy systemd-ukify | head -3
echo "=== stubble:arm64 laden"
cd /work/sl7/iso-inspect/stubble && apt-get download stubble:arm64 >/dev/null 2>&1 && ls stubble_*arm64.deb && rm -rf a64 && dpkg-deb -x stubble_*arm64.deb a64 && file a64/usr/lib/stubble/stubble.efi
