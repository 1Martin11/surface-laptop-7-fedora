# Build-Rezept – Surface Laptop 7 13,8" (Romulus13), Kernel `7.0.0-rc4-sl7`

Stand: 13.09.2026. Ausführbare Anleitung, keine Begründungen – die stehen in der Endfassung des Dossiers
(`docs/SL7-Linux-Dossier.md`) und in `build/workflow/local-facts.md` (maßgeblich bei Widersprüchen).
Offene Risiken und die Testreihenfolge auf dem Gerät stehen in `docs/Offene-Punkte.md`.

- **Build-Host:** x86-Windows-PC, WSL2 Ubuntu 26.04, alle Skripte laufen **als root in WSL**, gestartet **aus PowerShell** (Git-Bash verbiegt `/mnt/c`-Pfade).
- **Arbeitsverzeichnis in WSL:** `/work/sl7/` (schnelles WSL-Dateisystem). Ergebnisse landen zusätzlich unter `C:\Users\Martin\Desktop\Projekt Linux ARM\build\out\`.
- **Aktueller Stand:** Patch-Stand = `build/patches-upstream/sl7-tree-full.diff` (571 Zeilen, 6 Dateien), Paket-Revision **3** = `build/out/7.0.0-rc4-sl7-3/`.
- **Gerät noch nie gebootet:** Alle Erwartungswerte in Abschnitt 8 sind aus Cross-Build und arm64-Chroot abgeleitet, nicht auf dem Laptop gemessen **(unverifiziert auf dem Gerät)**.
- **Lautsprecher:** Schutz ist das Kernel-Volume-Limit (ab Revision 2 eingebaut). Lautstärke höchstens 70 %, niemals 100 %, niemals das PipeWire-Profil „Pro Audio“. Die harte Modulsperre (`SL7_NO_SPEAKER=1`) legt die **gesamte** Soundkarte still – auch Kopfhörer und Mikrofone.

---

## 1 Voraussetzungen auf dem Build-PC

Name der WSL-Distribution prüfen (muss `Ubuntu` heißen, sonst `-d <Name>` in allen Befehlen anpassen):

```bash
wsl -l -v
```

Ubuntu-Version, Kerne, RAM und freien Platz im WSL-Dateisystem prüfen (Soll: Ubuntu 26.04, ≥ 8 Kerne, ≥ 16 GB RAM, ≥ 60 GB frei; lokal verifiziert: Ryzen 9 9950X3D/32 Threads, 31 GB RAM, 925 GB frei):

```bash
wsl -d Ubuntu -u root -- bash -c "lsb_release -d; nproc; free -g | head -2; df -h /"
```

Prüfen, dass der Projektordner aus WSL erreichbar ist (muss die Skripte und `patches-upstream/sl7-tree-full.diff` zeigen):

```bash
wsl -d Ubuntu -u root -- bash -c "ls '/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build' && ls '/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/patches-upstream'"
```

Internetzugang aus WSL prüfen (Kernel-Clone ~2 GB, MSI 524 MB):

```bash
wsl -d Ubuntu -u root -- bash -c "curl -sI https://github.com | head -1; curl -sI http://ports.ubuntu.com | head -1"
```

Feste Regeln:

- Skripte **nie** direkt aus dem Windows-Ordner starten lassen, die dort liegenden Kopien haben CRLF – die Skripte selbst entfernen CRLF (`sed 's/\r$//'`), wo es nötig ist.
- `LC_ALL=C` setzen alle Skripte selbst.
- Umgebungsvariablen aus PowerShell immer über `env` übergeben: `wsl -d Ubuntu -u root -- env PKGREV=4 bash "…"`.

---

## 2 Einmalige Einrichtung

**2.1** Cross-Toolchain, Kernel-Build-Abhängigkeiten, `msitools`, `device-tree-compiler`, `qemu-user` + `qemu-user-binfmt`, `debootstrap` installieren (Dauer: Minuten):

```bash
wsl -d Ubuntu -u root -- bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-setup-toolchain.sh"
```

Erwartet am Ende: `OK aarch64-linux-gnu-gcc …`, `OK msiextract …`, `OK dtc …`, `OK debootstrap …` und eine Zeile `qemu-aarch64` unter binfmt. Fehlt `qemu-aarch64`, ist nur der Chroot-Test (Abschnitt 5.2/5.3) betroffen.

**2.2** Kernel-Trees klonen (ELLX `7.0-sl7` → `/work/sl7/kernel/ellx-7.0-sl7`, Ubuntu-Concept `qcom-x1e-7.0` als Vergleichsbaum):

```bash
wsl -d Ubuntu -u root -- bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-clone-kernels.sh"
```

Erwartet: `dts: x1e80100-microsoft-romulus13.dts` (und `romulus15.dts`) für beide Bäume, Version `7.0.0-rc4`.

**2.3** Tags nachladen – `wsl-apply-sl7-patches.sh` und `wsl-build-kernel.sh` checken den Tag `7.0.0-rc4-12` aus, der Klon ist `--depth 1`:

```bash
wsl -d Ubuntu -u root -- bash -c "cd /work/sl7/kernel/ellx-7.0-sl7 && git fetch --tags --depth 1 origin && git tag -l && git log -1 --format='%h %cd %s' --date=short 7.0.0-rc4-12"
```

Erwartet: Tag `7.0.0-rc4-12`, Commit `0e9944fa4 2026-05-14 webcam dtb patch for Surface Laptop 7`.

**2.4** Community-dwc3-Patches an die Stelle kopieren, die `wsl-build-kernel.sh` in Schritt [2] erwartet (**Pflicht** – fehlt der Ordner, bricht der Build-Lauf wegen `set -e` ab):

```bash
wsl -d Ubuntu -u root -- bash -c "rm -rf /work/sl7/patches/community && mkdir -p /work/sl7/patches && cp -r '/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/gits/giantdwarf17_linux-surface-laptop-7/patches' /work/sl7/patches/community && ls /work/sl7/patches/community/outgoing/dwc3-usb"
```

Erwartet: `0001-dt-bindings-usb-dwc3-…`, `0002-usb-dwc3-add-reinit-phy-on-resume-quirk.patch`, `0003-arm64-dts-qcom-x1e80100-microsoft-romulus-add-phy-re.patch`.

**2.5** arm64-Multiarch einrichten (`libssl-dev:arm64` für das `linux-headers`-Paket). **`NOBUILD=1` mitgeben**, sonst startet das Skript am Ende sofort einen vollständigen Rev.-1-Build ohne den aktuellen Patch-Stand:

```bash
wsl -d Ubuntu -u root -- env NOBUILD=1 bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-setup-multiarch.sh"
```

Erwartet: `OK opensslconf.h (arm64)` und danach die Config-Ausgabe von `wsl-build-kernel.sh` mit `NOBUILD=1 -> Ende nach Konfiguration`.

**2.6** arm64-Chroot für die Tests anlegen (einmalig, ~10 min):

```bash
wsl -d Ubuntu -u root -- bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-arm64-chroot.sh"
```

Erwartet: `aarch64`, `arm64`, am Ende `=== fertig: /work/sl7/chroot-arm64`.

---

## 3 Kernel bauen (Patch-Stand + Paket-Revision)

**Patch-Stand Revision 3** (kanonisch `build/patches-upstream/sl7-tree-full.diff`, angewendet auf Tag `7.0.0-rc4-12`):

| Inhalt | Herkunft |
|---|---|
| dwc3 „reinit-phy-on-resume“ (Binding + `core.c`/`core.h` + DTS) | Community 0001–0003, Oliver White 02.06.2026 |
| `ASoC: qcom: x1e80100: limit speaker volumes` | Ubuntu SAUCE, LP #2149808, aus resolute `linux 7.0.0-38.38` (04.09.2026) |
| hamoa USB-QMP-PHY-Supplies (nur `romulus.dtsi`-Hunk) | upstream `4458dcd`, 03.08.2026 (nicht in 7.2) |
| Touchscreen Variante A: `i2c8 @0x34` `hid-over-i2c` | linux-input 07.09.2026 (fQwQf) – **experimentell** |
| Touchscreen Variante B: `spi10` QSPI `hid-over-spi` (gpio48/51/64) | linux-surface#1590 (horizontblau 25.08.2026) + orvitpng/nix1e – **experimentell** |
| Touchpad-Wedge-Fix (`vreg_ts_5p0` `regulator-boot-on`, gpio65 raus) | horizontblau 29.08.2026 / orvitpng |
| `&iris` mit `qcom/x1e80100/microsoft/Romulus/qcvss8380.mbn` | nix1e-Vorbild, Hardware-Video |
| CPU-Thermal: `#cooling-cells` cpu0..cpu11 + passive Trips 85 °C | scuggo/x1e-nixos `surface-laptop-7-thermal.dts` |

