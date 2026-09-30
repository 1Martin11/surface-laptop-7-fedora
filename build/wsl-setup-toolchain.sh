#!/usr/bin/env bash
# Richtet die Cross-Compile-Umgebung fuer den Surface-Laptop-7-Kernel in WSL2 (Ubuntu 26.04) ein.
# Aufruf (als root in WSL):  bash /mnt/c/Users/Martin/Desktop/Projekt\ Linux\ ARM/build/wsl-setup-toolchain.sh
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C LANG=C

PKGS=(
  build-essential gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu libc6-dev-arm64-cross
  bc bison flex libssl-dev libelf-dev dwarves kmod cpio rsync fakeroot devscripts debhelper dpkg-dev equivs
  python3 python3-pip python3-dev zstd device-tree-compiler msitools p7zip-full curl wget git xz-utils lz4 ccache
  clang lld llvm pkg-config libncurses-dev squashfs-tools xorriso mtools dosfstools qemu-user qemu-user-binfmt
  debootstrap u-boot-tools libdw-dev libpci-dev libudev-dev libcap-dev libtraceevent-dev libtracefs-dev
)

echo "=== apt-get update"
apt-get update -qq 2>&1 | tail -2

echo "=== Paketnamen pruefen"
MISSING=()
INSTALL=()
for p in "${PKGS[@]}"; do
  if apt-cache policy "$p" 2>/dev/null | grep "Candidate: [0-9]" >/dev/null; then INSTALL+=("$p"); else MISSING+=("$p"); fi
done
if [ ${#MISSING[@]} -gt 0 ]; then echo "Nicht im Repo (uebersprungen): ${MISSING[*]}"; fi

echo "=== apt-get install (${#INSTALL[@]} Pakete)"
apt-get install -y -qq "${INSTALL[@]}" 2>&1 | grep -vE '^(Selecting|Preparing|Unpacking|Setting up|Processing)' | tail -20
RC=${PIPESTATUS[0]}
echo "apt-get install exit=$RC"

echo "=== Versionen"
for t in aarch64-linux-gnu-gcc clang msiextract dtc fakeroot bison flex bc make ccache zstd qemu-aarch64 debootstrap; do
  if command -v "$t" >/dev/null 2>&1; then
    v=$("$t" --version 2>&1 | head -1)
    echo "OK   $t : $v"
  else
    echo "FEHLT $t"
  fi
done
echo "=== binfmt aarch64"
ls /proc/sys/fs/binfmt_misc/ 2>/dev/null | grep -i aarch64 || echo "(kein qemu-aarch64 binfmt registriert)"
