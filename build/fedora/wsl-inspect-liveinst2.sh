#!/usr/bin/env bash
set -uo pipefail; export LC_ALL=C
R=/work/sl7/fedora/rootfs; B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"
echo "=== liveinst Rest"; grep -v '^\s*#' "$R/usr/bin/liveinst" | grep -v '^\s*$' | sed -n '120,200p'
PY=$(find "$R"/usr/lib "$R"/usr/lib64 -maxdepth 4 -type d -name pyanaconda 2>/dev/null | head -1); echo "=== pyanaconda: $PY"
echo "--- argument_parsing.py Optionen"; grep -nE 'add_argument\("(-[A-Za-z]|--[a-z-]+)' "$PY/argument_parsing.py" | grep -E 'liveinst|cmdline|kickstart|noninteractive|text|graphical|dirinstall|image|noselinux|display' | head -30
echo "--- display.py live/text"; grep -nE 'live|cmdline|noninteractive|TUI|gui_mode|tui_mode' "$PY/display.py" | head -50
echo "--- livecdInstall/is_live in Code"; grep -rnE 'livecdInstall|\.liveinst|is_live_os|liveinst' "$PY" --include=*.py | grep -vE '^\s*#|ui/gui|ui/webui' | head -30
echo "--- Live-Payload/Source Standardpfad"; grep -rnE 'live-base|live-osimg|/dev/mapper|osimg' "$PY" --include=*.py | head -10
echo "--- Services/InitialSetup in Profilen"; grep -rnE -B1 -A3 '^\[Services\]' "$R"/etc/anaconda/profile.d/fedora*.conf "$R"/etc/anaconda/anaconda.conf | head -40
echo "=== livesys"; ls "$R"/usr/libexec/livesys/ 2>/dev/null; for f in "$R"/usr/libexec/livesys/livesys "$R"/usr/libexec/livesys/livesys-late "$R"/usr/libexec/livesys/sessions.d/*; do [ -f "$f" ] && { echo "--- $f"; grep -v '^\s*#' "$f" | grep -v '^\s*$' | head -80; }; done
cat "$R"/usr/lib/systemd/system/livesys.service | grep -v '^#'
echo "=== initial-setup / systemd-Version"; ls "$R"/usr/lib/systemd/system/ | grep -iE 'initial-setup|firstboot|sddm|debug-shell'; ls "$R"/usr/lib/systemd/systemd; strings "$R/usr/lib/systemd/systemd" | grep -m1 -E '^systemd [0-9]+' ; grep -oE 'systemd-[0-9]+' <<< "$(ls "$R"/usr/lib/.build-id 2>/dev/null | head -0)"; ls "$R"/usr/share/doc | grep -E '^systemd' | head -3
echo "--- debug-shell.service"; cat "$R"/usr/lib/systemd/system/debug-shell.service | grep -vE '^#|^$'
echo "=== live-base im Test1-Log"; grep -aoE 'live-(base|rw)[^ ]*' "$B/out/logs/qemu-test1.log" | sort | uniq -c | head; grep -aoE 'Command line: .*' "$B/out/logs/qemu-test1.log" | head -1 | cut -c1-300
grep -aE 'livesys|liveuser' "$B/out/logs/qemu-test1.log" | tr -d '\r' | head -5