**3.1** Patch-Stand herstellen (frischer Checkout des Tags, alle lokalen Änderungen im Tree werden verworfen, `git apply` des Gesamt-Diffs, DTB-Testbau):

```bash
wsl -d Ubuntu -u root -- bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-apply-sl7-patches.sh"
```

Erwartet: `6 files changed`, danach `arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb` mit ca. **227.316 Bytes** und `OK - jetzt: PKGREV=<n> bash wsl-build-kernel.sh`.

**3.2** Kernel bauen und paketieren. `PKGREV` ist die Paket-Revision und bestimmt den Zielordner `build/out/7.0.0-rc4-sl7-<PKGREV>/` – für einen Neubau des aktuellen Stands `3`, für jeden geänderten Stand die nächsthöhere Zahl (Dauer: ca. 12 min Build + ca. 10 min Paketierung + Sekunden für das stubble-Image):

```bash
wsl -d Ubuntu -u root -- env PKGREV=3 bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-build-kernel.sh"
```

Erwartete Eckpunkte der Ausgabe:

- `[2/6]` → `dwc3 reinit-phy-on-resume: im DTS`, `rfkill-hack: im Tree`, `spi-hid: im Tree`
- `[3/6]` → `Optionen aus Annotations: 11983`, `Kernel-Release: 7.0.0-rc4-sl7`, `CONFIG_SPI_HID y`, `CONFIG_EFI_ZBOOT y`, `CONFIG_MODULE_SIG_FORCE (nicht gesetzt)`
- `[5/6]` → Pakete `linux-image-7.0.0-rc4-sl7_7.0.0~rc4-sl7-3_arm64.deb` (≈156 MB) und `linux-headers-…` (≈9,8 MB)
- `[7/7]` → `Anzahl .dtbauto-Sektionen: 32`, `FERTIG: …/vmlinuz-7.0.0-rc4-sl7.stubble` (21.112.320 Bytes)

Nützliche Umgebungsvariablen: `NOBUILD=1` (nur konfigurieren), `RECONFIG=1` (`.config` neu aus den Ubuntu-Annotations), `TAG=…` (anderer Tag).

**3.3** Ergebnisordner auf dem Windows-Laufwerk kontrollieren:

```bash
wsl -d Ubuntu -u root -- bash -c "ls -la '/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out/7.0.0-rc4-sl7-3'"
```

Erwartet: `linux-image-…deb`, `linux-headers-…deb`, `config-7.0.0-rc4-sl7`, `x1e80100-microsoft-romulus13.dtb`, `x1e80100-microsoft-romulus15.dtb`, `vmlinuz-7.0.0-rc4-sl7.stubble`, `SHA256SUMS`.

