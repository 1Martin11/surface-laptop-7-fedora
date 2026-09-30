#!/usr/bin/env bash
# Baut aus dem selbstgebauten vmlinuz.efi ein Ubuntu-"stubble"-Image (UKI-Stub + eingebettete DTBs mit SMBIOS-HWIDs),
# genau wie Ubuntus linux-qcom-x1e-Paket (debian/rules.d: ukify build --stub=stubble.efi --hwids ... --devicetree-auto=...).
# Damit waehlt der Bootstub den Romulus13-DTB selbst; GRUB braucht kein "devicetree".
# Aufruf (als root in WSL):  bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-build-stubble.sh"
set -euo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
K=/work/sl7/kernel/ellx-7.0-sl7
ST=/work/sl7/stubble
WINOUT="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out"
mkdir -p "$ST"
cd "$ST"

echo "=== [1/4] Werkzeuge: systemd-ukify, python3-libfdt, stubble (arm64: Stub; amd64: hwids/sbat identisch)"
apt-get install -y -qq systemd-ukify python3-libfdt python3-pefile 2>&1 | grep -vE '^(Selecting|Preparing|Unpacking|Setting up|Processing)' | tail -2 || true
ukify --version | head -1
if [ ! -f a64/usr/lib/stubble/stubble.efi ]; then
  apt-get download stubble:arm64 >/dev/null 2>&1
  rm -rf a64 && dpkg-deb -x stubble_*arm64.deb a64
fi
file -b a64/usr/lib/stubble/stubble.efi | cut -c1-60
ls a64/usr/share/stubble/hwids | wc -l | sed 's/^/    hwids-Dateien: /'

echo "=== [2/4] DTBs finden, die zu den HWIDs passen (finddtbs.py)"
KVER=$(cd "$K" && LOCALVERSION=-sl7 make -s kernelrelease)
DTBS=$(python3 a64/usr/libexec/stubble/finddtbs.py "$K/arch/arm64/boot/dts" a64/usr/share/stubble/hwids 2>/dev/null | sort)
echo "$DTBS" | sed 's/^/    /'
ARGS=()
while IFS= read -r d; do [ -n "$d" ] && ARGS+=("--devicetree-auto=$d"); done <<< "$DTBS"
echo "    Kernel: $KVER, DTBs: ${#ARGS[@]}"
[ ${#ARGS[@]} -gt 0 ] || { echo "FEHLER: keine DTBs gefunden"; exit 1; }

echo "=== [3/4] ukify build"
OUT="$ST/vmlinuz-$KVER.stubble"
ukify build \
  --linux="$K/arch/arm64/boot/vmlinuz.efi" \
  --stub="$ST/a64/usr/lib/stubble/stubble.efi" \
  --hwids="$ST/a64/usr/share/stubble/hwids" \
  --sbat="@$ST/a64/usr/share/stubble/sbat" \
  "${ARGS[@]}" \
  --output="$OUT" 2>&1 | tail -5
ls -la "$OUT"

echo "=== [4/4] Pruefung"
aarch64-linux-gnu-objdump -h "$OUT" | grep -E 'Idx|\.linux|\.dtbauto|\.hwids|\.sbat|\.cmdline' | head -30
echo "    Anzahl .dtbauto-Sektionen: $(aarch64-linux-gnu-objdump -h "$OUT" | grep -c '\.dtbauto')"
strings -n 8 "$OUT" | grep -E 'romulus|Romulus' | sort -u | head -5
D="$WINOUT/$KVER-${PKGREV:-1}"
mkdir -p "$D"
cp -f "$OUT" "$D/"
cp -f "$OUT" "/work/sl7/out/$KVER-${PKGREV:-1}/" 2>/dev/null || true
sha256sum "$OUT" >> "$D/SHA256SUMS"
echo "FERTIG: $D/$(basename "$OUT")"
