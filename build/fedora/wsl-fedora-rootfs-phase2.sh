#!/usr/bin/env bash
# Phase 2: Kernel A+B (RPM), DTB-Varianten, dtbloader-Images (stubble/ukify), Firmware, sl7-mac, Sleep-Hooks,
# Konfiguration (dracut/anaconda/postinstall), Live-initrds (dracut --no-hostonly), SELinux-Relabel, Aufraeumen.
# Voraussetzung: Phase 1 fertig (Update + iptsd), Kernel-RPMs A und B vorhanden.
set -uo pipefail; export LC_ALL=C
B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"; O="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out"; H="$B/wsl-fedora-chroot.sh"
R=/work/sl7/fedora/rootfs; ST=/work/sl7/stubble; KA=7.0.0-rc4-sl7; KB=7.3.0-rc3-sl7b
TA=/work/sl7/kernel/ellx-7.0-sl7/arch/arm64/boot/dts/qcom; TB=/work/sl7/kernel/ubuntu-7.3/arch/arm64/boot/dts/qcom
L=/work/sl7/fedora/phase2.log; : > "$L"
sed -i 's/\r$//' "$H"
if [ -d "$R/lib" ] && [ ! -L "$R/lib" ]; then
  echo "=== [0] Reparatur: /lib ist ein Verzeichnis statt Symlink -> Inhalt nach usr/lib, Symlink zurueck"
  mkdir -p "$R/usr/lib/firmware"; [ -d "$R/lib/firmware/updates" ] && cp -a "$R/lib/firmware/updates" "$R/usr/lib/firmware/" && rm -rf "$R/lib/firmware/updates"
  find "$R/lib" -mindepth 1 | head -3; rm -rf "$R/lib"; ln -s usr/lib "$R/lib"; ls -ld "$R/lib"
fi
bash "$H" mount >/dev/null || exit 1
run() { bash "$H" run "$@"; }
fail() { echo "FEHLER: $*"; exit 1; }
RPMA=$(ls /work/sl7/fedora/rpm/rpmbuild/RPMS/aarch64/kernel-7.0*.rpm | grep -v headers | head -1)
RPMB=$(ls /work/sl7/fedora/rpm-b/rpmbuild/RPMS/aarch64/kernel-7.3*.rpm | grep -v headers | head -1)
[ -f "$RPMA" ] && [ -f "$RPMB" ] || fail "Kernel-RPMs fehlen: A=$RPMA B=$RPMB"

echo "=== [1] Kernel-RPMs installieren (ohne Skripte; kernel-install/dracut machen wir selbst)"
mkdir -p "$R/root/sl7"; cp -f "$RPMA" "$RPMB" "$R/root/sl7/"
run rpm -ivh --replacepkgs --nodeps --noscripts "/root/sl7/$(basename "$RPMA")" "/root/sl7/$(basename "$RPMB")" 2>&1 | tail -3
for K in $KA $KB; do
  [ -f "$R/lib/modules/$K/vmlinuz" ] || fail "/lib/modules/$K/vmlinuz fehlt"
  [ -f "$R/lib/modules/$K/dtb/qcom/x1e80100-microsoft-romulus13.dtb" ] || fail "DTB fehlt fuer $K"
  run depmod -a "$K" || fail "depmod $K"
  echo "    $K: Module=$(find "$R/lib/modules/$K" -name '*.ko*' | wc -l) vmlinuz=$(stat -c %s "$R/lib/modules/$K/vmlinuz") B  /boot/dtb-$K: $([ -d "$R/boot/dtb-$K" ] && echo ja || echo nein)"
  cp -f "$R/lib/modules/$K/System.map" "$R/boot/System.map-$K" 2>/dev/null; cp -f "$R/lib/modules/$K/config" "$R/boot/config-$K" 2>/dev/null
  [ -d "$R/boot/dtb-$K" ] || cp -r "$R/lib/modules/$K/dtb" "$R/boot/dtb-$K"
done
rm -f "$R/root/sl7/"*.rpm

