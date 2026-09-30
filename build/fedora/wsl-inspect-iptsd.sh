#!/usr/bin/env bash
R=/work/sl7/fedora/rootfs
echo '--- iptsd sleep hook:'; cat "$R/usr/lib/systemd/system-sleep/iptsd"
echo '--- udev rule:'; cat "$R/usr/lib/udev/rules.d/50-iptsd.rules"
echo '--- service:'; cat "$R/usr/lib/systemd/system/iptsd@.service"
echo '--- iptsd.conf Touchpad-Abschnitt:'; grep -n -A8 -i '^\[Touchpad\]' "$R/etc/iptsd.conf" | head -14
echo '--- Schluessel im Quelltext (Fork):'; grep -rhoE 'ButtonDebounce[A-Za-z]*|DisableOnPalm|"[A-Za-z]*Debounce[A-Za-z]*"' /work/sl7/fedora/rootfs/root/sl7/iptsd/src 2>/dev/null | sort -u | head
