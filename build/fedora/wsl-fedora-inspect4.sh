#!/usr/bin/env bash
set -uo pipefail; export LC_ALL=C
R=/work/sl7/fedora/rootfs
echo "=== anaconda.conf [Bootloader] 134-175"; sed -n '134,175p' "$R/etc/anaconda/anaconda.conf"
echo "=== xattr-Schreibtest"; command -v setfattr || apt-get install -y -qq attr 2>&1 | tail -1; T=/work/sl7/fedora/xattrtest; echo x > $T; setfattr -n security.selinux -v 'system_u:object_r:bin_t:s0' $T; echo "setfattr exit=$?"; getfattr --absolute-names -n security.selinux $T; rm -f $T
echo "=== Firmware-Tar: DT-referenzierte Dateien vorhanden?"; tar -tJf "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out/sl7-firmware-msi-26100_26.053.36539.0.tar.xz" | grep -E 'qcadsp8380|qccdsp8380|adsp_dtbs|cdsp_dtbs|qcdxkmsuc8380|qcvss8380|board-2|qcvss' 
echo "=== Fedora-Firmware im Rootfs (xz):"; ls "$R/usr/lib/firmware/qcom/x1e80100/" | head; ls "$R/usr/lib/firmware/ath12k/WCN7850/hw2.0/"; ls "$R/usr/lib/firmware/qca/" | grep -i 'hmt\|7850' | head -5; ls -d "$R"/usr/lib/firmware/updates 2>&1
echo "=== Live-Kernel-Modul-Liste: spi-hid / geni / ath12k im Live-Kernel 6.19?"; find "$R/lib/modules/6.19.10-300.fc44.aarch64" -name 'spi-hid*' -o -name 'spi-geni*' -o -name 'ath12k.ko*' | sed 's|.*/||'
echo "=== phase1 Log Stand"; tail -c 600 /work/sl7/fedora/phase1.log | tr '\r' '\n' | tail -6
