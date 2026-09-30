#!/usr/bin/env bash
# Phase 5: komplette Anaconda-Installation des SL7-ISO in QEMU (aarch64 virt, EDK2 mit persistentem NVRAM, virtuelle NVMe 64 GB)
# und anschliessende Boots vom installierten System mit allen drei Kerneln.
#   bash wsl-fedora-qemu-install.sh install   -> frische NVMe + NVRAM, Live-Boot Kernel B, Kickstart-Installation (Treiber qemu-install.py)
#   bash wsl-fedora-qemu-install.sh disk      -> Boot 1 (Standard = Kernel B) -> Standard auf A -> Boot 2 (A) -> Standard auf Stock -> Boot 3 -> Standard zurueck auf B
#   bash wsl-fedora-qemu-install.sh all       -> beides nacheinander
#   bash wsl-fedora-qemu-install.sh peek      -> Zwischenstand der Logs
set -uo pipefail; export LC_ALL=C
W=/work/sl7/fedora; Q=$W/qemu; OUT=$W/out; B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"
ISO=$(ls -t "$OUT"/*.iso | head -1); CODE=/usr/share/AAVMF/AAVMF_CODE.no-secboot.fd; VARS=/usr/share/AAVMF/AAVMF_VARS.fd
KA=7.0.0-rc4-sl7; KB=7.3.0-rc3-sl7b; KS=6.19.10-300.fc44.aarch64
MODE=${1:-all}
mkdir -p "$Q"; sed 's/\r$//' "$B/qemu-install.py" > "$W/qemu-install.py"
COMMON=(qemu-system-aarch64 -M virt -cpu cortex-a72 -smp 8 -m 8G -nographic -no-reboot
        -drive "if=pflash,format=raw,readonly=on,file=$CODE" -drive "if=pflash,format=raw,file=$Q/vars.fd"
        -device virtio-rng-pci -device virtio-gpu-pci -netdev user,id=n0 -device virtio-net-pci,netdev=n0
        -drive "file=$Q/nvme.qcow2,if=none,id=nv0,format=qcow2,cache=unsafe" -device nvme,drive=nv0,serial=SL7NVME01)
CD=(-drive "file=$ISO,media=cdrom,if=none,id=cd0,readonly=on" -device virtio-scsi-pci,id=scsi0 -device scsi-cd,drive=cd0)
summ() { local log=$1; grep -a '^\[qemu-install' "$log" | tr -d '\r' | tail -${2:-6} | sed 's/^/    /'; }
peek() { for f in "$Q"/install.log "$Q"/disk-b.log "$Q"/disk-a.log "$Q"/disk-stock.log; do [ -f "$f" ] || continue
  echo "=== $f ($(stat -c %s "$f") B, $(date -r "$f" +%H:%M:%S))"; summ "$f" 8
  echo "--- letzte Zeilen:"; tail -c 3000 "$f" | tr -d '\r' | grep -av '^\s*$' | tail -12 | cut -c1-200; done
  echo "--- laufende qemu: $(pgrep -c qemu-system-aarch64)"; }
do_install() {
  pkill -x qemu-system-aar 2>/dev/null; sleep 1
  echo "=== Phase 5a: Installation  ISO=$ISO  $(date +%H:%M:%S)"
  rm -f "$Q/nvme.qcow2" "$Q/vars.fd"; qemu-img create -f qcow2 "$Q/nvme.qcow2" 64G >/dev/null && cp "$VARS" "$Q/vars.fd" || { echo "Vorbereitung fehlgeschlagen"; return 1; }
  START=$(date +%s)
  python3 "$W/qemu-install.py" "$Q/install.log" 14400 install kernel=sl7b -- "${COMMON[@]}" "${CD[@]}"; rc=$?
  echo "=== Installation: rc=$rc nach $(( $(date +%s)-START )) s"; summ "$Q/install.log" 12
  grep -aoE 'Installation (complete|finished)|Performing post-installation|Configuring installed system|Installing boot loader|Creating BLS|Running post-installation scripts' "$Q/install.log" | sort | uniq -c | sed 's/^/    /'
  cp -f "$Q/install.log" "$B/out/logs/qemu-install.log" 2>/dev/null
  return $rc; }
do_disk() {
  pkill -x qemu-system-aar 2>/dev/null; sleep 1
  [ -s "$Q/nvme.qcow2" ] || { echo "keine NVMe-Datei - erst install"; return 1; }
  local total=0
  for run in "b:$KA:disk-b" "a:$KS:disk-a" "stock:$KB:disk-stock"; do
    IFS=: read -r name next log <<< "$run"
    echo "=== Phase 5b: Boot vom installierten System ($name), danach Standard -> $next  $(date +%H:%M:%S)"; START=$(date +%s)
    python3 "$W/qemu-install.py" "$Q/$log.log" 1500 disk setdefault="$next" -- "${COMMON[@]}"; rc=$?; total=$((total+rc))
    echo "    rc=$rc nach $(( $(date +%s)-START )) s  Kernel: $(grep -aoE 'Linux version [^ ]+' "$Q/$log.log" | head -1)"
    summ "$Q/$log.log" 14
    cp -f "$Q/$log.log" "$B/out/logs/qemu-$log.log" 2>/dev/null
    [ $rc -eq 0 ] || break
  done
  return $total; }
case "$MODE" in
  install) do_install ;;
  disk) do_disk ;;
  all) do_install && do_disk; R=$?; echo "=== Phase 5 Ergebnis: $R (0 = alles ok)  $(date +%H:%M:%S)"; exit $R ;;
  peek) peek ;;
  *) echo "install|disk|all|peek"; exit 1 ;;
esac
