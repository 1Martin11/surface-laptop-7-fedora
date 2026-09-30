# Rohquellen (Kopien vom 13.09.2026)

| Datei/Ordner | Herkunft | Nutzen |
|---|---|---|
| `ls1590-comments-2026.json` | GitHub-API: linux-surface/linux-surface Issue #1590, Kommentare ab 2026-05-01 (100 Stueck) | Aktueller SL7-Diskussionsstand: Touchscreen spi10, iptsd-SIGILL, stubble.dtb_override, Lautsprecher, Suspend |
| `issue23.json`, `issue23-comments.json` | giantdwarf17/linux-surface-laptop-7 Issue #23 | iptsd@.service + 50-iptsd.rules (fehlen im ELLX-Deb) |
| `horizontblau-sl7.html/.txt` | https://horizontblau.de/linux/surface-laptop-7-linux.html | Writeup (Touchpad-Wedge, Messungen); Touchscreen-Knoten steht nur im GitHub-Kommentar |
| `nix1e/` | github.com/orvitpng/nix1e (NixOS-Flake fuer den SL7) | Device-Trees Touchpad/Touchscreen (spi19/spi10), QSPI, Firmware-Namen (iris/GPU/ADSP), neuere spi-hid-Serie (fullduplex.patch) |
| `x1e-nixos/` | github.com/scuggo/x1e-nixos | DT-Overlays Touchpad/Thermal/SAM, QSPI-Patches fuer spi-geni-qcom + gpi, rfkill-Patch, kernel.nix (Basis 7.1.2) |
| `touchscreen-i2c-thread/` | ratatoskr.run-Spiegel des linux-input-Threads 2026-09-07 (fQwQf) | Touchscreen-Variante hid-over-i2c @0x34 (Patch 0010) |
| `../dts/` | ELLX-Tree 7.0.0-rc4-12 | Romulus-Device-Tree-Quellen (Referenz fuer die Hardware-Tabelle) |
| `../../build/workflow/corpus.md` | Recherche-Agenten (7 Themen, 4 mit Gegenpruefung) | Vollstaendiger Fakten-/Quellenkorpus, aus dem das Dossier entstand |
