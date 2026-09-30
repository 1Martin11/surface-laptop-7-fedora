#!/usr/bin/env bash
set -uo pipefail; export LC_ALL=C
R=/work/sl7/fedora/rootfs; PY=$R/usr/lib64/python3.14/site-packages/pyanaconda
echo "=== startup_utils.py 150-190 + 415-445"; sed -n '150,190p;415,445p' "$PY/startup_utils.py"
echo "=== anaconda.py 75-105"; sed -n '75,105p' "$PY/anaconda.py"
echo "=== configuration/anaconda.py 365-390"; sed -n '365,390p' "$PY/core/configuration/anaconda.py"
echo "=== display.py 145-165, 280-300, 370-400"; sed -n '145,165p;280,300p;370,400p' "$PY/display.py"
echo "=== argument_parsing SetCmdlineMode"; grep -n -A8 'class SetCmdlineMode' "$PY/argument_parsing.py"
echo "=== anaconda.conf [User Interface] can_change"; grep -n -B4 '^can_change_root\|^can_change_users' "$R/etc/anaconda/anaconda.conf"
echo "=== cmdline-Modus: mandatory spokes / Fehlermeldung"; grep -rn -B2 -A6 'mandatory spokes' "$PY/ui/tui/hubs/summary.py" 2>/dev/null | head -40
grep -rn 'cmdline' "$PY/ui/tui/hubs/summary.py" "$PY/ui/tui/__init__.py" 2>/dev/null | head
echo "=== bootloader preserved/append Logik"; grep -n -B3 -A12 'preserved_arguments\|def _get_preserved' "$PY/modules/storage/bootloader/base.py" | head -60
echo "=== systemd-debug-generator man"; zcat "$R/usr/share/man/man8/systemd-debug-generator.8.gz" 2>/dev/null | grep -vE '^\.' | sed 's/\f[BIRP]//g' | grep -A6 -iE 'debug_shell|systemd\.run|systemd\.mask' | head -60
echo "=== livesys-main"; grep -v '^\s*#' "$R/usr/libexec/livesys/livesys-main" | grep -v '^\s*$' | head -80
echo "=== bash im Rootfs: $(ls "$R"/usr/share/doc | grep -E '^bash')"; ls -la "$R/bin/sh" "$R/usr/bin/sh"
echo "=== Host: nbd/btrfs/mke2fs -d/mtools"; modinfo nbd 2>&1 | head -1; grep -E 'btrfs|vfat' /proc/filesystems; mke2fs -V 2>&1 | head -1; which mcopy mformat guestfish 2>&1; ls /dev/nbd0 2>&1
echo "=== rootfs-Groesse"; du -sh --apparent-size "$R" 2>/dev/null | tail -1; ls /work/sl7/fedora/
