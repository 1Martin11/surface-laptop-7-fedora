#!/usr/bin/env bash
# Probelauf des Ziel-Installers im arm64-Chroot (DRYRUN=1, danach optional echt).
# Prueft die Logik end-to-end, ohne echte Hardware.
set -uo pipefail
export LC_ALL=C
CH=/work/sl7/chroot-arm64
OUT="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out"
for m in proc sys dev dev/pts; do mountpoint -q "$CH/$m" || mount --bind "/$m" "$CH/$m"; done
mkdir -p "$CH/opt/sl7out"
echo "=== Artefakte ins Chroot spiegeln (nur die kleinen Dateien + Paketliste)"
rsync -a --exclude '*.deb' --exclude '*.tar.xz' "$OUT/" "$CH/opt/sl7out/" 2>/dev/null
# Platzhalter fuer die grossen Dateien anlegen, damit die Namenslogik geprueft wird
for d in "$OUT"/7.0.0-rc4-sl7-*; do
  [ -d "$d" ] || continue
  b=$(basename "$d"); mkdir -p "$CH/opt/sl7out/$b"
  for f in "$d"/*.deb; do [ -f "$f" ] || continue; : > "$CH/opt/sl7out/$b/$(basename "$f")"; done
done
for f in "$OUT"/sl7-firmware-msi-*.tar.xz "$OUT"/sl7-mac_*.deb "$OUT"/ellx-iptsd/*.deb; do
  [ -f "$f" ] || continue
  rel=${f#"$OUT"/}; mkdir -p "$CH/opt/sl7out/$(dirname "$rel")"; : > "$CH/opt/sl7out/$rel"
done
ls -R "$CH/opt/sl7out" | head -25
echo
echo "=== DRYRUN im Chroot"
chroot "$CH" bash -c 'cd /opt/sl7out && DRYRUN=1 bash sl7-install-on-laptop.sh' 2>&1 | tail -60
echo "=== Exit: $?"
echo
echo "=== DRYRUN mit SL7_NO_SPEAKER=1 (nur der Audio-Abschnitt)"
chroot "$CH" bash -c 'cd /opt/sl7out && DRYRUN=1 SL7_NO_SPEAKER=1 bash sl7-install-on-laptop.sh' 2>&1 | grep -A3 'Lautsprecher-Schutz'
