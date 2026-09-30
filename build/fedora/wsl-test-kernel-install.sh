#!/usr/bin/env bash
# Test des Installations-Pfads ohne Anaconda: in einem Overlay ueber dem Rootfs (nichts wird veraendert) das nachstellen,
# was Anacondas create_bls_entries tut: kernel-install add <ver> /lib/modules/<ver>/vmlinuz-dtbloader.efi fuer alle Kernel.
# Erwartung: BLS-Typ-1-Eintraege, /boot/vmlinuz-<ver> = dtbloader-Image, host-only-initramfs mit spi-hid + DSP-Firmware,
# Standardeintrag = Kernel B. Danach sl7-postinstall.sh im Overlay laufen lassen (grubby-Argumente, Denylist).
set -uo pipefail; export LC_ALL=C
R=/work/sl7/fedora/rootfs; O=/work/sl7/fedora/ovl; M=$O/merged; KA=7.0.0-rc4-sl7; KB=7.3.0-rc3-sl7b; KS=6.19.10-300.fc44.aarch64
cleanup() { for m in run dev/pts dev sys proc; do mountpoint -q "$M/$m" 2>/dev/null && umount -l "$M/$m"; done; mountpoint -q "$M" && umount -l "$M"; }
trap cleanup EXIT
cleanup 2>/dev/null; rm -rf "$O"; mkdir -p "$O/upper" "$O/work" "$M"
mount -t overlay overlay -o "lowerdir=$R,upperdir=$O/upper,workdir=$O/work" "$M" || { echo "overlay fehlgeschlagen"; exit 1; }
for m in proc sys dev dev/pts; do mount --bind "/$m" "$M/$m"; done; mount -t tmpfs tmpfs "$M/run"
run() { chroot "$M" /usr/bin/env -i HOME=/root TERM=xterm LC_ALL=C.UTF-8 PATH=/usr/sbin:/usr/bin:/sbin:/bin "$@"; }
echo "=== Vorbereitung wie Anaconda: machine-id, /etc/sysconfig/kernel, BLS-Verzeichnis leer, Denylist wie nach Live-Boot mit USB-C-Eintrag"
echo 9216e190943a42679a561a51ac46d962 > "$M/etc/machine-id"; printf 'UPDATEDEFAULT=yes\nDEFAULTKERNEL=kernel-core\n' > "$M/etc/sysconfig/kernel"
mkdir -p "$M/boot/loader/entries"; rm -f "$M"/boot/loader/entries/*.conf; printf '# Module denylist written by anaconda\nblacklist qcom_q6v5_pas\n' > "$M/etc/modprobe.d/anaconda-denylist.conf"
run grub2-editenv - set saved_entry= 2>/dev/null
for K in $KS $KA $KB; do
  echo "=== kernel-install add $K (dtbloader-Image)"; START=$(date +%s)
  run kernel-install -v add "$K" "/lib/modules/$K/vmlinuz-dtbloader.efi" > "$O/ki-$K.log" 2>&1; rc=$?
  echo "    exit=$rc in $(( $(date +%s)-START )) s; Plugins: $(grep -oE 'install.d/[0-9]+-[a-z-]+\.install' "$O/ki-$K.log" | sort -u | tr '\n' ' ')"
  grep -iE 'error|fail|warn' "$O/ki-$K.log" | grep -v 'dracut-install' | head -4 | sed 's/^/    /'
done
echo "=== Ergebnis /boot"; ls -la "$M"/boot/vmlinuz-* "$M"/boot/initramfs-* 2>&1 | sed 's/^/    /'
for K in $KA $KB; do cmp -s "$M/boot/vmlinuz-$K" "$R/lib/modules/$K/vmlinuz-dtbloader.efi" && echo "    /boot/vmlinuz-$K == dtbloader-Image (ok)" || echo "    /boot/vmlinuz-$K weicht ab"; done
echo "=== BLS-Eintraege"; for f in "$M"/boot/loader/entries/*.conf; do echo "--- $(basename "$f")"; grep -E '^(title|version|linux|initrd|options|devicetree)' "$f" | cut -c1-160 | sed 's/^/    /'; done
echo "=== grubenv: $(run grub2-editenv list 2>/dev/null | tr '\n' ' ')"
echo "=== host-only-initramfs Inhalt (Kernel B): spi-hid=$(lsinitrd "$M/boot/initramfs-$KB.img" 2>/dev/null | grep -c spi-hid) qcadsp=$(lsinitrd "$M/boot/initramfs-$KB.img" 2>/dev/null | grep -c qcadsp8380) board-2=$(lsinitrd "$M/boot/initramfs-$KB.img" 2>/dev/null | grep -c 'updates/ath12k') efi_pstore=$(lsinitrd "$M/boot/initramfs-$KB.img" 2>/dev/null | grep -c efi-pstore) Groesse=$(stat -c %s "$M/boot/initramfs-$KB.img" 2>/dev/null)"
echo "=== sl7-postinstall.sh im Overlay"; START=$(date +%s); run /usr/lib/sl7/postinstall.sh; echo "    exit=$? in $(( $(date +%s)-START )) s"; cat "$M/var/lib/sl7/postinstall.log" | sed 's/^/    /' | head -30
echo "--- Denylist danach: $(cat "$M/etc/modprobe.d/anaconda-denylist.conf" 2>/dev/null || echo '(entfernt)')"
echo "--- grubby --info=ALL:"; run grubby --info=ALL 2>/dev/null | grep -E '^(kernel|args|index)' | cut -c1-170 | sed 's/^/    /'
echo "--- BLS-Optionen danach:"; grep -H '^options' "$M"/boot/loader/entries/*.conf | cut -c1-200 | sed 's/^/    /'
cleanup; rm -rf "$O/upper" "$O/work"; echo "=== Test fertig (Rootfs unveraendert)"
