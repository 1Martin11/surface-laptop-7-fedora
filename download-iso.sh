#!/bin/sh
# Downloads the Surface Laptop 7 Fedora ISO from the GitHub release, joins the parts and verifies the SHA256.
# Usage:  curl -fsSL https://raw.githubusercontent.com/1Martin11/surface-laptop-7-fedora/main/download-iso.sh | sh
set -e
base=https://github.com/1Martin11/surface-laptop-7-fedora/releases/download/v2026.09.30
iso=Fedora-KDE-Live-44-SL7-20260930.iso
sha=3a16e0d6108be68485f1de2043c64de70abadbefd9a5c734b1df7eb9dc5725f2
for i in 0 1 2; do [ -f "$iso.part-$i" ] || curl -fL -o "$iso.part-$i" "$base/$iso.part-$i"; done
cat "$iso.part-0" "$iso.part-1" "$iso.part-2" > "$iso" && rm -f "$iso".part-?
echo "$sha  $iso" | sha256sum -c - && echo "OK: $iso verified."
