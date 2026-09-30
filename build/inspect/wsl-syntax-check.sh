#!/usr/bin/env bash
# bash -n Syntaxpruefung aller Build-Skripte und des Ziel-Installers
export LC_ALL=C
cd "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build" || exit 1
rc=0
for f in wsl-*.sh out/sl7-install-on-laptop.sh; do
  if bash -n "$f" 2>/tmp/err; then echo "OK      $f"; else echo "FEHLER  $f"; cat /tmp/err; rc=1; fi
done
exit $rc
