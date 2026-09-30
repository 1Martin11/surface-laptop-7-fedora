#!/usr/bin/env bash
# Klont die Kernel-Kandidaten fuer den Surface Laptop 7 (Romulus13) nach /work/sl7/kernel (WSL-Dateisystem, schnell).
# Aufruf (als root in WSL):  bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-clone-kernels.sh"
set -uo pipefail
K=/work/sl7/kernel
mkdir -p "$K"
cd "$K" || exit 1

clone() {  # clone <url> <branch> <dir>
  local url=$1 br=$2 dir=$3
  if [ -d "$dir/.git" ]; then
    echo "=== $dir existiert, fetch $br"
    git -C "$dir" fetch -q --depth 1 origin "$br" && git -C "$dir" reset -q --hard FETCH_HEAD
  else
    echo "=== clone $url ($br) -> $dir"
    git clone -q --depth 1 --single-branch -b "$br" "$url" "$dir"
  fi
  echo "    HEAD: $(git -C "$dir" log -1 --format='%h %cd %s' --date=short 2>/dev/null)"
  if [ -f "$dir/Makefile" ]; then
    echo "    Version: $(grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL|EXTRAVERSION) =' "$dir/Makefile" | awk '{print $3}' | paste -sd '.' | sed 's/\.$//; s/\.\(-rc\)/\1/')"
  fi
  ls "$dir/arch/arm64/boot/dts/qcom/" 2>/dev/null | grep -i romulus | sed 's/^/    dts: /'
}

# 1) ELLX-Kernel (Community-Prebuilt-Quelle fuer den SL7, basiert auf dem Ubuntu-Concept-Tree)
clone https://github.com/ProgrammerIn-wonderland/ELLX-Kernel 7.0-sl7 ellx-7.0-sl7

# 2) Ubuntu-Concept-Kernel (Canonical, Launchpad) - qcom-x1e-7.0 Branch
clone https://git.launchpad.net/~ubuntu-concept/ubuntu/+source/linux/+git/resolute qcom-x1e-7.0 concept-qcom-x1e-7.0

echo "=== fertig"
du -sh "$K"/* 2>/dev/null
