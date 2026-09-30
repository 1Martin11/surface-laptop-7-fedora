# Patches fuer den SL7-Kernel (Basis: ELLX-Kernel Tag 7.0.0-rc4-12)

**Kanonisch:** `sl7-tree-full.diff` = kompletter Stand aller Aenderungen gegenueber dem Tag.
Anwenden: `bash build/wsl-apply-sl7-patches.sh` (frischer Checkout + git apply), dann `PKGREV=<n> bash build/wsl-build-kernel.sh`.

Einzelpatches (Dokumentation der Herkunft, alle in sl7-tree-full.diff enthalten):
- Community `patches/outgoing/dwc3-usb/0001..0003` (gits/giantdwarf17_linux-surface-laptop-7): USB-PHY-Reinit nach Resume (Oliver White, 2026-06-02)
- `ubuntu-speaker-limit.patch`: UBUNTU SAUCE "ASoC: qcom: x1e80100: limit speaker volumes" (LP #2149808) aus Ubuntu resolute linux 7.0.0-38.38
- `hamoa-usb-qmp-phy-supplies-romulus-only.patch`: upstream 4458dcd (2026-08-03), nur der Romulus-Hunk; `hamoa-usb-qmp-phy-supplies.patch` = Original mit allen Boards
- `0010-romulus13-touchscreen-hid-over-i2c.patch`: linux-input 2026-09-07 (fQwQf) + eigene pinctrl — EXPERIMENTELL
- nur im Gesamt-Diff: Touchscreen spi10 (hid-over-spi, Quellen linux-surface#1590 horizontblau 2026-08-25 / orvitpng/nix1e), Touchpad-Wedge-Fix (regulator-boot-on, gpio120), iris-Videodecoder (qcvss8380.mbn), CPU-Thermal-Trips 85 C (scuggo/x1e-nixos)

Rev. 1 = dwc3; Rev. 2 = + Speaker-Limit, USB-PHY, Touchscreen i2c8; Rev. 3 = + Touchscreen spi10, Touchpad-Fix, iris, Thermal.
