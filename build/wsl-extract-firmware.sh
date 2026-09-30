#!/usr/bin/env bash
# Baut das Firmware-Paket fuer den Surface Laptop 7 (Romulus13) aus dem offiziellen Microsoft-Treiberpaket (MSI):
#   1) MSI herunterladen + mit msiextract entpacken
#   2) die signierten Romulus-Blobs nach lib/firmware/qcom/x1e80100/microsoft/Romulus/ (+ Kopie in microsoft/) legen
#   3) ath12k WCN7850 board-2.bin von CodeLinaro holen und den SL7-Eintrag (subsystem-device 1107) einbauen
#   4) alles als tar.xz nach build/out/ schreiben (auf dem Laptop: sudo tar -xJf ... -C /)
# Aufruf (als root in WSL):
#   MSI_URL="https://download.microsoft.com/.../SurfaceLaptop7_ARM_Win11_....msi" bash "/mnt/c/.../build/wsl-extract-firmware.sh"
set -euo pipefail
export LC_ALL=C
W=/work/sl7/firmware
WINOUT="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out"
MSI_URL=${MSI_URL:-}
MSI_FILE=${MSI_FILE:-}
mkdir -p "$W" "$WINOUT"
cd "$W"

if [ -z "$MSI_URL" ] && [ -z "$MSI_FILE" ]; then
  echo "FEHLER: MSI_URL (oder MSI_FILE=/pfad/zur.msi) setzen. Quelle: Microsoft 'Surface Laptop 7 (Snapdragon) drivers and firmware'." >&2
  exit 1
fi
if [ -z "$MSI_FILE" ]; then
  MSI_FILE="$W/$(basename "${MSI_URL%%\?*}")"
  if [ ! -s "$MSI_FILE" ]; then
    echo "=== [1/4] MSI herunterladen: $MSI_URL"
    curl -L --fail --retry 3 -o "$MSI_FILE.part" "$MSI_URL" && mv "$MSI_FILE.part" "$MSI_FILE"
  else
    echo "=== [1/4] MSI bereits vorhanden: $MSI_FILE"
  fi
fi
ls -la "$MSI_FILE"
VER=$(basename "$MSI_FILE" .msi | sed 's/^SurfaceLaptop7_ARM_Win11_//')

echo "=== [2/4] MSI entpacken (msiextract)"
rm -rf "$W/msi" && mkdir -p "$W/msi"
msiextract -C "$W/msi" "$MSI_FILE" >/dev/null
echo "    Dateien: $(find "$W/msi" -type f | wc -l)"

# qcvss8380*.mbn = Video-Firmware fuer den iris-Decoder/Encoder (H.264/HEVC/VP9/AV1), Pfad im DTS-Patch 0012 (nix1e-Vorbild)
FW_FILES=(adsp_dtbs.elf adspr.jsn adsps.jsn adspua.jsn battmgr.jsn cdsp_dtbs.elf cdspr.jsn qcadsp8380.mbn qccdsp8380.mbn qcdxkmsuc8380.mbn qcdxkmsucpurwa.mbn qcvss8380.mbn qcvss8380_pa.mbn qcav1e8380.mbn)
STAGE="$W/stage"
rm -rf "$STAGE"
DST="$STAGE/lib/firmware/updates/qcom/x1e80100/microsoft/Romulus"
mkdir -p "$DST"
echo "=== Romulus-Blobs suchen"
for f in "${FW_FILES[@]}"; do
  src=$(find "$W/msi" -type f -iname "$f" | head -n1 || true)
  if [ -n "$src" ]; then
    cp -v "$src" "$DST/$f" | sed 's/^/    /'
  else
    echo "    WARNUNG: $f nicht im MSI gefunden"
  fi
done
# Kopie eine Ebene hoeher (aeltere Kernel/Firmware-Suchpfade erwarten qcom/x1e80100/microsoft/<datei>)
mkdir -p "$STAGE/lib/firmware/updates/qcom/x1e80100/microsoft"
cp "$DST"/* "$STAGE/lib/firmware/updates/qcom/x1e80100/microsoft/"
echo "=== Weitere Qualcomm-Blobs im MSI (zur Info, nicht kopiert):"
find "$W/msi" -type f \( -iname '*.mbn' -o -iname '*.jsn' -o -iname '*.elf' -o -iname '*.tlv' \) | sed "s|$W/msi/||" | sort | head -60

echo "=== [3/4] ath12k board-2.bin fuer WCN7850 mit SL7-Eintrag (subsystem-device 1107)"
BD="$W/board"
mkdir -p "$BD" && cd "$BD"
curl -L --fail --retry 3 -o board-2.bin "https://git.codelinaro.org/clo/ath-firmware/ath12k-firmware/-/raw/main/WCN7850/hw2.0/board-2.bin?ref_type=heads"
curl -L --fail --retry 3 -o ath12k-bdencoder "https://raw.githubusercontent.com/qca/qca-swiss-army-knife/master/tools/scripts/ath12k/ath12k-bdencoder"
chmod +x ath12k-bdencoder
./ath12k-bdencoder -e board-2.bin >/dev/null
python3 - <<'PY'
import json
match_name = "bus=pci,vendor=17cb,device=1107,subsystem-vendor=17cb,subsystem-device=3378,qmi-chip-id=2,qmi-board-id=255"
new_name   = "bus=pci,vendor=17cb,device=1107,subsystem-vendor=17cb,subsystem-device=1107,qmi-chip-id=2,qmi-board-id=255"
data = json.load(open("board-2.json", encoding="utf-8"))
found = present = False
for group in data:
    for entry in group.get("board", []):
        names = entry.get("names", [])
        if match_name in names:
            found = True
            if new_name in names: present = True
            else: names.append(new_name)
            break
    if found: break
if not found: raise SystemExit("Referenz-Eintrag (subsystem-device=3378) nicht in board-2.json gefunden")
if present: print("    SL7-Eintrag war schon vorhanden (upstream gefixt?)")
else:
    json.dump(data, open("board-2.json", "w", encoding="utf-8"), indent=4); print("    SL7-Eintrag hinzugefuegt")
PY
./ath12k-bdencoder -c board-2.json >/dev/null
mkdir -p "$STAGE/lib/firmware/updates/ath12k/WCN7850/hw2.0"
cp board-2.bin "$STAGE/lib/firmware/updates/ath12k/WCN7850/hw2.0/board-2.bin"
cd "$W"

echo "=== [4/4] Paket schreiben"
OUTTAR="$WINOUT/sl7-firmware-msi-$VER.tar.xz"
tar -C "$STAGE" -cJf "$OUTTAR" lib
cp "$OUTTAR" "$W/"
find "$STAGE" -type f -printf '%10s  %P\n' | sort -k2 > "$WINOUT/sl7-firmware-msi-$VER.list.txt"
sha256sum "$OUTTAR" > "$OUTTAR.sha256"
ls -la "$OUTTAR"
echo "Installieren auf dem Laptop:  sudo tar -xJf $(basename "$OUTTAR") -C /  &&  sudo update-initramfs -u"
