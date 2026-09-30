#!/usr/bin/env bash
set -uo pipefail; export LC_ALL=C
B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"; W=/work/sl7/fedora
sed 's/\r$//' "$B/qemu-install.py" > $W/qemu-install.py; sed 's/\r$//' "$B/qemu-sim.py" > $W/qemu-sim.py
echo "=== Simulation install"; timeout 300 python3 $W/qemu-install.py /tmp/sim-install.log 250 install kernel=sl7b -- python3 -u $W/qemu-sim.py install; echo "rc=$?"
grep -a '^\[qemu-install\|\[sim\] befehl' /tmp/sim-install.log | cut -c1-170
echo "=== Simulation disk"; timeout 300 python3 $W/qemu-install.py /tmp/sim-disk.log 250 disk setdefault=7.0.0-rc4-sl7 -- python3 -u $W/qemu-sim.py disk; echo "rc=$?"
grep -a '^\[qemu-install\|\[sim\] befehl\|\[sim\] grubby' /tmp/sim-disk.log | cut -c1-170
echo "=== Kickstart wie gesendet:"; sed -n "/cat > \/root\/ks.cfg/,/^EOK/p" /tmp/sim-install.log | tr -d '\r'
echo "=== Schritt-7-Zeile wie gesendet:"; grep -a 'awk' /tmp/sim-install.log | head -1 | tr -d '\r'