echo "=== [2] DTB-Varianten"
cp -f "$TA/x1e80100-microsoft-romulus13-exp.dtb" "$TA/x1e80100-microsoft-romulus13-i2cts.dtb" "$R/lib/modules/$KA/dtb/qcom/" || fail "A-Varianten"
cp -f "$TA/x1e80100-microsoft-romulus13-exp.dtb" "$TA/x1e80100-microsoft-romulus13-i2cts.dtb" "$R/boot/dtb-$KA/qcom/"
if [ -f "$TB/x1e80100-microsoft-romulus13-i2cts.dtb" ]; then
  cp -f "$TB/x1e80100-microsoft-romulus13-i2cts.dtb" "$R/lib/modules/$KB/dtb/qcom/"; cp -f "$TB/x1e80100-microsoft-romulus13-i2cts.dtb" "$R/boot/dtb-$KB/qcom/"
else echo "    (Kernel B: keine i2cts-Variante vorhanden)"; fi
ls "$R/lib/modules/$KA/dtb/qcom/" "$R/lib/modules/$KB/dtb/qcom/" | grep romulus | sed 's/^/    /'

echo "=== [3] dtbloader-Images (stubble + ukify, wie Fedoras kernel-uki-dtbloader)"
for K in $KA $KB; do
  ukify build --linux="$R/lib/modules/$K/vmlinuz" --stub="$ST/a64/usr/lib/stubble/stubble.efi" --hwids="$ST/a64/usr/share/stubble/hwids" --sbat="@$ST/a64/usr/share/stubble/sbat" \
    --devicetree-auto="$R/lib/modules/$K/dtb/qcom/x1e80100-microsoft-romulus13.dtb" --devicetree-auto="$R/lib/modules/$K/dtb/qcom/x1e80100-microsoft-romulus15.dtb" \
    --output="$R/lib/modules/$K/vmlinuz-dtbloader.efi" >>"$L" 2>&1 || fail "ukify $K (siehe $L)"
  n=$(aarch64-linux-gnu-objdump -h "$R/lib/modules/$K/vmlinuz-dtbloader.efi" | grep -c '\.dtbauto'); h=$(aarch64-linux-gnu-objdump -h "$R/lib/modules/$K/vmlinuz-dtbloader.efi" | grep -c '\.hwids')
  echo "    $K: vmlinuz-dtbloader.efi $(stat -c %s "$R/lib/modules/$K/vmlinuz-dtbloader.efi") B, .dtbauto=$n .hwids=$h"; [ "$n" = 2 ] || fail "dtbauto-Sektionen"
  cp -f "$R/lib/modules/$K/vmlinuz-dtbloader.efi" "$R/boot/vmlinuz-$K"; chmod 755 "$R/boot/vmlinuz-$K"
done

echo "=== [4] Firmware (Microsoft-MSI-Blobs + gepatchte ath12k board-2.bin nach /usr/lib/firmware/updates)"
rm -rf /tmp/sl7fw && mkdir -p /tmp/sl7fw && tar -xJf "$O/sl7-firmware-msi-26100_26.053.36539.0.tar.xz" -C /tmp/sl7fw --no-same-owner || fail "Firmware-Tar"
mkdir -p "$R/usr/lib/firmware/updates" && cp -a /tmp/sl7fw/lib/firmware/updates/. "$R/usr/lib/firmware/updates/" && rm -rf /tmp/sl7fw
[ -L "$R/lib" ] || fail "/lib ist kein Symlink mehr"
echo "    Dateien: $(find "$R/usr/lib/firmware/updates" -type f | wc -l)"
for K in $KA $KB; do for d in "$R"/lib/modules/$K/dtb/qcom/x1e80100-microsoft-romulus13*.dtb; do
  for f in $(strings "$d" | grep -oE 'qcom/x1e80100/[A-Za-z0-9_./-]+\.(mbn|elf|bin)' | sort -u); do
    [ -f "$R/usr/lib/firmware/updates/$f" ] || [ -f "$R/usr/lib/firmware/$f" ] || [ -f "$R/usr/lib/firmware/$f.xz" ] || echo "    FEHLT: $f (fuer $(basename "$d"))"; done; done; done
