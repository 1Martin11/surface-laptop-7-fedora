#!/usr/bin/env bash
# Fedora-Chroot: Einstieg testen (qemu-user), SELinux-xattrs pruefen, dann iptsd bauen (wsl-fedora-iptsd.sh).
set -uo pipefail; export LC_ALL=C
B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"; R=/work/sl7/fedora/rootfs
sed -i 's/\r$//' "$B/wsl-fedora-chroot.sh" "$B/wsl-fedora-iptsd.sh"
echo "xattr etc/passwd:   $(getfattr -m security.selinux -d "$R/etc/passwd" 2>/dev/null | tail -1)"
echo "xattr usr/bin/bash: $(getfattr -m security.selinux -d "$R/usr/bin/bash" 2>/dev/null | tail -1)"
ls -la "$R/etc/resolv.conf"; cat "$R/etc/selinux/config" 2>/dev/null | grep -v '^#' | grep .
bash "$B/wsl-fedora-chroot.sh" mount || exit 1
bash "$B/wsl-fedora-chroot.sh" run rpm -q kernel-core dracut grub2-efi-aa64 systemd systemd-ukify 2>&1
bash "$B/wsl-fedora-chroot.sh" run dnf --version 2>&1 | head -1
echo "=== iptsd"; time bash "$B/wsl-fedora-iptsd.sh"
