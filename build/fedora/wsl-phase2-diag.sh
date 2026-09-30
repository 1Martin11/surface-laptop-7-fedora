#!/usr/bin/env bash
export LC_ALL=C; R=/work/sl7/fedora/rootfs
echo "=== lib/bin/sbin/lib64 im Rootfs:"; ls -ld "$R/lib" "$R/lib64" "$R/bin" "$R/sbin" "$R/usr/lib/firmware/updates" 2>&1
echo "--- Inhalt von \$R/lib (falls Verzeichnis):"; [ -L "$R/lib" ] || ls "$R/lib" "$R/lib/firmware" 2>&1 | head
echo "--- find updates:"; find "$R/lib/firmware/updates" "$R/usr/lib/firmware/updates" -type f 2>/dev/null | wc -l
echo "=== Kernel-Verzeichnisse:"; ls -d "$R"/usr/lib/modules/* "$R"/boot/dtb-* 2>&1; ls -la "$R"/boot/vmlinuz-* 2>&1
echo "=== phase2.log (dracut-Fehler):"; grep -n -iE 'error|fail|cannot|No such|not found|Failed' /work/sl7/fedora/phase2.log | head -20; echo "--- letzte 25 Zeilen:"; tail -25 /work/sl7/fedora/phase2.log
echo "=== Mounts:"; mount | grep "$R" | awk '{print $3}'
