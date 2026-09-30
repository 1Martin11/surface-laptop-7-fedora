#!/usr/bin/env bash
# Helfer: Fedora-Rootfs (/work/sl7/fedora/rootfs) als arm64-Chroot betreten (qemu-user binfmt).
#   bash wsl-fedora-chroot.sh mount      -> bind-Mounts + resolv.conf einrichten
#   bash wsl-fedora-chroot.sh run CMD... -> Befehl im Chroot ausfuehren
#   bash wsl-fedora-chroot.sh umount     -> alles aushaengen
set -uo pipefail
export LC_ALL=C
R=/work/sl7/fedora/rootfs
cmd=${1:-mount}; shift || true
case "$cmd" in
  mount)
    [ -d "$R/usr" ] || { echo "Rootfs fehlt: $R"; exit 1; }
    for m in proc sys dev dev/pts; do mountpoint -q "$R/$m" || mount --bind "/$m" "$R/$m"; done
    mountpoint -q "$R/run" || mount -t tmpfs tmpfs "$R/run"
    mkdir -p "$R/run/systemd/resolve"
    cp -f /etc/resolv.conf "$R/etc/resolv.conf.sl7"; cp -f /etc/resolv.conf "$R/run/systemd/resolve/stub-resolv.conf" 2>/dev/null
    # Fedora hat /etc/resolv.conf -> ../run/systemd/resolve/stub-resolv.conf
    [ -L "$R/etc/resolv.conf" ] || cp -f /etc/resolv.conf "$R/etc/resolv.conf"
    grep -q F /proc/sys/fs/binfmt_misc/qemu-aarch64 2>/dev/null && echo "binfmt qemu-aarch64 (F) ok" || echo "WARNUNG: binfmt ohne F-Flag"
    chroot "$R" /usr/bin/uname -m && chroot "$R" /usr/bin/cat /etc/fedora-release && echo "Chroot bereit" ;;
  run)
    chroot "$R" /usr/bin/env -i HOME=/root TERM=xterm LC_ALL=C.UTF-8 LANG=C.UTF-8 PATH=/usr/sbin:/usr/bin:/sbin:/bin "$@" ;;
  umount)
    for m in run dev/pts dev sys proc; do mountpoint -q "$R/$m" && umount -l "$R/$m"; done; echo "ausgehaengt" ;;
  *) echo "mount|run CMD|umount"; exit 1 ;;
esac
