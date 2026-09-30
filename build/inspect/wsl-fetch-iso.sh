#!/usr/bin/env bash
# Laedt das offizielle Ubuntu-26.04.1-arm64-Desktop-ISO nach "Projekt Linux ARM/iso" und prueft die Pruefsumme.
# Aufruf (als root in WSL):  bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/inspect/wsl-fetch-iso.sh"
set -uo pipefail
export LC_ALL=C
BASE="https://cdimage.ubuntu.com/releases/26.04/release"
ISO="ubuntu-26.04.1-desktop-arm64.iso"
D="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/iso"
mkdir -p "$D"; cd "$D" || exit 1

echo "=== Pruefsummen holen"
curl -sL --fail --max-time 60 -o SHA256SUMS "$BASE/SHA256SUMS" || { echo "SHA256SUMS nicht ladbar"; exit 1; }
grep "$ISO" SHA256SUMS || { echo "$ISO steht nicht in SHA256SUMS"; exit 1; }

echo "=== ISO laden (3,9 GB, Fortsetzung moeglich)"
curl -L --fail --retry 5 --retry-delay 5 -C - -o "$ISO" "$BASE/$ISO" --progress-bar || { echo "Download abgebrochen - Skript einfach erneut starten, es setzt fort"; exit 1; }
ls -la "$ISO"

echo "=== SHA256 pruefen (dauert ein bis zwei Minuten)"
if grep "$ISO" SHA256SUMS | sha256sum -c -; then
  echo
  echo "OK - ISO ist vollstaendig und unveraendert."
  echo "Naechster Schritt: Ventoy 1.1.17 auf den USB-Stick, dann diese Datei einfach daraufkopieren."
else
  echo
  echo "PRUEFSUMME FALSCH - Datei loeschen und neu laden. Genau dieser Fehler kostete in der Community einen halben Tag."
  exit 1
fi
