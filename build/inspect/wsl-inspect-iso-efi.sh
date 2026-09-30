#!/usr/bin/env bash
# Untersucht die EFI-Binaries und den Kernel der Ubuntu-x1e-ISO: Wo steckt die DTB-Auswahl (GRUB-Embedded-Config, Memdisk, Kernel)?
set -uo pipefail
export LC_ALL=C
ISO="/mnt/c/Users/Martin/Downloads/questing-desktop-arm64+x1e.iso"
W=/work/sl7/iso-inspect
rm -rf "$W" && mkdir -p "$W" && cd "$W"
echo "=== Alle Dateien der ISO (ohne pool/ und casper/*.squashfs)"
7z l -ba "$ISO" | awk '{print $4, $NF}' | grep -vE ' pool/|\.squashfs$' | sort -k2 | head -80
echo
7z x -o"$W" "$ISO" 'EFI' 'boot' '.disk' -r >/dev/null 2>&1
find "$W" -type f -printf '%10s  %P\n' | sort -k2
echo
for f in $(find "$W/EFI" -iname '*.efi'); do
  echo "=== strings $f (dtb/devicetree/smbios/romulus/x1e/memdisk/config)"
  strings -n 6 "$f" | grep -iE 'dtb|devicetree|smbios|romulus|x1e|memdisk|\.cfg|grub\.cfg|dtbloader|fdt' | sort -u | head -40
done
echo
echo "=== GRUB-Embedded-Config? (grub-mkimage -c legt 'grub-early' o.ae. ab)"
for f in $(find "$W/EFI" -iname 'grub*.efi'); do
  strings -n 8 "$f" | grep -iE 'menuentry|search|set prefix|configfile|regexp|cutmem|devicetree|\(memdisk\)' | head -20
done
echo
echo "=== Kernel casper/vmlinuz: eingebettete DTBs?"
7z x -o"$W" "$ISO" casper/vmlinuz >/dev/null 2>&1
ls -la "$W/casper/vmlinuz"
file "$W/casper/vmlinuz"
strings -n 8 "$W/casper/vmlinuz" | grep -iE 'romulus|x1e80100-|microsoft,|lenovo,|dtb' | sort -u | head -20
echo "--- zboot? (PE mit komprimiertem Kernel) -> entpacken und im Kernel nach DTB-Compatible-Strings suchen"
python3 - <<'PY'
import re, sys, subprocess
data = open('/work/sl7/iso-inspect/casper/vmlinuz','rb').read()
# zstd frame magic 28 B5 2F FD
i = data.find(b'\x28\xb5\x2f\xfd')
print('zstd frame offset:', i)
if i > 0:
    open('/work/sl7/iso-inspect/kernel.zst','wb').write(data[i:])
    r = subprocess.run(['zstd','-d','-q','-f','/work/sl7/iso-inspect/kernel.zst','-o','/work/sl7/iso-inspect/Image'], capture_output=True, text=True)
    print('zstd:', r.returncode, r.stderr.strip()[:200])
PY
if [ -f "$W/Image" ]; then
  ls -la "$W/Image"
  strings -n 8 "$W/Image" | grep -E 'microsoft,romulus|qcom,x1e80100|x1e80100-microsoft|dtb' | sort -u | head -20
  echo "--- Anzahl 'compatible'-artiger Board-Strings im Image: $(strings -n 8 "$W/Image" | grep -cE '^(microsoft|lenovo|asus|dell|hp|qcom),')"
fi
