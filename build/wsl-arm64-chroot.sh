#!/usr/bin/env bash
# Legt ein natives arm64-Ubuntu-26.04-Chroot in WSL an (qemu-user binfmt), um
#   - das selbstgebaute Kernel-.deb testweise zu installieren (postinst, initramfs, DTB-Pfade pruefen)
#   - iptsd / sl7-mac nativ fuer arm64 zu bauen
# Aufruf (als root in WSL):  bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-arm64-chroot.sh"
set -euo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
CH=/work/sl7/chroot-arm64
MIRROR=http://ports.ubuntu.com/ubuntu-ports

echo "=== binfmt-Status"
cat /proc/sys/fs/binfmt_misc/qemu-aarch64 2>/dev/null | head -4 || { echo "kein qemu-aarch64 binfmt"; exit 1; }
FLAGS=$(grep -oP '^flags: \K.*' /proc/sys/fs/binfmt_misc/qemu-aarch64 || true)
QEMU=$(grep -oP '^interpreter \K.*' /proc/sys/fs/binfmt_misc/qemu-aarch64)
echo "    interpreter=$QEMU flags=$FLAGS"
file -L "$QEMU" | sed 's/^/    /'
if ! echo "$FLAGS" | grep -q F; then
  echo "    Hinweis: kein F-Flag -> qemu muss ins Chroot kopiert werden (statisch noetig)"
fi

if [ ! -x "$CH/bin/bash" ] && [ ! -x "$CH/usr/bin/bash" ]; then
  echo "=== debootstrap arm64 resolute -> $CH"
  rm -rf "$CH"
  if echo "$FLAGS" | grep -q F && file -L "$QEMU" | grep -q "statically linked"; then
    debootstrap --arch=arm64 --variant=minbase resolute "$CH" "$MIRROR" 2>&1 | tail -3
  else
    debootstrap --arch=arm64 --variant=minbase --foreign resolute "$CH" "$MIRROR" 2>&1 | tail -3
    mkdir -p "$CH/usr/bin"; cp "$QEMU" "$CH/usr/bin/" || true
    chroot "$CH" /debootstrap/debootstrap --second-stage 2>&1 | tail -3
  fi
fi

echo "=== Chroot-Test"
chroot "$CH" uname -m
chroot "$CH" dpkg --print-architecture
cat > "$CH/etc/apt/sources.list" <<EOF
deb $MIRROR resolute main restricted universe multiverse
deb $MIRROR resolute-updates main restricted universe multiverse
deb $MIRROR resolute-security main restricted universe multiverse
EOF
mount -t proc proc "$CH/proc" 2>/dev/null || true
mount --bind /dev "$CH/dev" 2>/dev/null || true
mount --bind /dev/pts "$CH/dev/pts" 2>/dev/null || true
mount -t sysfs sys "$CH/sys" 2>/dev/null || true
echo "=== Pakete im Chroot (initramfs-tools, grub, linux-firmware, Build-Werkzeuge fuer iptsd)"
chroot "$CH" bash -c "apt-get update -qq && apt-get install -y -qq initramfs-tools zstd kmod grub-efi-arm64-bin linux-firmware build-essential meson ninja-build pkg-config cmake git debhelper devscripts libcli11-dev libeigen3-dev libfmt-dev libspdlog-dev libinih-dev libgsl-dev libsdl2-dev libhidrs-dev 2>&1 | grep -vE '^(Selecting|Preparing|Unpacking|Setting up|Processing)' | tail -8" || true
echo "=== fertig: $CH"
du -sh "$CH"
