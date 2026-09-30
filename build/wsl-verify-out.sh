#!/usr/bin/env bash
# Prueft die Artefakte einer Revision in build/out: stubble-Image (dtbauto-Sektionen, romulus13-DTB enthalten), Paketinhalt, Pruefsummen.
set -uo pipefail
export LC_ALL=C
REV=${REV:-3}
D="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out/7.0.0-rc4-sl7-$REV"
S="$D/vmlinuz-7.0.0-rc4-sl7.stubble"
cd "$D" || exit 1
echo "=== Revision $REV: $(ls | tr '\n' ' ')"
echo "--- .dtbauto-Sektionen: $(aarch64-linux-gnu-objdump -h "$S" | grep -c dtbauto)"
SZ=$(stat -c %s x1e80100-microsoft-romulus13.dtb); HEX=$(printf '%08x' "$SZ")
echo "--- romulus13.dtb Groesse $SZ (0x$HEX) im stubble-Image: $(aarch64-linux-gnu-objdump -h "$S" | grep -c "$HEX")"
echo "--- Strings iris/cooling im Image: $(strings -n 6 "$S" | grep -c 'qcvss8380\|cooling-device')"
echo "--- DTB-Inhalt (aus dem .dtb): touchscreen@0=$(dtc -I dtb -O dts x1e80100-microsoft-romulus13.dtb 2>/dev/null | grep -c 'touchscreen@0 {') touchscreen@34=$(dtc -I dtb -O dts x1e80100-microsoft-romulus13.dtb 2>/dev/null | grep -c 'touchscreen@34 {') cooling-device=$(dtc -I dtb -O dts x1e80100-microsoft-romulus13.dtb 2>/dev/null | grep -c cooling-device) qcvss=$(dtc -I dtb -O dts x1e80100-microsoft-romulus13.dtb 2>/dev/null | grep -c qcvss8380)"
echo "--- Paket: romulus13.dtb im linux-image: $(dpkg-deb -c linux-image-*.deb | grep -c 'qcom/x1e80100-microsoft-romulus13.dtb')  Version: $(dpkg-deb -f linux-image-*.deb Version)"
echo "--- SHA256SUMS:"; sha256sum -c SHA256SUMS 2>&1 | sed 's/^/    /'
