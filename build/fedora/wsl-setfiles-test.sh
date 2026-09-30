#!/usr/bin/env bash
export LC_ALL=C; R=/work/sl7/fedora/rootfs; FC=/etc/selinux/targeted/contexts/files/file_contexts
echo "--- Form 1: spec absolut (Host-Pfad), -r Rootfs"; setfiles -n -v -F -r "$R" "$R$FC" "$R/usr/lib/sl7" "$R/usr/lib/firmware/qcom/x1e80100" 2>&1 | tail -3; echo "exit=${PIPESTATUS[0]}"
echo "--- Form 2: spec relativ zum Alt-Root"; setfiles -n -v -F -r "$R" "$FC" "$R/usr/lib/sl7" 2>&1 | tail -3; echo "exit=${PIPESTATUS[0]}"
echo "--- Dry-Run usr/bin (Form 1, Threads)"; time setfiles -n -F -T 0 -r "$R" "$R$FC" "$R/usr/bin" 2>&1 | tail -2
echo "--- Was wuerde sich aendern (Stichprobe usr/bin/sl7-mac, usr/bin/iptsd falls da):"; setfiles -n -v -F -r "$R" "$R$FC" "$R/usr/bin/sl7-mac" "$R/usr/bin/bash" 2>&1 | tail -3
