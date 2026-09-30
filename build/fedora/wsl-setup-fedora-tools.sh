#!/usr/bin/env bash
# Werkzeuge fuer das Fedora-ISO-Projekt in WSL: QEMU (aarch64-Boot-Tests), UEFI-Firmware, ISO-/squashfs-Werkzeuge, rpm/dnf.
# Aufruf (als root in WSL):  bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora/wsl-setup-fedora-tools.sh"
set -uo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
apt-get update -qq 2>&1 | tail -1
PK="qemu-system-arm qemu-efi-aarch64 qemu-utils ovmf squashfs-tools xorriso isolinux syslinux-utils mtools dosfstools rpm rpm2cpio cpio dnf libarchive-tools genisoimage p7zip-full zstd python3-rpm rsync"
OK=(); MISS=()
for p in $PK; do if apt-cache policy "$p" 2>/dev/null | grep "Candidate: [0-9]" >/dev/null; then OK+=("$p"); else MISS+=("$p"); fi; done
[ ${#MISS[@]} -gt 0 ] && echo "nicht im Repo: ${MISS[*]}"
apt-get install -y -qq "${OK[@]}" 2>&1 | grep -vE '^(Selecting|Preparing|Unpacking|Setting up|Processing)' | tail -3
echo "=== Versionen"
for t in qemu-system-aarch64 qemu-img mksquashfs unsquashfs xorriso rpm rpm2cpio dnf bsdtar 7z; do
  if command -v "$t" >/dev/null 2>&1; then printf 'OK    %-20s %s\n' "$t" "$("$t" --version 2>&1 | head -1 | cut -c1-70)"; else echo "FEHLT $t"; fi
done
echo "=== UEFI-Firmware fuer aarch64"
ls -la /usr/share/AAVMF/AAVMF_CODE.fd /usr/share/qemu-efi-aarch64/QEMU_EFI.fd 2>/dev/null || find /usr/share -iname '*AAVMF*' -o -iname 'QEMU_EFI*' 2>/dev/null | head
echo "=== KVM in WSL?"; ls -la /dev/kvm 2>/dev/null || echo "(kein /dev/kvm - QEMU laeuft rein emuliert, langsam aber ausreichend fuer Boot-Tests)"
echo "=== Platz"; df -h /work | tail -1
