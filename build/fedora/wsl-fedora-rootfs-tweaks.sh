#!/usr/bin/env bash
# Nachtraegliche Rootfs-Ergaenzungen aus der Plan-Synthese (docs/Fedora-Plan.md): efi_pstore in der dracut-Konfiguration,
# dnf-Ausschluss fuer Fedora-Kernelpakete im Zielsystem, aktualisierte SL7-Hinweise, SELinux-Labels der geaenderten Dateien.
set -uo pipefail; export LC_ALL=C
B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"; R=/work/sl7/fedora/rootfs
echo "=== dracut: efi_pstore"; grep -q efi_pstore "$R/etc/dracut.conf.d/90-sl7.conf" || sed -i 's/^add_drivers+=" /add_drivers+=" efi_pstore /' "$R/etc/dracut.conf.d/90-sl7.conf"; grep '^add_drivers' "$R/etc/dracut.conf.d/90-sl7.conf" | cut -c1-120
echo "=== dnf.conf: Fedora-Kernelpakete von Updates ausschliessen"
if ! grep -q '^exclude=' "$R/etc/dnf/dnf.conf"; then cat >> "$R/etc/dnf/dnf.conf" <<'EOC'

# SL7-Projekt: Fedoras Kernelpakete nicht nachziehen, sonst wird ein Stock-Kernel ohne spi-hid/Trackpad-Klick
# zum Standard-Booteintrag. Aufheben: diese Zeile entfernen (oder "dnf --disableexcludes=main upgrade").
exclude=kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-uki-dtbloader kernel-uki-virt
EOC
fi; grep -A1 '^# SL7' "$R/etc/dnf/dnf.conf" | tail -1 | cut -c1-100; grep '^exclude=' "$R/etc/dnf/dnf.conf" | cut -c1-80
echo "=== SL7-Hinweise aktualisieren"; sed 's/\r$//' "$B/SL7-Hinweise.txt" > "$R/etc/skel/Desktop/SL7-Hinweise.txt"; head -6 "$R/etc/skel/Desktop/SL7-Hinweise.txt" | tail -3
echo "=== Labels"; FCD="$R/etc/selinux/targeted/contexts/files"; for b in "$FCD"/*.bin; do mv -f "$b" "$b.sl7tmp"; done
setfiles -F -r "$R" "$FCD/file_contexts" "$R/etc/dracut.conf.d" "$R/etc/dnf" "$R/etc/skel" "$R/lib/modules/7.0.0-rc4-sl7/vmlinuz-dtbloader.efi" "$R/lib/modules/7.3.0-rc3-sl7b/vmlinuz-dtbloader.efi" "$R/boot" 2>&1 | head -3
for b in "$FCD"/*.sl7tmp; do mv -f "$b" "${b%.sl7tmp}"; done
for f in etc/dnf/dnf.conf etc/skel/Desktop/SL7-Hinweise.txt lib/modules/7.3.0-rc3-sl7b/vmlinuz-dtbloader.efi boot/vmlinuz-7.3.0-rc3-sl7b; do printf '    %-55s %s\n' "$f" "$(getfattr --absolute-names --only-values -n security.selinux "$R/$f" 2>/dev/null)"; done
echo "=== grub-sl7.cfg Syntax"; sed 's/\r$//' "$B/grub-sl7.cfg" > /tmp/g.cfg; grub-script-check /tmp/g.cfg && echo "    ok"
ls -la /work/sl7/fedora/analyse/isofs/boot/aarch64/loader/grub2/fonts/ 2>&1 | head -3
echo fertig
