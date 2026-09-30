#!/usr/bin/env bash
# Teil 3: stubble-Werkzeug im Detail + Zustand des Kernel-Trees nach bindeb-pkg.
set -uo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7
S=/work/sl7/iso-inspect/stubble/x
cd "$K"
echo "=== git status der debian-Verzeichnisse (bindeb-pkg ueberschreibt debian/):"
git status --short debian debian.master debian.qcom-x1e | head -5
ls debian | head -8
echo
echo "=== Packaging: stubble-Abschnitt (aus git HEAD):"
git show HEAD:debian/rules.d/2-binary-arch.mk | grep -a -n -A22 'do_stubble),true' | head -45
echo
echo "=== stubble-Paket: Dateien (ohne hwids)"
find "$S" -type f -not -path '*/hwids/*' | sort
echo "=== hwids romulus13:"
cat "$S/usr/share/stubble/hwids/x1e80100-microsoft-romulus13.json"; echo
echo "=== stubble Programm(e):"
for f in "$S"/usr/bin/* "$S"/usr/sbin/* "$S"/usr/lib/stubble/*; do
  [ -f "$f" ] || continue
  echo "--- $f: $(file -b "$f" | cut -c1-80)"
  case "$(file -b "$f")" in *text*|*script*) head -80 "$f";; esac
done 2>/dev/null | head -160
echo
echo "=== stubble --help"
PYTHONPATH="$S/usr/lib/python3/dist-packages" python3 "$S/usr/bin/stubble" --help 2>&1 | head -40 || true
