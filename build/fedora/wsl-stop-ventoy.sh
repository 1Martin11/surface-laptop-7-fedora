#!/usr/bin/env bash
pkill -f "wsl-ventoy-test.sh"; pkill -x qemu-system-aar; sleep 1; pgrep -a -f "ventoy-test|qemu-system" | head; echo gestoppt