**3.4** Nur das stubble-Image neu bauen (wenn `wsl-build-kernel.sh` durchlief, aber Schritt [7] abbrach):

```bash
wsl -d Ubuntu -u root -- env PKGREV=3 bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-build-stubble.sh"
```

---

## 4 Firmware-Paket bauen

Quelle: Microsoft-Treiberpaket **`SurfaceLaptop7_ARM_Win11_26100_26.053.36539.0.msi`** (Download-Center id=106120), 523.874.304 Bytes, Last-Modified 25.06.2026, geprüft am 13.09.2026. Die im Community-Skript stehende alte URL (25.013.35106.0) ist 404.

**4.1** MSI laden, entpacken, Romulus-Blobs + gepatchte `ath12k`-`board-2.bin` einpacken (Dauer: Minuten, 524 MB Download):

```bash
wsl -d Ubuntu -u root -- env MSI_URL="https://download.microsoft.com/download/b7ca2c3f-d320-4795-be0f-529a0117abb4/SurfaceLaptop7_ARM_Win11_26100_26.053.36539.0.msi" bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-extract-firmware.sh"
```

Erwartet: keine `WARNUNG: … nicht im MSI gefunden`, `SL7-Eintrag hinzugefuegt` (bzw. „war schon vorhanden“, falls upstream gefixt) und am Ende `build/out/sl7-firmware-msi-26100_26.053.36539.0.tar.xz` (19.995.088 Bytes).

Liegt das MSI schon lokal, statt `MSI_URL` einfach `MSI_FILE=/pfad/zur.msi` setzen.

**4.2** Paketinhalt prüfen (29 Dateien: 14 Blobs doppelt abgelegt + `board-2.bin`):

```bash
wsl -d Ubuntu -u root -- bash -c "cd '/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out' && sha256sum -c sl7-firmware-msi-26100_26.053.36539.0.tar.xz.sha256 && wc -l sl7-firmware-msi-26100_26.053.36539.0.list.txt && grep -E 'qcdxkmsuc8380|qcadsp8380|qcvss8380.mbn|board-2.bin' sl7-firmware-msi-26100_26.053.36539.0.list.txt"
```

Erwartet: `OK`, `29`, und die Zeilen mit Zielpfad `lib/firmware/updates/qcom/x1e80100/microsoft/Romulus/…` bzw. `lib/firmware/updates/ath12k/WCN7850/hw2.0/board-2.bin`.
SHA256 des aktuellen Pakets: `8402f9467888887ef4876a2dc3934b692136c7b0f46e2cd24e333381b4de7252`.

Bluetooth-Firmware (`qca/hmtbtfw20.tlv`, `hmtnv20.bin`) ist **nicht** im Paket – die kommt auf dem Laptop aus Ubuntus `linux-firmware`.

---

## 5 Prüfen vor dem Kopieren

**5.1** Artefakte der Revision prüfen (Sektionen im stubble-Image, DTB-Inhalt, Paketinhalt, Prüfsummen):

```bash
wsl -d Ubuntu -u root -- env REV=3 bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-verify-out.sh"
```

Erwartete Ausgabe (Revision 3):

```
--- .dtbauto-Sektionen: 32
--- romulus13.dtb Groesse 227316 (0x…) im stubble-Image: 1
--- Strings iris/cooling im Image: <>0
--- DTB-Inhalt (aus dem .dtb): touchscreen@0=1 touchscreen@34=1 cooling-device=20 qcvss=1
--- Paket: romulus13.dtb im linux-image: 1  Version: 7.0.0~rc4-sl7-3
--- SHA256SUMS: … OK
```

Hinweis: Die dritte Zeile in `SHA256SUMS` zeigt auf den WSL-Pfad `/work/sl7/stubble/vmlinuz-7.0.0-rc4-sl7.stubble`; wurde `/work/sl7/stubble` aufgeräumt, meldet `sha256sum -c` dort „FAILED open or read“ – die beiden `.deb`-Zeilen müssen `OK` sein.

**5.2** Kernel-Paket im arm64-Chroot testinstallieren (postinst-Hooks, DTB-Pfade, Modulliste, initramfs):

```bash
wsl -d Ubuntu -u root -- bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-chroot-test-kernel.sh"
```

Erwartet: `dpkg -i` ohne Fehler, DTBs unter `/usr/lib/linux-image-7.0.0-rc4-sl7/qcom/`, `Module (Anzahl): ~7932`, und in der Modultabelle **kein** `FEHLT` bei `ath12k`, `spi-hid`, `msm`, `qcom_battmgr`, `ucsi_glink`, `snd-soc-x1e80100`, `snd-soc-wsa884x`, `ov02c10`, `qcom-camss`, `hid-multitouch`.

**5.3** dracut-Lauf im Chroot testen (Ubuntu 26.04 benutzt dracut, nicht `update-initramfs`):

```bash
wsl -d Ubuntu -u root -- env KVER=7.0.0-rc4-sl7 bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-chroot-test-dracut.sh"
```

Erwartet: `dracut … /boot/initrd.img-7.0.0-rc4-sl7` ohne Fehler und ein vorhandenes Initrd in der Auflistung.

**5.4** Sicherheits-/Config-Kontrolle (Speaker-Limit im Tree, SL7-Config-Optionen, Concept-Vergleich):

```bash
wsl -d Ubuntu -u root -- bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/inspect/wsl-check-safety.sh"
```

