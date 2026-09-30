#!/usr/bin/env bash
set -uo pipefail; export LC_ALL=C
R=/work/sl7/fedora/rootfs; PY=$R/usr/lib64/python3.14/site-packages/pyanaconda
echo "=== interactive-defaults.ks"; cat "$R/usr/share/anaconda/interactive-defaults.ks"; echo "--- post-scripts:"; ls "$R/usr/share/anaconda/post-scripts/" 2>/dev/null
grep -rn 'post-scripts\|interactive-defaults' "$PY" --include=*.py | grep -v '^\s*#' | head -8
echo "=== payload/live.py (Klassen, Tasks, post_install)"; grep -nE 'class |def |Task\(|kernel|bls|initrd|dracut|rsync|live-base|mount' "$PY/payload/live.py" | head -60
echo "=== anaconda.py: Ende/poweroff/liveinst"; grep -nE 'poweroff|KS_SHUTDOWN|KS_REBOOT|liveinst|reboot' "$PY/anaconda.py" "$PY/ui/tui/spokes/installation_progress.py" "$PY/ui/tui/__init__.py" "$PY/exception.py" 2>/dev/null | head -30
echo "=== hidden_spokes in TUI?"; grep -rn 'hidden_spokes' "$PY/ui" --include=*.py | head -8
echo "=== TUI Spokes mandatory"; grep -rln 'def mandatory' "$PY/ui/tui/spokes/" | xargs -I{} sh -c 'echo "--- {}"; grep -n -A3 "def mandatory" {}' 2>/dev/null | head -60
echo "=== live payload install tasks (modules/payloads/payload/live_os)"; ls "$PY/modules/payloads/payload/live_os/" 2>/dev/null; grep -nE 'class |Task|rsync|def ' "$PY/modules/payloads/payload/live_os/installation.py" 2>/dev/null | head -30
grep -rn 'class InstallFromImageTask' -A30 "$PY/modules/payloads/base/installation.py" 2>/dev/null | grep -nE 'rsync|exclude|xattr|cmd' | head -10
echo "=== Host btrfs-Modul: $(modinfo -n btrfs 2>&1 | head -1)"
