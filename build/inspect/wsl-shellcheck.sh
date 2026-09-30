#!/usr/bin/env bash
# Statische Pruefung aller Projekt-Skripte mit shellcheck (nur Fehler und Warnungen).
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
command -v shellcheck >/dev/null 2>&1 || apt-get install -y -qq shellcheck >/dev/null 2>&1
command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck nicht verfuegbar"; exit 0; }
cd "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build" || exit 1
for f in wsl-*.sh out/sl7-install-on-laptop.sh; do
  out=$(shellcheck -S warning -e SC1090,SC1091,SC2086,SC2012 "$f" 2>&1)
  if [ -z "$out" ]; then echo "SAUBER  $f"; else echo "=== $f"; echo "$out" | head -40; fi
done