echo "    Firmware-Referenzen geprueft."

echo "=== [5] sl7-mac (valeronm, MIT) - Wi-Fi/BT-Fabrik-MAC aus UEFI"
rm -rf /tmp/sl7mac && mkdir -p /tmp/sl7mac && dpkg-deb -x "$O/sl7-mac_1.0.2_all.deb" /tmp/sl7mac
cp -a /tmp/sl7mac/usr/bin/sl7-mac "$R/usr/bin/"; mkdir -p "$R/usr/lib/sl7-mac"; cp -a /tmp/sl7mac/usr/lib/sl7-mac/. "$R/usr/lib/sl7-mac/"
cp -a /tmp/sl7mac/usr/lib/systemd/system/sl7-*.service "$R/usr/lib/systemd/system/"; cp -a /tmp/sl7mac/usr/lib/udev/rules.d/99-sl7-bt-mac.rules "$R/usr/lib/udev/rules.d/"
mkdir -p "$R/usr/share/doc/sl7-mac" "$R/usr/share/man/man1"; cp -a /tmp/sl7mac/usr/share/doc/sl7-mac/. "$R/usr/share/doc/sl7-mac/"; cp -a /tmp/sl7mac/usr/share/man/man1/sl7-mac.1.gz "$R/usr/share/man/man1/"
mkdir -p "$R/etc/systemd/system/sysinit.target.wants"; ln -sf /usr/lib/systemd/system/sl7-wifi-mac.service "$R/etc/systemd/system/sysinit.target.wants/sl7-wifi-mac.service"
chmod 755 "$R/usr/bin/sl7-mac" "$R/usr/lib/sl7-mac/mgmt-set-addr.py"; echo "    installiert, sl7-wifi-mac.service aktiviert (sysinit.target)"

