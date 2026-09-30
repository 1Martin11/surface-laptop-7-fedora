#!/usr/bin/env bash
export LC_ALL=C; W=/work/sl7/fedora
for f in $W/qemu-test1.log $W/qemu-test2.log $W/qemu-test3.log; do
  [ -f "$f" ] || continue; echo "=== $f ($(stat -c %s "$f") B)"
  grep -a -n 'login:\|qemu-drive\|Reached target graphical\|Linux version\|Machine model\|sddm\|Failed to start\|emergency\|panic' "$f" | tr -d '\r' | cut -c1-160 | tail -14
  echo "--- letzte Zeilen:"; tail -c 1200 "$f" | tr -d '\r' | grep -v '^\s*$' | tail -8 | cut -c1-160
done
echo "--- laufende qemu: $(pgrep -c qemu-system-aarch64)"
