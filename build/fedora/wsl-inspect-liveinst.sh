#!/usr/bin/env bash
# Inspektion: kann Anaconda im Live-System ohne GUI (cmdline/kickstart) installieren? Voraussetzungen fuer QEMU-Installationstest.
set -uo pipefail; export LC_ALL=C
R=/work/sl7/fedora/rootfs; B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"
echo "=== liveinst-Skripte"; find "$R/usr" -name 'liveinst*' -not -path '*/locale/*' 2>/dev/null | head
for f in $(find "$R/usr" -name 'liveinst' -type f 2>/dev/null | head -2); do echo "--- $f"; cat "$f" | grep -v '^\s*#' | grep -v '^\s*$' | head -120; done
PY=$(ls -d "$R"/usr/lib/python3.*/site-packages/pyanaconda 2>/dev/null | head -1); echo "=== pyanaconda: $PY"
echo "--- display.py (live/text/cmdline-Stellen)"; grep -nE 'live|cmdline|noninteractive|TUI|text mode|Text mode' "$PY/display.py" | head -60
echo "--- argument_parsing.py (Optionen)"; grep -nE '"--(liveinst|cmdline|kickstart|noninteractive|text|dirinstall|image)"|-C|-T' "$PY/argument_parsing.py" | head -30
echo "--- anaconda.py / startup: liveinst-Verarbeitung"; grep -rnE 'liveinst|livecdInstall|is_live' "$PY"/*.py "$PY"/core/*.py 2>/dev/null | grep -v '^.*#' | head -40
echo "--- Live-Payload-Auswahl"; grep -rnE 'LIVE_OS|live_os|LiveOS' "$PY"/*.py "$PY"/core/*.py "$PY"/modules/payloads/*.py 2>/dev/null | head -20
echo "=== anaconda.conf Auszug"; grep -nE '^\[|^default_source|^type|^is_live|^can_|^flatpak|^installation_target|^live' "$R/etc/anaconda/anaconda.conf" | head -40
echo "--- conf.d + profile.d"; ls "$R/etc/anaconda/conf.d" "$R/etc/anaconda/profile.d" 2>/dev/null; grep -rn "" "$R/etc/anaconda/conf.d/"*.conf 2>/dev/null | grep -v '#' | head -30
for f in "$R"/etc/anaconda/profile.d/fedora-kde*.conf "$R"/etc/anaconda/profile.d/fedora.conf; do [ -f "$f" ] && { echo "--- $f"; grep -v '^#' "$f" | grep -v '^$' | head -40; }; done
echo "=== liveuser"; grep -E '^liveuser' "$R/etc/passwd" "$R/etc/shadow"; ls -la "$R/etc/sudoers.d/" 2>/dev/null; cat "$R"/etc/sudoers.d/* 2>/dev/null | grep -v '^#'
grep -nE 'nullok' "$R/etc/pam.d/system-auth" "$R/etc/pam.d/password-auth" "$R/etc/pam.d/login" 2>/dev/null | head; grep -n 'root' "$R/etc/shadow" | head -1 | cut -c1-30
echo "--- getty/autologin"; ls "$R"/etc/systemd/system/getty@tty1.service.d/ 2>/dev/null; cat "$R"/etc/systemd/system/getty@tty1.service.d/*.conf 2>/dev/null; ls "$R"/usr/lib/systemd/system/*live* 2>/dev/null
echo "=== Pakete (Chroot)"; bash "$B/wsl-fedora-chroot.sh" mount >/dev/null 2>&1
bash "$B/wsl-fedora-chroot.sh" run rpm -qa 2>/dev/null | grep -E '^(anaconda|shim|grub2-efi|efibootmgr|python3-kickstart|pykickstart|grub2-tools|grubby|dracut|kernel)' | sort
bash "$B/wsl-fedora-chroot.sh" umount >/dev/null 2>&1
echo "--- shim/EFI-Dateien"; ls -la "$R"/boot/efi/EFI/BOOT/ "$R"/boot/efi/EFI/fedora/ 2>/dev/null | head -20
echo "=== Host: EFI-Firmware/QEMU/Platz"; ls -la /usr/share/qemu-efi-aarch64/ /usr/share/AAVMF/ 2>/dev/null; which qemu-img qemu-system-aarch64; df -h /work | tail -1; free -g | head -2; nproc
