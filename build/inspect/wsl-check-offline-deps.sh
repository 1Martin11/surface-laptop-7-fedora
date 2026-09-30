#!/usr/bin/env bash
# Prueft im arm64-Chroot, was der Ziel-Installer offline braucht: Abhaengigkeiten von iptsd und sl7-mac,
# und ob die noetigen Werkzeuge in einem frischen Ubuntu-26.04-Desktop schon vorhanden sind.
set -uo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
CH=/work/sl7/chroot-arm64
OUT="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out"
for m in proc sys dev dev/pts; do mountpoint -q "$CH/$m" || mount --bind "/$m" "$CH/$m"; done
mkdir -p "$CH/tmp/deps"
cp -f "$OUT/ellx-iptsd/iptsd_3.1.0-1_arm64.deb" "$OUT"/sl7-mac_*.deb "$CH/tmp/deps/" 2>/dev/null

chroot "$CH" bash <<'EOS'
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
echo "=== Deklarierte Abhaengigkeiten"
for f in /tmp/deps/*.deb; do
  echo "--- $(basename "$f")"
  dpkg-deb -f "$f" Package Version Depends Recommends 2>/dev/null
done
echo
echo "=== Welche davon fehlen in diesem Minimal-Chroot?"
apt-get update -qq 2>/dev/null
for f in /tmp/deps/*.deb; do
  deps=$(dpkg-deb -f "$f" Depends 2>/dev/null | tr ',' '\n' | sed 's/(.*)//; s/|.*//; s/^ *//; s/ *$//' | grep -v '^$')
  for d in $deps; do
    if dpkg -s "$d" >/dev/null 2>&1; then :; else echo "FEHLT: $d  (fuer $(basename "$f"))"; fi
  done
done
echo
echo "=== Werkzeuge, die der Installer benutzt"
for t in dpkg dracut update-grub systemctl udevadm dconf tar findmnt blkid stat install sha256sum; do
  if command -v "$t" >/dev/null 2>&1; then echo "OK    $t"; else echo "FEHLT $t"; fi
done
echo
echo "=== Pakete, die ein Ubuntu-26.04-DESKTOP normalerweise mitbringt (Gegenprobe)"
for p in linux-firmware dracut initramfs-tools grub-efi-arm64 pipewire wireplumber dconf-cli; do
  printf '%-22s %s\n' "$p" "$(apt-cache policy "$p" 2>/dev/null | sed -n '2p' | tr -d ' ')"
done
EOS
