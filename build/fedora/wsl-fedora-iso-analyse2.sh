#!/usr/bin/env bash
# Teil 2: Was ist LiveOS/squashfs.img wirklich (squashfs/erofs/ext4)? Kernel-/initrd-Typ, dracut-Module; DTB-Vergleich safe/exp.
set -uo pipefail
export LC_ALL=C
W=/work/sl7/fedora/analyse
cd "$W/isofs" || exit 1
echo "=== Dateitypen"
file LiveOS/squashfs.img boot/aarch64/loader/linux boot/aarch64/loader/initrd
echo "=== blkid squashfs.img"; blkid -p LiveOS/squashfs.img 2>&1 | head -3
echo "=== unsquashfs -s (mit Fehlern)"; unsquashfs -s LiveOS/squashfs.img 2>&1 | head -8
echo "=== erofs?"; command -v dump.erofs >/dev/null 2>&1 || { apt-get install -y -qq erofs-utils >/dev/null 2>&1 && echo "erofs-utils installiert"; }; dump.erofs LiveOS/squashfs.img 2>&1 | head -12
echo "=== initrd: Format + dracut-Module"
INITRD=boot/aarch64/loader/initrd
lsinitrd "$INITRD" 2>&1 | head -5
lsinitrd "$INITRD" 2>/dev/null | sed -n '/dracut modules/,/^=====/p' | tr '\n' ' ' | cut -c1-900; echo
echo "--- Module fuer Live/qcom/nvme im initrd:"; lsinitrd "$INITRD" 2>/dev/null | grep -oE '(dmsquash-live|livenet|img-lib|qcom[a-z_-]*\.ko|msm\.ko|nvme\.ko|phy-qcom-qmp-pcie\.ko|pcie-qcom\.ko|ath12k\.ko|spi-hid\.ko|dtb)[^ ]*' | sort -u | head -20
echo "--- Kernel-Version laut initrd-Modulpfad:"; lsinitrd "$INITRD" 2>/dev/null | grep -oE 'lib/modules/[^/]+/' | sort -u | head -3
echo "--- initrd: eingebettete Firmware qcom/ath12k?"; lsinitrd "$INITRD" 2>/dev/null | grep -E 'firmware/(qcom|ath12k|qca)' | head -5 | sed 's/^/    /'
echo "=== Kernel-Image: PE (zboot)?"; head -c 64 boot/aarch64/loader/linux | od -A x -t x1z | head -3
echo
echo "=== DTB-Vergleich safe vs exp"
cd /work/sl7/kernel/ellx-7.0-sl7/arch/arm64/boot/dts/qcom || exit 1
for d in romulus13 romulus13-exp; do
  T=$(dtc -I dtb -O dts "x1e80100-microsoft-$d.dtb" 2>/dev/null)
  printf '  %-14s Zeilen=%-6s __symbols__=%s surface-sam=%s wcn7850-pci=%s wsa8845=%s reinit-phy=%s\n' "$d" "$(echo "$T" | wc -l)" "$(echo "$T" | grep -c __symbols__)" "$(echo "$T" | grep -c surface-sam)" "$(echo "$T" | grep -c 'pci17cb,1107')" "$(echo "$T" | grep -c sdw20217020400)" "$(echo "$T" | grep -c reinit-phy-on-resume)"
done