echo "=== [6] Sleep-Hooks (ELLX display-fix + Trackpad-Rebind), tolerant gemacht"
mkdir -p "$R/usr/lib/systemd/system-sleep"
cat > "$R/usr/lib/systemd/system-sleep/sl7-display-fix" <<'EOS'
#!/bin/sh
# SL7 (ELLX-Fix): nach dem Aufwachen einmal VT wechseln, damit das Panel/DRM sicher wieder anzeigt.
case "$1" in post) CUR=$(fgconsole 2>/dev/null || echo 1); chvt 20 2>/dev/null; chvt "$CUR" 2>/dev/null ;; esac
exit 0
EOS
cat > "$R/usr/lib/systemd/system-sleep/sl7-trackpad-rebind" <<'EOS'
#!/bin/bash
# SL7 (ELLX-Fix): spi_hid-Geraete (Trackpad, ggf. Touchscreen) nach dem Aufwachen neu binden, falls sie haengen.
[ "$1" = post ] || exit 0
DRV=/sys/bus/spi/drivers/spi_hid; [ -d "$DRV" ] || exit 0
devs=(); for e in "$DRV"/spi*; do n=$(basename "$e"); [[ "$n" =~ ^spi[0-9]+\.[0-9]+$ ]] && [ -L "$e" ] && devs+=("$n"); done
[ ${#devs[@]} -gt 0 ] || exit 0
for d in "${devs[@]}"; do printf '%s' "$d" > "$DRV/unbind" 2>/dev/null || true; done
sleep 0.5
for d in "${devs[@]}"; do printf '%s' "$d" > "$DRV/bind" 2>/dev/null || logger -t sl7-trackpad-rebind "bind $d fehlgeschlagen"; done
exit 0
EOS
chmod 755 "$R/usr/lib/systemd/system-sleep/sl7-"*; ls "$R/usr/lib/systemd/system-sleep/" | sed 's/^/    /'; ls "$R"/usr/bin/chvt "$R"/usr/bin/fgconsole 2>&1 | sed 's/^/    /'

echo "=== [7] Konfiguration"
cat > "$R/etc/dracut.conf.d/90-sl7.conf" <<'EOC'
# Surface Laptop 7 (X1E80100): HID-over-SPI/I2C-Treiber und die geraetespezifische DSP-/GPU-Firmware
# (aus /usr/lib/firmware/updates) gehoeren in jede initramfs - auch host-only (Fedora-Wiki "Snapdragon WoA Laptop Install").
add_drivers+=" spi-hid spi-geni-qcom i2c-hid-of i2c-qcom-geni qcom_q6v5_pas qcom_pd_mapper pdr_interface pmic_glink pmic_glink_altmode qcom_battmgr ucsi_glink "
install_items+=" /usr/lib/firmware/updates/qcom/x1e80100/microsoft/Romulus/qcadsp8380.mbn /usr/lib/firmware/updates/qcom/x1e80100/microsoft/Romulus/qccdsp8380.mbn /usr/lib/firmware/updates/qcom/x1e80100/microsoft/Romulus/adsp_dtbs.elf /usr/lib/firmware/updates/qcom/x1e80100/microsoft/Romulus/cdsp_dtbs.elf /usr/lib/firmware/updates/qcom/x1e80100/microsoft/qcdxkmsuc8380.mbn /usr/lib/firmware/updates/qcom/x1e80100/microsoft/Romulus/qcdxkmsuc8380.mbn /usr/lib/firmware/updates/ath12k/WCN7850/hw2.0/board-2.bin "
EOC
echo "scmi-cpufreq" > "$R/etc/modules-load.d/sl7-scmi-cpufreq.conf"
mkdir -p "$R/etc/anaconda/conf.d"
cat > "$R/etc/anaconda/conf.d/90-sl7.conf" <<'EOC'
# SL7-Projekt: X1E-Kernelparameter vom Live-System ins installierte System uebernehmen (Fedora-Liste + systemd.tpm2_wait).
[Bootloader]
preserved_arguments =
    cio_ignore zfcp.allow_lun_scan
    speakup_synth apic noapic apm ide noht acpi video
    pci nodmraid nompath nomodeset noiswmd fips selinux
    biosdevname ipv6.disable net.ifnames net.ifnames.prefix
    nosmt vga rd.net.dns rd.net.dns-resolve-mode rd.net.dns-backend console
    clk_ignore_unused pd_ignore_unused arm64.nopauth systemd.tpm2_wait
EOC
mkdir -p "$R/usr/lib/sl7" "$R/var/lib/sl7"
cat > "$R/usr/lib/sl7/postinstall.sh" <<'EOS'
#!/bin/bash
# SL7-Projekt: laeuft einmal beim ersten Start des INSTALLIERTEN Systems (nicht im Live-System).
# - Anaconda uebernimmt "modprobe.blacklist=qcom_q6v5_pas" (nur fuer USB-C-Live-Boot noetig) als Denylist -> entfernen,
#   sonst gibt es keinen ADSP (Audio, Akku-Status, USB-C-Altmode).
# - X1E-Kernelparameter in allen Boot-Eintraegen sicherstellen, initramfs neu bauen.
set -u
LOG=/var/lib/sl7/postinstall.log; exec >>"$LOG" 2>&1; echo "== $(date -Is) sl7-postinstall"
DL=/etc/modprobe.d/anaconda-denylist.conf
# ADSP-Sperre (Denylist) bleibt bestehen, bis /usr/local/sbin/sl7-audio-freigeben das Lautstaerke-Limit am Geraet geprueft hat (30.09.2026)
if command -v grubby >/dev/null; then
  grubby --update-kernel=ALL --args="clk_ignore_unused pd_ignore_unused systemd.tpm2_wait=0" 2>/dev/null && echo "Kernelparameter gesetzt"
  grubby --set-default=/boot/vmlinuz-7.3.0-rc3-sl7b 2>/dev/null && echo "Standardkernel: Kernel B"
  grubby --info=ALL 2>/dev/null | grep -E '^(kernel|args|devicetree)' | head -20
fi
for k in /lib/modules/*/; do k=$(basename "$k"); [ -f "/boot/vmlinuz-$k" ] && dracut -f "/boot/initramfs-$k.img" "$k" >/dev/null 2>&1 && echo "initramfs $k neu"; done
touch /var/lib/sl7/postinstall-done; echo "fertig"
EOS
chmod 755 "$R/usr/lib/sl7/postinstall.sh"
cat > "$R/usr/lib/systemd/system/sl7-postinstall.service" <<'EOS'
[Unit]
Description=Surface Laptop 7: einmalige Nacharbeiten nach der Installation (Denylist, Kernelparameter)
ConditionKernelCommandLine=!rd.live.image
ConditionPathExists=!/var/lib/sl7/postinstall-done
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/lib/sl7/postinstall.sh

[Install]
WantedBy=multi-user.target
EOS
mkdir -p "$R/etc/systemd/system/multi-user.target.wants"; ln -sf /usr/lib/systemd/system/sl7-postinstall.service "$R/etc/systemd/system/multi-user.target.wants/sl7-postinstall.service"
mkdir -p "$R/etc/skel/Desktop"; sed 's/\r$//' "$B/SL7-Hinweise.txt" > "$R/etc/skel/Desktop/SL7-Hinweise.txt" 2>/dev/null || echo "    (SL7-Hinweise.txt fehlt noch)"
cat > "$R/etc/sl7-release" <<EOC
SL7-Projekt Fedora KDE Live (aarch64) - Build $(date -I)
Kernel A: $KA (ELLX 7.0.0-rc4-12 + konservative Patches; DTB-Varianten: standard, exp, i2cts)
Kernel B: $KB (Ubuntu 26.10 linux-source 7.3.0-5.5 + ItsLucas r15.1: rfkill, QSPI-Touchpad, GTCH-SPI-Touchscreen, spi-hid power, panel power, QRTR-Revert)
iptsd: alex-lentz/iptsd @3663e96 (haptischer Klick)   sl7-mac: 1.0.2   Firmware: Microsoft MSI 26.053.36539.0
EOC
echo "    dracut/anaconda/postinstall/modules-load geschrieben"

echo "=== [7b] Geraete-Korrekturen vom 30.09.2026 (Audio-Freigabe, Touchpad-udev, GPU-Firmware in initramfs, Deckel, Regdomain)"
sed 's/$//' "$B/sl7-audio-freigeben.sh" > "$R/usr/local/sbin/sl7-audio-freigeben"; chmod 755 "$R/usr/local/sbin/sl7-audio-freigeben"
sed 's/$//' "$B/80-sl7-touchpad-libinput.rules" > "$R/usr/lib/udev/rules.d/80-sl7-touchpad-libinput.rules"
printf '%s
' '# SL7: GPU-Firmware (Adreno X1-85) in die initramfs, msm laedt sie schon frueh' 'install_items+=" /usr/lib/firmware/qcom/gen70500_sqe.fw.xz /usr/lib/firmware/qcom/gen70500_gmu.bin.xz /usr/lib/firmware/qcom/x1e80100/gen70500_zap.mbn.xz "' > "$R/etc/dracut.conf.d/91-sl7-gpu.conf"
mkdir -p "$R/etc/systemd/logind.conf.d"; printf '[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
' > "$R/etc/systemd/logind.conf.d/sl7-lid.conf"
printf '[AC][SuspendAndShutdown]
LidAction=0

[Battery][SuspendAndShutdown]
LidAction=0

[LowBattery][SuspendAndShutdown]
LidAction=0
' > "$R/etc/xdg/powerdevilrc"
echo 'COUNTRY=DE' > "$R/etc/sysconfig/regdomain"
echo "=== [8] Live-initrds (dracut --no-hostonly, gleiche Argumente wie Fedoras kiwi-Build)"
PROFILE=(); [ -f "$R/.profile" ] && PROFILE=(--install /.profile)
for K in $KA $KB; do
  START=$(date +%s)
  run dracut --verbose --reproducible --no-hostonly --no-hostonly-cmdline "${PROFILE[@]}" --add " dmsquash-live livenet pollcdrom " --omit " multipath " --kver "$K" -f "/boot/initramfs-$K.img" >>"$L" 2>&1 || fail "dracut $K (siehe $L)"
  LS=$(lsinitrd "$R/boot/initramfs-$K.img" 2>/dev/null)
  echo "    $K: initramfs $(stat -c %s "$R/boot/initramfs-$K.img") B in $(( ($(date +%s)-START)/60 )) min; spi-hid=$(echo "$LS" | grep -c 'spi-hid') qcadsp=$(echo "$LS" | grep -c 'qcadsp8380') board-2=$(echo "$LS" | grep -c 'updates/ath12k') dmsquash=$(echo "$LS" | grep -c 'dmsquash-live-root')"
done

echo "=== [9] Aufraeumen"
rm -rf "$R/root/rpmbuild" "$R/root/sl7/iptsd" "$R/var/cache/dnf" "$R/var/cache/libdnf5" "$R/var/log/dnf5.log"* "$R/var/log/hawkey.log" "$R/tmp/"* "$R/var/tmp/"* 2>/dev/null
run dnf -y clean all >/dev/null 2>&1
bash "$H" umount >/dev/null
rm -f "$R/etc/resolv.conf.sl7"; [ -L "$R/etc/resolv.conf" ] || { rm -f "$R/etc/resolv.conf"; ln -s ../run/systemd/resolve/stub-resolv.conf "$R/etc/resolv.conf"; }

echo "=== [10] SELinux-Relabel (setfiles vom Host, Kontexte aus dem Rootfs; dnf im Chroot laesst Dateien ohne Label zurueck)"
command -v setfiles >/dev/null || apt-get install -y -qq policycoreutils >/dev/null 2>&1
FCD="$R/etc/selinux/targeted/contexts/files"
# Die vorkompilierten .bin passen nicht zur Host-pcre2 -> vorher wegschieben, setfiles nimmt dann die Textdateien
for b in "$FCD"/*.bin; do mv -f "$b" "$b.sl7tmp"; done
START=$(date +%s)
setfiles -F -T 0 -r "$R" -e "$R/proc" -e "$R/sys" -e "$R/dev" -e "$R/run" "$FCD/file_contexts" "$R" > /work/sl7/fedora/setfiles.log 2>&1; rc=$?
echo "    setfiles exit=$rc in $(( $(date +%s)-START )) s, Meldungen: $(wc -l < /work/sl7/fedora/setfiles.log)"; head -3 /work/sl7/fedora/setfiles.log
echo "    Kontrolle (Trockenlauf, sollte 0 sein): $(setfiles -n -v -F -r "$R" -e "$R/proc" -e "$R/sys" -e "$R/dev" -e "$R/run" "$FCD/file_contexts" "$R" 2>/dev/null | grep -c 'Would relabel') noch umzubenennen"
for b in "$FCD"/*.sl7tmp; do mv -f "$b" "${b%.sl7tmp}"; done
for f in usr/bin/sl7-mac usr/bin/iptsd boot/vmlinuz-$KA usr/lib/firmware/updates/ath12k/WCN7850/hw2.0/board-2.bin usr/lib/systemd/system/sl7-postinstall.service etc/iptsd.d/90-sl7-touchpad.conf usr/lib/firmware/qcom/x1e80100/adsps.jsn; do printf '    %-64s %s
' "$f" "$(getfattr --absolute-names --only-values -n security.selinux "$R/$f" 2>/dev/null)"; done
echo "=== Zusammenfassung"; ls "$R/lib/modules/"; ls -la "$R/boot/" | grep -E 'vmlinuz|initramfs'; du -sh "$R" 2>/dev/null | tail -1
echo "=== Phase 2 fertig"
