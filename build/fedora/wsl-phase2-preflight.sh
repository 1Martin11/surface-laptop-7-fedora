#!/usr/bin/env bash
export LC_ALL=C; R=/work/sl7/fedora/rootfs; ST=/work/sl7/stubble; O="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out"; B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"
for f in /work/sl7/kernel/ellx-7.0-sl7/arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13-exp.dtb /work/sl7/kernel/ellx-7.0-sl7/arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13-i2cts.dtb /work/sl7/kernel/ubuntu-7.3/arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13-i2cts.dtb "$ST/a64/usr/lib/stubble/stubble.efi" "$ST/a64/usr/share/stubble/sbat" "$O/sl7-firmware-msi-26100_26.053.36539.0.tar.xz" "$O/sl7-mac_1.0.2_all.deb" "$B/SL7-Hinweise.txt" "$B/grub-sl7.cfg" /usr/share/qemu-efi-aarch64/QEMU_EFI.fd; do [ -f "$f" ] && echo "ok   $f" || echo "FEHLT $f"; done
ls /work/sl7/fedora/rpm/rpmbuild/RPMS/aarch64/ /work/sl7/fedora/rpm-b/rpmbuild/RPMS/aarch64/ 2>&1 | grep -v headers
for t in ukify aarch64-linux-gnu-objdump lsinitrd dpkg-deb mksquashfs xorriso setfiles getfattr; do printf '%-26s %s\n' "$t" "$(command -v $t || echo FEHLT)"; done
echo "--- rpm -qpl Kernel A: /boot- und vmlinuz-Eintraege"; rpm -qpl /work/sl7/fedora/rpm/rpmbuild/RPMS/aarch64/kernel-7.0*.rpm | grep -E '^/boot/[^/]+$|/vmlinuz|modules/[^/]+/(dtb|config|System.map)$' | head
echo "--- iptsd-Build-Log (Stand):"; tail -5 /work/sl7/fedora/iptsd-rpm.log 2>/dev/null
echo "--- Platz:"; df -h /work | tail -1
