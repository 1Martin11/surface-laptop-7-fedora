#!/usr/bin/env bash
# Testet die drei Ziel-Skripte im arm64-Chroot: Syntax, Dach-Skript (Selbsttest + Probelauf), check, optimize.
set -uo pipefail
export LC_ALL=C
CH=/work/sl7/chroot-arm64
OUT="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out"
echo "=== Syntaxpruefung"
for f in SL7-INSTALLIEREN.sh sl7-install-on-laptop.sh sl7-check.sh sl7-optimize.sh; do
  if bash -n "$OUT/$f" 2>/tmp/e; then echo "  OK    $f"; else echo "  FEHLER $f"; cat /tmp/e; fi
done
if command -v shellcheck >/dev/null 2>&1; then
  echo "=== shellcheck (nur Fehler)"
  for f in SL7-INSTALLIEREN.sh sl7-check.sh sl7-optimize.sh; do
    o=$(shellcheck -S error -e SC1090,SC1091,SC2086,SC2012,SC2010 "$OUT/$f" 2>&1)
    [ -z "$o" ] && echo "  sauber $f" || { echo "  === $f"; echo "$o" | head -20; }
  done
fi

for m in proc sys dev dev/pts; do mountpoint -q "$CH/$m" || mount --bind "/$m" "$CH/$m"; done
echo
echo "=== Testordner im Chroot aufbauen (Platzhalter statt der grossen Pakete)"
rm -rf "$CH/opt/sl7out"; mkdir -p "$CH/opt/sl7out"
rsync -a --exclude '*.deb' --exclude '*.tar.xz' "$OUT/" "$CH/opt/sl7out/"
for d in "$OUT"/7.0.0-rc4-sl7-*; do
  [ -d "$d" ] || continue; b=$(basename "$d"); mkdir -p "$CH/opt/sl7out/$b"
  for f in "$d"/*.deb; do [ -f "$f" ] && : > "$CH/opt/sl7out/$b/$(basename "$f")"; done
done
for f in "$OUT"/sl7-firmware-msi-*.tar.xz "$OUT"/sl7-mac_*.deb "$OUT"/ellx-iptsd/*.deb; do
  [ -f "$f" ] || continue; rel=${f#"$OUT"/}; mkdir -p "$CH/opt/sl7out/$(dirname "$rel")"; : > "$CH/opt/sl7out/$rel"
done

echo
echo "=== Dach-Skript: Abbruch bei 'nein' (Selbsttest + Probelauf muessen durchlaufen)"
chroot "$CH" bash -c 'cd /opt/sl7out && printf "n\n" | bash SL7-INSTALLIEREN.sh' 2>&1 | tail -45
echo "  Exit: ${PIPESTATUS[0]}"

echo
echo "=== Dach-Skript: Selbsttest muss fehlschlagen, wenn die Firmware fehlt"
mv "$CH/opt/sl7out/sl7-firmware-msi-26100_26.053.36539.0.tar.xz" /tmp/fw.bak 2>/dev/null
chroot "$CH" bash -c 'cd /opt/sl7out && bash SL7-INSTALLIEREN.sh' 2>&1 | grep -E '\!|Selbsttest' | head -6
mv /tmp/fw.bak "$CH/opt/sl7out/sl7-firmware-msi-26100_26.053.36539.0.tar.xz" 2>/dev/null

echo
echo "=== sl7-check.sh im Chroot (dort fehlt echte Hardware, es geht nur um Durchlauf ohne Absturz)"
chroot "$CH" bash -c 'cd /opt/sl7out && bash sl7-check.sh' 2>&1 | tail -25
echo "  Exit: ${PIPESTATUS[0]}"

echo
echo "=== sl7-optimize.sh Probelauf"
chroot "$CH" bash -c 'cd /opt/sl7out && DRYRUN=1 bash sl7-optimize.sh' 2>&1 | tail -22
echo "  Exit: ${PIPESTATUS[0]}"
