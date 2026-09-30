# Fedora KDE Linux on the Microsoft Surface Laptop 7 (13.8", Snapdragon X Elite / X1E80100)

Custom **Fedora KDE Live 44 (aarch64)** image for the Surface Laptop 7 "Romulus13", bootable from USB (plain dd or Ventoy) and installable with the normal Fedora installer. German documentation: [README.de.md](README.de.md), full guide in [docs/Fedora-ISO-Anleitung.md](docs/Fedora-ISO-Anleitung.md); this page is the English summary.

**Status (2026-09-30):** installed and running on real hardware next to Windows 11 (dual boot).

## What works

| Component | Status |
|---|---|
| Boot, device tree auto-selection (13.8"/15") | yes (dtbloader image, Fedora-style) |
| KDE Plasma (Wayland), GPU acceleration | yes, Adreno X1-85 (glmark2 ~5200) |
| Keyboard | yes (Surface Aggregator) |
| Haptic trackpad incl. force click | yes (iptsd fork with haptic click, calibrated for 13.8") |
| Touchscreen, pen | yes (SPI/GTCH variant; I²C variant available in the boot menu) |
| Wi-Fi (WCN7850) | yes, factory MAC restored (sl7-mac) |
| Bluetooth | adapter up with factory MAC |
| Speakers | yes, **kernel volume limit verified on device** (see warning) |
| Battery, charging, USB-C | yes (after the audio DSP is released) |
| NVMe | yes (3.3 GB/s read) |
| Suspend/resume | worked once in the live system, not yet tested in the installed system |
| Camera, fingerprint | no |

## Download

One-liner (downloads the parts, joins them, verifies the checksum):

* **Windows (PowerShell):** `irm https://raw.githubusercontent.com/1Martin11/surface-laptop-7-fedora/main/download-iso.ps1 | iex`
* **Linux/macOS:** `curl -fsSL https://raw.githubusercontent.com/1Martin11/surface-laptop-7-fedora/main/download-iso.sh | sh`

Manual way:

Release [v2026.09.30](https://github.com/1Martin11/surface-laptop-7-fedora/releases/tag/v2026.09.30): the ISO is split into three parts (GitHub limit 2 GB/file). Join them and verify:

```bash
cat Fedora-KDE-Live-44-SL7-20260930.iso.part-0 Fedora-KDE-Live-44-SL7-20260930.iso.part-1 Fedora-KDE-Live-44-SL7-20260930.iso.part-2 > Fedora-KDE-Live-44-SL7-20260930.iso
sha256sum -c Fedora-KDE-Live-44-SL7-20260930.iso.sha256
```
Windows: `cmd /c copy /b part-0+part-1+part-2 Fedora-KDE-Live-44-SL7-20260930.iso` (full names), then `Get-FileHash`.

## Boot and install

1. Copy the ISO to a **Ventoy** stick (the image contains the initrd list Ventoy needs) or write it raw (`dd`, or `Fedora-Stick-schreiben.ps1` on Windows).
2. On the Surface: UEFI → Secure Boot **off**; use the **USB-A** port.
3. Boot menu: keep the first entry, **Kernel B 7.3 (ItsLucas patches), USB-C safe (audio DSP off)**. Fallbacks: Kernel A 7.0 (ELLX base), stock Fedora kernel, diagnostic entries without splash, touchscreen variants.
4. Install with "Install to Hard Drive" (Anaconda). Automatic partitioning uses free space and reuses the Windows EFI partition; Windows stays bootable (GRUB entry + firmware menu).
5. After the first boot run `sudo sl7-audio-freigeben` once: it loads the audio DSP, checks the kernel speaker limit (`SpkrLeft/Right PA Volume max=6`, `WSA_RX0/RX1 Digital Volume max=81`), sets the amplifiers to 0 and only then removes the block. Battery status and USB-C alt-mode appear at the same time.

## Speaker warning

The X1E80100 has **no hardware speaker protection** under Linux; community members have destroyed speakers. Both custom kernels carry the volume-limit patch, and the image keeps the audio DSP blocked until the limit has been verified on the device. Keep the volume at **70 % or less** and never select the PipeWire **"Pro Audio"** profile. A module blacklist is not a gentle option: it disables the whole sound card.

## Kernels

* **Kernel B `7.3.0-rc3-sl7b`** (default): Ubuntu 26.10 `linux-source-7.3.0` + [ItsLucas](https://github.com/ItsLucas/linux-surface-laptop-7) patches r15.1 (rfkill, QSPI touchpad, GTCH SPI touchscreen, spi-hid power, panel power, QRTR revert). Note: this Ubuntu config runs without SELinux (LSM list), so the installer writes `selinux=0`.
* **Kernel A `7.0.0-rc4-sl7`**: ELLX 7.0.0-rc4-12 + conservative patches, fallback.
* Device-tree variants: standard, `-i2cts` (I²C touchscreen), `-exp` (Kernel A, experimental).
* Both are packaged as RPMs; `dnf` excludes `kernel*` so a stock update cannot take over the default entry.

## Repository layout

| Path | Content |
|---|---|
| `build/fedora/` | the whole pipeline: `wsl-fedora-*.sh` phases 1–4 (rootfs copy, chroot update, iptsd RPM, kernels, dtbloader images, firmware, ISO build with xorriso), QEMU tests (`qemu-drive.py`, `qemu-install.py`), `grub-sl7.cfg`, `sl7-audio-freigeben.sh`, udev rule, `ventoy-initrd.cfg` |
| `build/patches-upstream/` | kernel patches and DTS sources |
| `docs/` | German guide, research dossier, open issues, device-tree sources, collected community sources |
| `hardware/` | hardware inventory script (Windows) and `sl7-ssh.py` (remote maintenance of the live/installed system) |
| `Fedora-Stick-schreiben.ps1` | raw USB writer for Windows |

Build host: Windows 11 + WSL2 (Ubuntu), cross-compiled kernels, Fedora rootfs in a qemu-user chroot, boot tests in `qemu-system-aarch64` (including a Ventoy chain test).

## Open items

Suspend test in the installed system, Bluetooth pairing, touchscreen fine-tuning, haptic feedback while dragging (needs driver work: the spi-hid device exposes no HID haptic capability), camera, cleanup of old Ubuntu leftovers on the EFI partition.

## Credits

ItsLucas (linux-surface-laptop-7), bryce-hoehn, the ELLX project, alex-lentz (iptsd haptic-click fork), valeronm (sl7-mac), fQwQf (I²C touchscreen), the Fedora and Ubuntu concept1 / x1e communities, horizontblau and nix1e write-ups. Firmware blobs come from Microsoft's driver package.