Erwartet: In `sound/soc/qcom/x1e80100.c` steht `snd_soc_limit_volume` (Speaker-Limit vorhanden); in der Optionentabelle sind `SPI_HID=m`, `ATH12K=m`, `DRM_MSM=m`, `BATTERY_QCOM_BATTMGR=m`, `VIDEO_OV02C10=m`, `SND_SOC_WSA884X=m` gesetzt; `SURFACE_FAN` ist erwartungsgemäß `-`.

---

## 6 USB-Stick vorbereiten

**Was auf den Stick muss**

| Quelle | Ziel auf dem Stick |
|---|---|
| `ubuntu-26.04.1-desktop-arm64.iso` (cdimage.ubuntu.com/releases/26.04/release/, Listing 26.08.2026) | Ventoy-Partition, Wurzel |
| optional `questing-desktop-arm64+x1e.iso` (liegt in `Downloads\` bzw. `S:\Surface fedora\`) als Zweit-ISO | Ventoy-Partition, Wurzel |
| **kompletter Ordner** `C:\Users\Martin\Desktop\Projekt Linux ARM\build\out\` | z. B. `\sl7\out\` (Struktur unverändert lassen) |

Der Installer `sl7-install-on-laptop.sh` sucht **neben sich**: `7.0.0-rc4-sl7-*/` (nimmt die höchste Revision), `sl7-firmware-msi-*.tar.xz`, `ellx-iptsd/`, `ellx-fixes/`, `sl7-mac_*_all.deb`. Ohne diese Struktur überspringt er Teile stillschweigend.

**6.1** Ventoy **1.1.17** (24.07.2026) von der Ventoy-Projektseite laden, `Ventoy2Disk` starten, Stick (≥ 16 GB) auswählen, Partitionsstil GPT, installieren. `dd`/Rufus bleibt reiner **Fallback** – auf dem SL7 sind mit direkt geflashten Sticks GRUB-Freezes und eine tote interne Tastatur belegt (dann externe USB-Tastatur bereitlegen).

**6.2** ISO **vor** dem Kopieren gegen `SHA256SUMS` von cdimage prüfen (ein korrupter Download hat im Community-Thread einen halben Tag gekostet):

```bash
wsl -d Ubuntu -u root -- sha256sum "/mnt/c/Users/Martin/Downloads/ubuntu-26.04.1-desktop-arm64.iso"
```

**6.3** ISO und Projekt-Artefakte auf den Stick kopieren (Laufwerksbuchstabe anpassen, hier `E:`):

```bash
xcopy "C:\Users\Martin\Downloads\ubuntu-26.04.1-desktop-arm64.iso" "E:\" /Y
xcopy "C:\Users\Martin\Desktop\Projekt Linux ARM\build\out" "E:\sl7\out" /E /I /Y
```

**6.4** ISO **nach** dem Kopieren auf dem Stick erneut prüfen (muss identisch zu 6.2 sein):

```bash
certutil -hashfile "E:\ubuntu-26.04.1-desktop-arm64.iso" SHA256
```

**6.5** Kernel-Prüfsummen auf dem Stick kontrollieren:

```bash
certutil -hashfile "E:\sl7\out\7.0.0-rc4-sl7-3\linux-image-7.0.0-rc4-sl7_7.0.0~rc4-sl7-3_arm64.deb" SHA256
```

Erwartet: `1bdee894f135328d00d241ea8d3bf22c62841715c5f3a342be69256d68018cf3`
(Headers: `55a072433ab3dc23c7af4292f791df606881cf627a0d6761e63455a611d10264`, Firmware-Tar: `8402f946…7252`).

**6.6** Zweiter Stick: Surface-Recovery-Image (Microsoft, per Seriennummer) – als letzte Rückfallebene bereitlegen.

---

## 7 Installation auf dem Laptop

### 7.1 Unter Windows vorbereiten (auf dem Surface)

Alle Surface-/Windows-Updates einspielen (Firmware- und EC-Updates gibt es später nur noch über Windows):

```bash
# Windows Update vollständig durchlaufen lassen, danach Neustart
```

Hardware-Dump sichern (PnP-IDs, ACPI, EDID, MACs, Partitionen, TPM/Secure-Boot):

```bash
powershell -ExecutionPolicy Bypass -File "C:\Users\Martin\Desktop\Projekt Linux ARM\hardware\SL7-Hardware-Dump.ps1"
```

BitLocker-Status prüfen und **vor** der Secure-Boot-Änderung aussetzen; Recovery-Key vorher sichern:

```bash
manage-bde -status C:
manage-bde -protectors -get C: -type RecoveryPassword
manage-bde -protectors -disable C: -RebootCount 2
```

`C:` verkleinern und 60–100 GB unpartitioniert lassen (Datenträgerverwaltung `diskmgmt.msc`, Rechtsklick auf `C:` → „Volume verkleinern“). Windows-Partition und Windows-Boot-Manager unangetastet lassen:

```bash
diskmgmt.msc
```

### 7.2 Surface-UEFI

Gerät ausschalten, **Lautstärke +** gedrückt halten und **Power** drücken, halten bis das Surface-Logo erscheint. Dort einstellen:

- Security → Secure Boot → **None** (unsere Kernel sind unsigniert; nicht „Microsoft only“)
- Boot configuration → USB-Boot erlauben und vor die SSD ordnen
- TPM/Pluton unverändert lassen (wird von Windows gebraucht)

### 7.3 Ubuntu installieren

1. Vom Ventoy-Stick starten, `ubuntu-26.04.1-desktop-arm64.iso` wählen und mit **Enter = Normalmodus** booten (**nicht** Strg+R/grub2-Modus – im Normalmodus lädt der ISO-eigene GRUB, der stubble/`.dtbauto` kennt).
2. Bei schwarzem Bildschirm: GRUB-Eintrag mit `e` editieren und `quiet splash` entfernen.
3. Im Live-System: Maus mitnehmen (Touchpad läuft ohne `spi-hid` nicht), Netzwerk per USB-Ethernet oder USB-Tethering (WLAN geht hier noch nicht, `board-2.bin` fehlt).
4. Installer: „Neben Windows installieren“, „Zusätzliche Treiber installieren“ anhaken, `ext4` (oder btrfs) für `/`, **keine** TPM-gebundene Verschlüsselung.
5. Neu starten in das installierte Ubuntu (generischer Ubuntu-Kernel, GPU zunächst llvmpipe – normal).

### 7.4 Eigenen Kernel + Firmware installieren

Stick einhängen und den kompletten `out`-Ordner auf die interne Platte kopieren (schneller und unabhängig vom Stick):

```bash
mkdir -p ~/sl7 && cp -r /media/$USER/*/sl7/out ~/sl7/ && ls ~/sl7/out
```

Erst den Probelauf (zeigt nur, was passieren würde, ändert nichts), dann die echte Installation (idempotent, ändert den Windows-Bootloader nicht; nimmt automatisch die höchste Revision neben sich):

```bash
cd ~/sl7/out && sudo DRYRUN=1 bash sl7-install-on-laptop.sh
```

```bash
cd ~/sl7/out && sudo bash sl7-install-on-laptop.sh
```

Das Skript macht: Kernel-Pakete `dpkg -i` → stubble-Image nach `/boot/vmlinuz-7.0.0-rc4-sl7` (Original als `.plain`) + `/boot/sl7-romulus13.dtb` → Firmware-Tar nach `/` → GNOME-Überverstärkung aus → `/etc/default/grub.d/90-sl7.cfg` (`clk_ignore_unused pd_ignore_unused`, Menü, Timeout 5) + `/etc/grub.d/42_sl7_fallback` → `dracut --force` → `update-grub` → iptsd + Kalibrierung + `iptsd@.service` + `50-iptsd.rules` → `sl7-mac` + Sleep-Hooks.

Optional für einen ersten Testboot **ganz ohne Ton** (sperrt das Verstärker-Modul hart – damit ist die **gesamte** Soundkarte tot, auch Kopfhörer und Mikrofone):

```bash
cd ~/sl7/out && sudo SL7_NO_SPEAKER=1 bash sl7-install-on-laptop.sh
```

Neu starten und im GRUB-Menü den neuen Kernel (Standardeintrag) wählen:

```bash
sudo reboot
```

Bootet das stubble-Image nicht: im GRUB-Menü den Eintrag **„SL7 Fallback: 7.0.0-rc4-sl7 (plain + devicetree)“** nehmen. Bootet auch der nicht: „Advanced options“ → Ubuntu-generic-Kernel.

---

## 8 Kontrolle nach dem ersten Boot

Alle Befehle auf dem Laptop. Die Erwartungswerte stammen aus Cross-Build, DTB-Analyse und Community-Berichten – **auf dem Gerät noch nicht gemessen (unverifiziert)**.

**8.1 Kernel** – läuft der eigene Kernel?

```bash
uname -r ; uname -m ; cat /proc/cmdline
```

Erwartet: `7.0.0-rc4-sl7`, `aarch64`, Cmdline enthält `clk_ignore_unused pd_ignore_unused` (und `root=UUID=…`).

**8.2 DTB-Auswahl** – hat der stubble-Stub den richtigen Device Tree gewählt?

```bash
cat /proc/device-tree/model ; tr '\0' '\n' < /proc/device-tree/compatible ; stat -c '%n %s' /boot/vmlinuz-7.0.0-rc4-sl7
```

Erwartet: `Microsoft Surface Laptop 7 (13.8 inch)`, `microsoft,romulus13` + `qcom,x1e80100`, Image-Größe `21112320` (= stubble-Variante; `156…`-Byte-Größe wäre das plain-Image).

Gegenprobe, dass GRUB **keinen** DTB übergibt (nur der Fallback-Eintrag darf eine `devicetree`-Zeile haben):

```bash
grep -n "devicetree" /boot/grub/grub.cfg
```

Erwartet: genau eine Trefferzeile, innerhalb von `menuentry 'SL7 Fallback…'`.

**8.3 WLAN** – ath12k mit gepatchter `board-2.bin`, kein Hard-Block:

```bash
dmesg | grep -i ath12k | head -20 ; rfkill list ; ip -br link ; nmcli dev
```

Erwartet: `ath12k_pci … chip_id 0x2 … board_id`, **kein** `failed to fetch board data for … subsystem-device=1107`, `Hard blocked: no`, ein `wlan0`/`wlp…`-Interface.

MAC-Adressen aus der UEFI-Variable setzen (der Installer ruft das bereits auf):

```bash
sudo sl7-mac all ; ip link show | grep -A1 wl
```

Erwartet: eine feste MAC (nicht bei jedem Boot neu); Fehlermeldung „UEFI-Variable nicht lesbar“ nur, wenn `efivarfs` fehlt.

**8.4 Bluetooth** – `hci_qca` mit Firmware aus `linux-firmware`:

```bash
dmesg | grep -iE 'qca|bluetooth' | head -20 ; bluetoothctl show
```

Erwartet: geladene `qca/hmtbtfw20.tlv` + `hmtnv20.bin`, ein Controller mit fester Adresse und `Powered: yes`.

**8.5 GPU** – freedreno/Turnip statt llvmpipe (hängt am Zap-Shader-Pfad):

```bash
dmesg | grep -iE 'msm|adreno|zap' | head -20 ; glxinfo -B | grep -iE 'renderer|OpenGL version' ; vulkaninfo --summary | grep -iE 'driverName|apiVersion'
```

Erwartet: `Adreno … 741`, Renderer `freedreno`/`Turnip`, **nicht** `llvmpipe`, keine Meldung `could not get GPU ID`.

**8.6 Audio** – Karte bindet, Volume-Limit greift. **Erst mit ≤ 30 % Lautstärke testen:**

```bash
cat /proc/asound/cards ; aplay -l ; lsmod | grep -E 'wsa884x|wcd93|x1e80100' ; dmesg | grep -iE 'wsa884x|sndcard|EPROBE' | head -20
```

Erwartet: Karte `X1E80100-Romulus`, Wiedergabegeräte vorhanden, keine dauerhaften `EPROBE_DEFER`-Meldungen.

Kernel-Volume-Limit kontrollieren (das ist der Lautsprecherschutz):

```bash
amixer -c0 contents | grep -B2 -A6 -i 'PA Volume' | head -40
```

Erwartet: bei den `Spkr/Woofer/Tweeter PA Volume`-Reglern `max=6` bzw. `platform_max=6`; Digital Volume gedeckelt auf `81`.

UCM-Profil prüfen (DMI-Regex muss den Romulus treffen):

```bash
cat /sys/devices/virtual/dmi/id/board_vendor /sys/devices/virtual/dmi/id/product_family /sys/devices/virtual/dmi/id/board_name ; alsaucm -c X1E80100-Romulus list _verbs
```

Erwartet: `alsaucm` listet Verben (`HiFi` o. ä.). Kommt „card not found“/leere Liste, greift das UCM nicht – dann Kopfhörer/DMICs per `alsamixer` prüfen und den tj90241-UCM-Patch nachziehen. Mikrofon: `arecord -l` und eine kurze Testaufnahme.

**8.7 Touchpad** – `spi-hid` + iptsd:

```bash
dmesg | grep -iE 'spi.hid|spi_hid|88c000.spi' | head -20 ; ls /sys/bus/spi/devices ; systemctl status 'iptsd@*' --no-pager | head -20 ; libinput list-devices | grep -iA4 -E 'touchpad|Touch'
```

Erwartet: ein `spi-hid`-Gerät auf `spi19`, ein laufender `iptsd@…`-Dienst, ein Touchpad in `libinput`. Ohne Kalibrierung fühlt sich das Pad schlecht an:

```bash
iptsd-find-hidraw ; sudo iptsd-calibrate /dev/hidrawN
```

**8.8 Touchscreen** (experimentell, beide DT-Varianten sind im DTB – hier zeigt sich, welche enumeriert):

```bash
dmesg | grep -iE 'hid-over-i2c|i2c_hid|hid_over_spi|touchscreen|GTCH' | head -20 ; ls /sys/bus/i2c/devices ; libinput list-devices | grep -iB2 -A6 'Touchscreen'
```

Erwartet (Hoffnungswert): ein HID-Gerät über `spi10` (Variante B). Die `i2c8`-Variante ist die unwahrscheinlichere. Kommt gar nichts, ist das der dokumentierte offene Punkt – kein Fehler der Installation.

**8.9 Akku / Laden** – `qcom_battmgr` über pmic-glink (braucht ADSP-Firmware):

```bash
dmesg | grep -iE 'battmgr|pmic_glink|adsp|cdsp' | head -20 ; upower -i $(upower -e | grep BAT) ; cat /sys/class/power_supply/*/status
```

Erwartet: ADSP/CDSP geladen (`qcadsp8380.mbn`, `qccdsp8380.mbn`), Ladestand, `Charging`/`Discharging`; **kein** `EAGAIN` im battmgr-Pfad.

**8.10 cpufreq** – SCMI-Treiber über CPUCP-Mailbox:

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver ; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ; cat /sys/devices/system/cpu/cpufreq/boost
```

Erwartet: `scmi`, `schedutil`, eine plausible Frequenz, `boost` = `1`. Steht dort `(kein Treiber)` bzw. fehlt das Verzeichnis, ist `qcom-cpucp-mbox` (Modul) nicht geladen → `lsmod | grep cpucp`.

**8.11 Thermik** – Sensoren und die eingebauten Drossel-Trips (85 °C passive, aus Revision 3):

```bash
for z in /sys/class/thermal/thermal_zone*; do echo "$z $(cat $z/type) $(cat $z/temp)"; done | head -30
ls /sys/class/thermal/ | grep -c cooling_device
cat /sys/class/thermal/thermal_zone0/trip_point_*_temp
```

Erwartet: `qcom_tsens`-Zonen (`cpu0-0-top` …) mit Temperaturen in Milligrad, Cooling-Devices vorhanden, Trip-Punkte bei `85000` (passive) und `115000` (critical). Lüftersteuerung liegt beim EC (`SURFACE_FAN` ist bewusst nicht gebaut).

**8.12 Kamera** – OV02C10 über CAMSS:

```bash
dmesg | grep -iE 'ov02c10|camss|csiphy' | head -20 ; ls /dev/video* ; v4l2-ctl --list-devices ; cam -l 2>/dev/null | head
```

Erwartet: Sensor-Probe ohne Fehler, `/dev/video*`-Knoten, `qcom-camss` in der Geräteliste. Bildqualität (Grünstich) braucht zusätzlich das libcamera-Tuning aus dem Community-Repo.

**8.13 Hardware-Video** (iris, Revision 3 neu):

```bash
dmesg | grep -iE 'iris|venus' | head ; v4l2-ctl --list-devices | grep -iA2 iris
```

Erwartet: `iris` bindet mit `qcom/x1e80100/microsoft/Romulus/qcvss8380.mbn`. Bindet stattdessen `venus` oder nichts, ist das kein Beinbruch (CPU-Decode bleibt).

**8.14 Suspend/Resume** – nach dem Test Display, Touchpad und USB-A prüfen:

```bash
cat /sys/power/mem_sleep ; cat /sys/power/state ; sudo systemctl suspend
```

Erwartet: `s2idle [deep]`, kein `disk` (kein Hibernate). Aufwecken mit der **Power-Taste**. Danach Bild (Hook `display-fix`), Touchpad (Hook `trackpad`) und ein USB-A-Gerät kontrollieren.

**8.15 Sammelprotokoll** für die Fehlersuche:

```bash
( uname -a; cat /proc/device-tree/model; dmesg ) > ~/sl7-erstboot.log ; grep -icE 'error|fail' ~/sl7-erstboot.log
```

---

## 9 Neu bauen nach Patch-Änderungen

**9.1** Änderung direkt im Tree machen (Zweig `sl7-build`), z. B. am Device Tree:

```bash
wsl -d Ubuntu -u root -- bash -c "cd /work/sl7/kernel/ellx-7.0-sl7 && git status --short && git diff --stat"
```

**9.2** Nur den DTB schnell gegentesten (kein volles Kernel-Paket nötig):

```bash
wsl -d Ubuntu -u root -- bash -c "cd /work/sl7/kernel/ellx-7.0-sl7 && make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/x1e80100-microsoft-romulus13.dtb && dtc -I dtb -O dts arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dtb 2>/dev/null | grep -c cooling-device"
```

**9.3** Kanonischen Gesamt-Diff aus dem Tree neu schreiben – immer gegen den **Tag** `7.0.0-rc4-12` (nicht gegen HEAD, sonst ist der Diff leer, sobald etwas commitet wurde) und ohne die Ubuntu-Packaging-Verzeichnisse, die `bindeb-pkg` verändert:

```bash
wsl -d Ubuntu -u root -- bash -c "cd /work/sl7/kernel/ellx-7.0-sl7 && git diff 7.0.0-rc4-12 -- . ':!debian' ':!debian.master' ':!debian.qcom-x1e' > '/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/patches-upstream/sl7-tree-full.diff' && wc -l '/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/patches-upstream/sl7-tree-full.diff'"
```

**9.4** Gegenprobe: Patch-Stand aus dem neuen Diff frisch herstellen (verwirft den Arbeitsstand, beweist Reproduzierbarkeit):

```bash
wsl -d Ubuntu -u root -- bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-apply-sl7-patches.sh"
```

**9.5** Neue Revision bauen (Zahl immer hochzählen, sonst überschreibt der Build den alten Ordner):

```bash
wsl -d Ubuntu -u root -- env PKGREV=4 bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-build-kernel.sh"
```

Bei reinen Config-Änderungen zusätzlich `RECONFIG=1` mitgeben; `.config` bleibt sonst erhalten und der Build ist inkrementell (Minuten statt 12 min).

**9.6** Neue Revision prüfen und auf den Stick legen:

```bash
wsl -d Ubuntu -u root -- env REV=4 bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-verify-out.sh"
```

```bash
xcopy "C:\Users\Martin\Desktop\Projekt Linux ARM\build\out\7.0.0-rc4-sl7-4" "E:\sl7\out\7.0.0-rc4-sl7-4" /E /I /Y
```

**9.7** Auf dem Laptop erneut installieren (nimmt automatisch die höchste Revision im Ordner):

```bash
cd ~/sl7/out && sudo bash sl7-install-on-laptop.sh && sudo reboot
```

Zurückrollen: im GRUB-Menü unter „Advanced options“ die alte Revision wählen bzw.

```bash
sudo dpkg -i ~/sl7/out/7.0.0-rc4-sl7-3/linux-image-*.deb && sudo update-grub
```

---

## 10 Späterer Wechsel auf die 7.2-Concept-Basis

Ziel: `linux-qcom-x1e 7.2.0-18.18` aus dem PPA `~ubuntu-concept/x1e` (resolute, 09.09.2026) als neue Basis. Der Branch `qcom-x1e-7.2` existiert **nicht** (404) – die Quelle kommt als Quellpaket aus der PPA. Vorher muss geprüft werden, was dort schon drin ist und was nachgezogen werden muss.

**10.1** Paketliste der PPA und exakten `.dsc`-Namen holen:

```bash
wsl -d Ubuntu -u root -- bash -c "apt-get install -y -qq ubuntu-dev-tools devscripts >/dev/null; pull-ppa-source --help >/dev/null 2>&1 && echo 'pull-ppa-source vorhanden'; curl -s 'https://launchpad.net/~ubuntu-concept/+archive/ubuntu/x1e/+packages' | grep -o 'linux-qcom-x1e[^<\"]*' | sort -u | head"
```

Der genaue Dateiname des `.dsc` ist **(unverifiziert)** – aus der Ausgabe übernehmen.

**10.2** Quellpaket entpacken (Beispiel-URL, Dateinamen aus 10.1 einsetzen):

```bash
wsl -d Ubuntu -u root -- bash -c "mkdir -p /work/sl7/kernel/concept-7.2 && cd /work/sl7/kernel/concept-7.2 && dget -x https://launchpad.net/~ubuntu-concept/+archive/ubuntu/x1e/+files/linux-qcom-x1e_7.2.0-18.18.dsc && ls -d */"
```

**10.3** Im neuen Baum prüfen, welche der eigenen Patches dort schon enthalten sind:

```bash
wsl -d Ubuntu -u root -- bash -c "cd /work/sl7/kernel/concept-7.2/linux-qcom-x1e-7.2.0 && echo '--- Speaker-Limit:'; grep -c snd_soc_limit_volume sound/soc/qcom/x1e80100.c; echo '--- hamoa USB-PHY (romulus):'; grep -n -A3 'usb_1_ss0_qmpphy' arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus.dtsi | grep -c 'vdda-phy-supply'; echo '--- spi-hid:'; ls drivers/hid/spi-hid 2>/dev/null | wc -l; echo '--- rfkill-Hack:'; grep -c 'Surface Laptop 7' drivers/net/wireless/ath/ath12k/core.c; echo '--- OV02C10-DT:'; grep -c ov02c10 arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus.dtsi; echo '--- dwc3 needs_full_reinit:'; grep -c needs_full_reinit drivers/usb/dwc3/core.c"
```

Erwartung laut Recherche: Speaker-Limit **wahrscheinlich vorhanden** (Ubuntu ab 7.2.0-5.5, 18.08.2026 – dort aber ungeprüft), hamoa-USB-PHY-Fix **nicht** vorhanden (erst v7.3-rc1), `spi-hid`/rfkill-Hack/Kamera-DT/QSPI-Hacks **nicht** vorhanden, dwc3 ab 7.1 mit upstream-Mechanismus `needs_full_reinit` statt des Community-Quirks.

**10.4** Nachzuziehende Teile (Reihenfolge für den Rebase):

1. `drivers/hid/spi-hid` – statt des 2022er Luz-Patches die aktuelle Upstream-Serie (spi-hid v4, Jingyuan Liang) bzw. die Chromium-Serie aus orvitpng/nix1e inkl. `fullduplex.patch`
2. QSPI: `spi-geni-qcom.c` + `dma/qcom/gpi.c` (Patches aus scuggo/x1e-nixos)
3. ath12k „Surface Laptop 7 Enumeration hack“ (`core.c`)
4. Kamera: OV02C10-DT + `ov02c10.c`-Anpassung
5. `hamoa-usb-qmp-phy-supplies-romulus-only.patch` (falls `4458dcd` nicht im Baum)
6. `ubuntu-speaker-limit.patch` (nur falls 10.3 `0` meldet)
7. Aus `sl7-tree-full.diff` die DT-Teile: Touchscreen `spi10`/`i2c8`, Touchpad-Wedge-Fix, `&iris`, CPU-Thermal-Trips
8. dwc3: prüfen, ob `needs_full_reinit` den Community-Quirk ersetzt – dann Patch 0001–0003 **weglassen**

**10.5** Skripte auf den neuen Baum umstellen – diese Stellen sind hart verdrahtet:

```bash
wsl -d Ubuntu -u root -- bash -c "grep -rn 'ellx-7.0-sl7\|7.0.0-rc4-sl7\|TAG:-7.0.0-rc4-12' '/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build'/*.sh '/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out/sl7-install-on-laptop.sh'"
```

Anzupassen: `K=` in `wsl-apply-sl7-patches.sh`, `wsl-build-kernel.sh`, `wsl-build-stubble.sh`, `inspect/wsl-check-safety.sh`; `TAG`/`LOCALVERSION`; die Pfadmuster `7.0.0-rc4-sl7-*` in `wsl-verify-out.sh` und in `sl7-install-on-laptop.sh` (dort `KDIR`, `KVER`, der Fallback-Menüeintrag und der Name des stubble-Images).

**10.6** Bauen, prüfen, installieren – danach gilt wieder Abschnitt 3.2, 5 und 7.4 mit dem neuen `KVER` (z. B. `7.2.0-sl7`):

```bash
wsl -d Ubuntu -u root -- env PKGREV=1 bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-build-kernel.sh"
```

**10.7** Rückweg offen halten: Die Revision `7.0.0-rc4-sl7-3` bleibt in `build/out/` und auf dem Laptop installiert; bei Problemen im GRUB-Menü unter „Advanced options“ zurückwählen.

---

### Quellen zu den Fixpunkten dieses Rezepts

- Microsoft-Treiberpaket: https://download.microsoft.com/download/b7ca2c3f-d320-4795-be0f-529a0117abb4/SurfaceLaptop7_ARM_Win11_26100_26.053.36539.0.msi (HTTP 200, 523.874.304 Bytes, Last-Modified 25.06.2026; geprüft 13.09.2026)
- ath12k board-2.bin: https://git.codelinaro.org/clo/ath-firmware/ath12k-firmware/-/raw/main/WCN7850/hw2.0/board-2.bin (abgerufen 13.09.2026)
- ath12k-bdencoder: https://raw.githubusercontent.com/qca/qca-swiss-army-knife/master/tools/scripts/ath12k/ath12k-bdencoder (abgerufen 13.09.2026)
- Kernel-Basis: https://github.com/ProgrammerIn-wonderland/ELLX-Kernel Tag `7.0.0-rc4-12` (Commit 0e9944fa4, 14.05.2026)
- Concept-Basis 7.2: https://launchpad.net/~ubuntu-concept/+archive/ubuntu/x1e/+packages (`linux-qcom-x1e 7.2.0-18.18`, 09.09.2026; abgerufen 13.09.2026)
- Ubuntu-ISO: https://cdimage.ubuntu.com/releases/26.04/release/ (Listing 26.08.2026)
- Speaker-Limit: https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2149808 (Meldung 21.04.2026; Fix in `linux 7.0.0-15.15`, Changelog 22.04.2026, ausgeliefert seit 29.04.2026; in `linux 7.2.0-5.5` seit 18.08.2026)
- hamoa-USB-PHY-Fix: upstream `4458dcd` „arm64: dts: qcom: hamoa: Fix swapped USB QMP PHY vdda-phy/vdda-pll supplies“ (03.08.2026, in v7.3-rc1)
- Touchscreen/Touchpad-DT, Ventoy-Fehlalarm, Suspend-Verhalten: https://github.com/linux-surface/linux-surface/issues/1590 (Stand 12.09.2026)
