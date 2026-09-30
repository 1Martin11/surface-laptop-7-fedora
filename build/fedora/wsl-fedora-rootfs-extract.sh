#!/usr/bin/env bash
# EROFS-Live-Rootfs komplett nach /work/sl7/fedora/rootfs entpacken (Remaster-Basis + Chroot) und analysieren:
# Kernel-Image-Sektionen (dtbauto?), initrd-Module, Kernelversion, DTBs, grub2/kernel-install, Firmware, Pakete.
set -uo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
W=/work/sl7/fedora
A=$W/analyse/isofs
R=$W/rootfs
apt-get install -y -qq dracut-core erofs-utils >/dev/null 2>&1 || true
command -v lsinitrd >/dev/null 2>&1 || echo "lsinitrd fehlt weiterhin"

echo "=== [1] Kernel-Image (PE) Sektionen"
aarch64-linux-gnu-objdump -h "$A/boot/aarch64/loader/linux" 2>/dev/null | awk '/^ +[0-9]+ /{print $2, $3}' | sort | uniq -c | sort -rn | head -12
echo "--- Strings: romulus / dtbauto / X1E:"; strings -n 8 "$A/boot/aarch64/loader/linux" | grep -iE 'romulus|dtbauto|X1E80100|hwids|stubble|systemd-stub' | sort -u | head -12

echo; echo "=== [2] initrd (zstd) - dracut-Module und Kernelversion"
if command -v lsinitrd >/dev/null 2>&1; then
  lsinitrd "$A/boot/aarch64/loader/initrd" 2>/dev/null | sed -n '/dracut modules/,/^=====/p' | tr '\n' ' ' | cut -c1-1200; echo
  lsinitrd "$A/boot/aarch64/loader/initrd" 2>/dev/null | grep -oE 'lib/modules/[^/]+/' | sort -u | head -2
  echo "--- qcom/msm/nvme/pcie-Module im initrd:"; lsinitrd "$A/boot/aarch64/loader/initrd" 2>/dev/null | grep -oE '[a-z0-9_-]+\.ko(\.xz|\.zst)?' | grep -E 'qcom|msm|nvme|pcie|phy-qcom|ath12k|spi-hid|dwc3|ufs|cpufreq|scmi' | sort -u | tr '\n' ' '; echo
  echo "--- Firmware im initrd (qcom/ath/qca):"; lsinitrd "$A/boot/aarch64/loader/initrd" 2>/dev/null | grep -E 'firmware/(qcom|ath|qca)' | wc -l
else
  mkdir -p /tmp/initrd && (cd /tmp/initrd && zstd -dc "$A/boot/aarch64/loader/initrd" | cpio -t 2>/dev/null | grep -oE 'lib/modules/[^/]+/' | sort -u | head -2)
fi

echo; echo "=== [3] EROFS-Rootfs entpacken (2,8 GB komprimiert -> Klartext; dauert)"
if [ ! -d "$R/usr" ]; then
  rm -rf "$R"   # fsck.erofs legt das Zielverzeichnis selbst an und verweigert ein vorhandenes
  START=$(date +%s)
  fsck.erofs --extract="$R" "$A/LiveOS/squashfs.img" 2>&1 | tail -2
  echo "    Dauer: $(( ($(date +%s) - START) ))s"
fi
du -sh "$R" 2>/dev/null
cat "$R/etc/os-release" | head -3

echo; echo "=== [4] Kernel/DTB/Boot im Rootfs"
ls "$R/usr/lib/modules/"
for m in "$R"/usr/lib/modules/*; do
  echo "--- $(basename "$m"): vmlinuz=$(ls -la "$m/vmlinuz" 2>/dev/null | awk '{print $5}') dtb-Ordner=$([ -d "$m/dtb" ] && echo ja || echo nein)"
  ls "$m/dtb/qcom/" 2>/dev/null | grep -iE 'x1e80100|romulus' | head -8 | sed 's/^/      /'
  echo "      qcom-DTBs gesamt: $(ls "$m/dtb/qcom/" 2>/dev/null | wc -l)"
done
echo "--- /boot:"; ls -la "$R/boot/" 2>/dev/null | head; ls "$R/boot/loader/entries/" 2>/dev/null
echo "--- BLS-Eintrag:"; cat "$R/boot/loader/entries/"*.conf 2>/dev/null | head -12
echo "--- /etc/kernel/cmdline:"; cat "$R/etc/kernel/cmdline" 2>/dev/null
echo "--- kernel-install Plugins:"; ls "$R/usr/lib/kernel/install.d/" 2>/dev/null | tr '\n' ' '; echo
echo "--- devicetree-Logik in kernel-install / grubby / grub.d:"; grep -rl -i 'devicetree' "$R/usr/lib/kernel/install.d/" "$R/etc/grub.d/" "$R/usr/sbin/grubby" "$R/usr/libexec/grubby/" 2>/dev/null | head; grep -rn -i 'devicetree\|dtb' "$R/usr/lib/kernel/install.d/"*.install 2>/dev/null | head -8
echo "--- grub2-Pakete / shim:"; ls "$R/boot/efi/EFI/" 2>/dev/null; ls "$R/usr/lib/grub/" 2>/dev/null
echo "--- dracut-Konfiguration:"; ls "$R/usr/lib/dracut/dracut.conf.d/" "$R/etc/dracut.conf.d/" 2>/dev/null; cat "$R/usr/lib/dracut/dracut.conf.d/"*.conf 2>/dev/null | grep -v '^#' | grep -v '^$' | head -12

echo; echo "=== [5] Firmware im Rootfs"
ls "$R/usr/lib/firmware/ath12k/WCN7850/hw2.0/" 2>/dev/null | head -5
echo "qcom/x1e80100: $(ls "$R/usr/lib/firmware/qcom/x1e80100/" 2>/dev/null | wc -l) Dateien"; ls "$R/usr/lib/firmware/qcom/x1e80100/" 2>/dev/null | head -12 | tr '\n' ' '; echo
ls -d "$R"/usr/lib/firmware/qcom/x1e80100/*/ 2>/dev/null | sed "s|$R/usr/lib/firmware/||"
ls "$R/usr/lib/firmware/qca/" 2>/dev/null | grep -i hmt | tr '\n' ' '; echo
ls "$R/usr/lib/firmware/qcom/" 2>/dev/null | grep -iE 'gen70500|a740' | tr '\n' ' '; echo

echo; echo "=== [6] Pakete (rpm --root)"
rpm --root "$R" -qa 2>/dev/null | wc -l | sed 's/^/    Pakete: /'
for p in kernel kernel-core kernel-modules linux-firmware qcom-firmware iptsd libinput pipewire wireplumber alsa-ucm-conf plymouth dracut grub2-efi-aa64 shim-aa64 grubby systemd-ukify mesa-vulkan-drivers mesa-dri-drivers anaconda-live; do
  printf '    %-22s %s\n' "$p" "$(rpm --root "$R" -q "$p" 2>/dev/null | head -1)"
done
echo "=== fertig"
