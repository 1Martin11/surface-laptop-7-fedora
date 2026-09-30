#!/usr/bin/env bash
# dtbloader-Images ohne .osrel neu bauen (Fedora-Muster "unvollstaendiges UKI"), Sektionen mit Fedoras Image vergleichen,
# kernel-install inspect im Chroot (muss "pe" sein, nicht "uki").
set -uo pipefail; export LC_ALL=C
B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"; H="$B/wsl-fedora-chroot.sh"; R=/work/sl7/fedora/rootfs; ST=/work/sl7/stubble
KA=7.0.0-rc4-sl7; KB=7.3.0-rc3-sl7b; KS=6.19.10-300.fc44.aarch64
secs() { aarch64-linux-gnu-objdump -h "$1" | awk '/^ +[0-9]+ /{print $2}' | sort | uniq -c | awk '{printf "%s×%s ", $1, $2}'; echo; }
echo "=== Fedora-Referenz ($KS): $(secs "$R/lib/modules/$KS/vmlinuz-dtbloader.efi")"
for K in $KA $KB; do
  echo "--- vorher $K: $(secs "$R/lib/modules/$K/vmlinuz-dtbloader.efi")"
  ukify build --linux="$R/lib/modules/$K/vmlinuz" --stub="$ST/a64/usr/lib/stubble/stubble.efi" --hwids="$ST/a64/usr/share/stubble/hwids" --sbat="@$ST/a64/usr/share/stubble/sbat" \
    --devicetree-auto="$R/lib/modules/$K/dtb/qcom/x1e80100-microsoft-romulus13.dtb" --devicetree-auto="$R/lib/modules/$K/dtb/qcom/x1e80100-microsoft-romulus15.dtb" \
    --os-release="" --uname="$K" --output="$R/lib/modules/$K/vmlinuz-dtbloader.efi.new" 2>&1 | grep -v '^Real-Mode\|readelf\|Kernel version\|Found uname' | tail -2
  [ -s "$R/lib/modules/$K/vmlinuz-dtbloader.efi.new" ] || { echo "FEHLER ukify $K"; exit 1; }
  mv -f "$R/lib/modules/$K/vmlinuz-dtbloader.efi.new" "$R/lib/modules/$K/vmlinuz-dtbloader.efi"
  echo "--- nachher $K: $(secs "$R/lib/modules/$K/vmlinuz-dtbloader.efi")"
  o=$(aarch64-linux-gnu-objdump -h "$R/lib/modules/$K/vmlinuz-dtbloader.efi" | grep -cE '\.(osrel|cmdline|initrd)'); d=$(aarch64-linux-gnu-objdump -h "$R/lib/modules/$K/vmlinuz-dtbloader.efi" | grep -c '\.dtbauto')
  [ "$o" = 0 ] && [ "$d" = 2 ] && echo "    ok: keine .osrel/.cmdline/.initrd, 2 .dtbauto" || { echo "FEHLER: osrel/cmdline/initrd=$o dtbauto=$d"; exit 1; }
  cp -f "$R/lib/modules/$K/vmlinuz-dtbloader.efi" "$R/boot/vmlinuz-$K"; chmod 755 "$R/boot/vmlinuz-$K"
  setfattr -n security.selinux -v 'system_u:object_r:modules_object_t:s0' "$R/lib/modules/$K/vmlinuz-dtbloader.efi"; setfattr -n security.selinux -v 'system_u:object_r:boot_t:s0' "$R/boot/vmlinuz-$K"
done
echo "=== kernel-install inspect im Chroot"
bash "$H" mount >/dev/null || exit 1
for K in $KS $KA $KB; do echo "--- $K:"; bash "$H" run kernel-install inspect "$K" "/lib/modules/$K/vmlinuz-dtbloader.efi" 2>&1 | grep -iE 'Image Type|Layout|Initrd Generator|UKI Generator|Entry Token' | sed 's/^/    /'; done
bash "$H" umount >/dev/null
echo "=== Stub-Strings (HWID/Modelle im Image):"; strings -n 8 "$R/lib/modules/$KB/vmlinuz-dtbloader.efi" | grep -iE 'romulus|Surface' | sort -u | head -5
echo fertig
