# Fedora KDE Live für den Surface Laptop 7 – Aufbau, Bau, Nutzung

Stand: 22.09.2026. Ziel: ein **bootfähiges, installierbares Fedora-KDE-Live-ISO (aarch64)** für den
Surface Laptop 7 13,8" (X1E80100, Romulus13), bei dem WLAN, Bluetooth, Tastatur, das haptische
Trackpad (Kraft-Klick), Maus, Display, Akku und Suspend mit eigenem Kernel funktionieren – und das
sich mit Anaconda ganz normal installieren lässt, ohne dass danach etwas nachinstalliert werden muss.

## 1. Was drin ist

| Baustein | Quelle | Stand |
|---|---|---|
| Basis | Fedora-KDE-Desktop-Live-44-1.7.aarch64.iso (kiwi, EROFS-Rootfs, dracut-Live-initrd) | GA, alle Pakete per `dnf upgrade` auf Stand 22.09.2026 (Kernel ausgenommen) |
| **Kernel B** `7.3.0-rc3-sl7b` | Ubuntu 26.10 `linux-source-7.3.0-5.5` (generic-Config aus `linux-buildinfo`) + ItsLucas-Patches r15.1: 0001 ath12k-rfkill (Romulus13), 0002 QSPI-Touchpad (spi-geni QSPI + spi-hid), 0003 GTCH-SPI-Touchscreen, 0004 spi-hid Power-Lifecycle, 0005 GPIO-Panel-Power, 0006 QRTR-HELLO-Revert; Ubuntu-Speaker-Limit ist in 7.3 schon enthalten | Standard-Kernel |
| **Kernel A** `7.0.0-rc4-sl7` | ELLX-Kernel Tag 7.0.0-rc4-12 (Ubuntu qcom-x1e-Config) + konservative Patches (dwc3 reinit-phy-on-resume, Speaker-Limit, hamoa-QMP-Supplies) | Rückfall |
| DTB-Auswahl | wie Fedora 44: `vmlinuz-dtbloader.efi` = stubble-Stub + `.dtbauto` (romulus13 + romulus15) + HWIDs → der Bootstub wählt den DTB per SMBIOS-HWID | beide Kernel |
| DTB-Varianten | A: `-exp` (spi10-SPI-Touchscreen nach horizontblau, iris, Thermal-Trips), `-i2cts` (I²C-Touchscreen nach fQwQf); B: `-i2cts` | nur über Menüeinträge mit `devicetree` |
| iptsd | Fork **alex-lentz/iptsd** @3663e96 (haptischer Klick: Frame 0x94 → BTN_LEFT, Entprellung, Sleep-Hook), als RPM `iptsd-3-0.sl7.git3663e96` im Fedora-Chroot mit Fedoras Toolchain gebaut (keine BTI/PAC-Mischung → kein SIGILL) | |
| Firmware | Microsoft-MSI 26.053.36539.0 (ADSP/CDSP/GPU/Video-Blobs, `updates/qcom/x1e80100/microsoft/{,Romulus/}`) + gepatchte `ath12k/WCN7850/hw2.0/board-2.bin` (Subsystem-ID 1107) unter `/usr/lib/firmware/updates` | |
| sl7-mac 1.0.2 | valeronm: Fabrik-MAC für WLAN/BT aus der UEFI-Variable `MacAddressEmulationAddress` (sonst zufällige WLAN-MAC, BT „unconfigured") | aktiviert |
| Sleep-Hooks | `sl7-display-fix` (VT-Wechsel nach Resume), `sl7-trackpad-rebind` (spi_hid neu binden) | |
| Konfiguration | `/etc/dracut.conf.d/90-sl7.conf` (spi-hid/i2c-hid/ADSP-Treiber + DSP-Firmware in jede initramfs), `/etc/modules-load.d/sl7-scmi-cpufreq.conf`, `/etc/anaconda/conf.d/90-sl7.conf` (X1E-Kernelparameter werden übernommen), `sl7-postinstall.service` (erster Start nach Installation: ADSP-Denylist entfernen, Parameter setzen, initramfs neu), `/etc/iptsd.d/*`, `/etc/sl7-release`, `SL7-Hinweise.txt` auf dem Desktop | |

## 2. Boot-Menü des ISO (GRUB)

Alle „SL7"-Einträge setzen `clk_ignore_unused pd_ignore_unused systemd.tpm2_wait=0` (Fedora-Wiki für X1E).

* **Kernel B – Standard, USB-C-sicher**: zusätzlich `modprobe.blacklist=qcom_q6v5_pas`. Ohne ADSP kein Ton
  im Live-System, aber der Stick fliegt beim ADSP-Neustart (TCPM-Reset) nicht raus.
* **Kernel B – mit ADSP/Audio**: für USB-A-Stick oder nach der Installation.
* **Kernel A** (beide Varianten) – Rückfall mit dem älteren, konservativen Tree.
* **Touchscreen-Varianten**: explizite `devicetree`-Einträge (I²C-Variante für B und A, exp/Standard für A).
* **Diagnose**: ohne `quiet rhgb`, `loglevel=7 systemd.show_status=1 console=tty0 rd.timeout=180`; „extrem" mit
  `initcall_debug rd.shell rd.debug`; Varianten mit `arm64.nopauth`, ohne `clk/pd_ignore_unused`, 64-GB-`cutmem`,
  `nomodeset`; **Fedora-Original** (Stock-Kernel 6.19.10, unverändert) und „Medium prüfen".

Bei einer Boot-Schleife: nächsten Eintrag probieren, Reihenfolge Kernel B → Kernel A → arm64.nopauth →
ohne clk/pd_ignore_unused → Fedora-Original. Das Live-System schreibt nichts auf die SSD.

## 3. Installation

1. Live-System starten (Kernel B), Installer „Auf Festplatte installieren" (Anaconda).
2. Anaconda kopiert das Live-Rootfs, ruft für **jeden** Kernel unter `/boot/vmlinuz-*` `kernel-install add` auf
   (mit `vmlinuz-dtbloader.efi`, genau wie beim Fedora-Kernel), baut host-only-initramfs (unsere dracut-Konfiguration
   liefert spi-hid + DSP-Firmware mit) und schreibt BLS-Einträge. Standard-Eintrag = höchste Version = Kernel B.
3. Erster Start: `sl7-postinstall.service` entfernt die von Anaconda übernommene ADSP-Denylist, setzt die
   X1E-Kernelparameter in allen Einträgen (`grubby`), baut die initramfs neu. Protokoll `/var/lib/sl7/postinstall.log`.
4. Secure Boot bleibt aus (unsignierte Kernel).

## 4. Bau (auf dem PC, WSL2 Ubuntu 26.04, Skripte in `build/fedora/`)

| Schritt | Skript | Dauer |
|---|---|---|
| Werkzeuge | `wsl-setup-fedora-tools.sh` (qemu, xorriso, squashfs-tools, rpm/dnf, erofs-utils, ukify, attr, policycoreutils) | einmalig |
| ISO analysieren, Rootfs kopieren | `wsl-fedora-iso-analyse.sh`, `wsl-fedora-rootfs-copy.sh` (erofsfuse + `cp -a`, xattrs bleiben erhalten) | 5 min |
| Kernel A (RPM) | `wsl-tree-safe-exp.sh` → `wsl-build-kernel-fedora.sh` (+ `wsl-dtb-i2cts-a.sh`) | 15 min |
| Kernel B (RPM) | `wsl-fetch-itslucas.sh` → `wsl-prepare-kernel-73.sh` → `wsl-fix-kernel-73.sh` → `wsl-build-kernel-73-fedora.sh` (+ `wsl-dtb-i2cts-b.sh`) | 15 min |
| Phase 1 | `wsl-fedora-rootfs-phase1.sh`: Chroot (qemu-user), `dnf upgrade --exclude=kernel*`, iptsd-RPM (`iptsd-sl7.spec`) bauen/installieren, Build-Werkzeuge entfernen | 60–90 min |
| Phase 2 | `wsl-fedora-rootfs-phase2.sh`: Kernel-RPMs, DTB-Varianten, dtbloader-Images (ukify), Firmware, sl7-mac, Hooks, Konfiguration, Live-initrds (`dracut --no-hostonly` mit den kiwi-Argumenten), SELinux-Relabel (`setfiles -r`), Aufräumen | 30–60 min |
| Phase 3 | `wsl-fedora-build-iso.sh`: `mksquashfs` (zstd, xattrs), Boot-Dateien, `grub-sl7.cfg`, `xorriso -boot_image any replay` aus dem Original-ISO, SHA256 | 10 min |
| Phase 4 | `wsl-fedora-qemu-test.sh`: UEFI/GRUB-Boot des ISO (Standardeintrag) und Direktboot Kernel A in `qemu-system-aarch64 -M virt` | 15 min |
| Stick | `Fedora-Stick-schreiben.ps1` (Windows, roh/dd, optional Rücklesen) | 5 min |

Alle Ergebnisse (RPMs, DTBs, ISO, Prüfsummen, Logs) liegen unter `build/fedora/out/`.

## 4a. Ergebnisse der Recherche-Synthese (`docs/Fedora-Plan.md`), die eingeflossen sind

* **`.osrel`-Fehler:** ukify bettet ohne `--os-release=""` das os-release des Ubuntu-Hosts ein; mit `.linux`+`.osrel`
  stuft `kernel-install` das Image als **UKI** ein (Layout `uki`, kein BLS-Typ-1-Eintrag, keine initramfs) → das
  installierte System hätte mit unseren Kerneln nicht gebootet. Behoben (`wsl-fix-dtbloader.sh`): Sektionen jetzt wie
  bei Fedoras `kernel-uki-dtbloader` (`.linux .dtbauto×2 .hwids .uname .sbat`, **kein** `.osrel/.cmdline/.initrd`),
  `kernel-install inspect` im Chroot meldet für alle drei Kernel „Kernel Image Type: pe“.
* **GRUB-Tastatur:** Launchpad #2084951 – auf dem SL7 reagiert die Tastatur im GRUB nur mit `gfxterm`. `grub-sl7.cfg`
  lädt `unicode.pf2` und setzt `terminal_output gfxterm console` (Fallback `console`).
* **Panic-Protokolle ohne Platte:** `efi_pstore` in `add_drivers` (beide Kernel: `EFI_VARS_PSTORE=m`, `PSTORE=y`) →
  nach einem Absturz `ls /sys/fs/pstore/` (wenn die Firmware Variablen-Schreibzugriffe erlaubt).
* **dnf-Schutz:** `/etc/dnf/dnf.conf` schließt Fedoras Kernelpakete aus, damit `95-set-boot-entry` nach einem Update
  nicht den Stock-Kernel (kein spi-hid/Klick) zum Standard macht. Aufheben: `exclude=`-Zeile entfernen.
* „Diagnose extrem“ zusätzlich mit `panic=0 boot_delay=20`; `implantisomd5` nach dem ISO-Bau (Eintrag „Medium prüfen“).
* Offen geblieben (bewusst): Anaconda-Installation in QEMU auf virtuelle NVMe (aufwendig), udev-Regel zum Ausblenden
  des rohen spi-hid-Touchpads gegenüber libinput (Pfad `platform-88c000.spi-cs-0` unverifiziert – erst am Gerät prüfen).

## 4b. Test des Installationspfads (Overlay-Chroot, `wsl-test-kernel-install.sh`, 22.09.2026)

Nachgestellt wurde, was Anacondas `create_bls_entries` im Zielsystem tut: `kernel-install add <ver> /lib/modules/<ver>/vmlinuz-dtbloader.efi`
für 6.19.10 (Fedora), 7.0.0-rc4-sl7 (A) und 7.3.0-rc3-sl7b (B), danach unser `sl7-postinstall.sh`. Ergebnis:

* Plugins 10-devicetree, 20-grub, 50-depmod, 50-dracut, 51-dracut-rescue, 90/95/99 liefen für alle drei Kernel durch (exit 0).
* `/boot/vmlinuz-<ver>` ist byteidentisch mit dem dtbloader-Image; BLS-Typ-1-Einträge mit `linux`/`initrd`/`options` wurden erzeugt.
* Host-only-initramfs (Kernel B, 60 MB) enthält spi-hid, `qcadsp8380.mbn`, `board-2.bin` (updates/), `efi-pstore` – unsere `90-sl7.conf` greift.
* `sl7-postinstall.sh`: Denylist `qcom_q6v5_pas` entfernt, `grubby` setzt `clk_ignore_unused pd_ignore_unused systemd.tpm2_wait=0`
  in allen Einträgen, initramfs neu gebaut; `grubby --info=ALL` zeigt Kernel B als Index 0 (Standard bei leerem `saved_entry`).
* Meldungen `grub2-probe … overlay` / `/efi` stammen vom Overlay-Testaufbau, nicht vom Zielsystem.

## 5. Kontrollen, die eingebaut sind

* Firmware-Referenzen jeder DTB (`firmware-name`) gegen die Dateien unter `updates/` geprüft.
* dtbloader-Images: genau 2 `.dtbauto`-Sektionen + `.hwids`, sonst Abbruch.
* initrds: enthalten spi-hid, `qcadsp8380.mbn`, `board-2.bin`, dmsquash-live (Zählung per `lsinitrd`).
* iptsd: `readelf -n` (Branch-Protection), `ldd`, RPM-Requires.
* SELinux-Labels: Stichproben nach dem Relabel; squashfs mit `-xattrs`.
* ISO: El-Torito/GPT-Report, Dateiliste, SHA256; QEMU-Boot bis `graphical.target`/Login.

## 5a. Testergebnisse (22.09.2026, `wsl-fedora-qemu-test.sh`, Logs in `build/fedora/out/qemu-test*.log`)

ISO `Fedora-KDE-Live-44-SL7-20260922.iso` (4 782 817 280 B, SHA256 `4ffb749e…5fdb4`) in `qemu-system-aarch64 -M virt`
(EDK2, seriell, GRUB per Konsole gesteuert):

| Test | Pfad | Ergebnis |
|---|---|---|
| 1 | UEFI → shim/GRUB (unser Menü sichtbar) → `linux-sl7b` (dtbloader-Image Kernel B) + `initrd-sl7b` → `root=live:CDLABEL` → squashfs/overlayfs → systemd | **ok**, `multi-user.target` + `graphical.target` nach 270 s |
| 2 | wie 1 mit Kernel A (`linux-sl7a`, `initrd-sl7a`) | **ok**, 257 s |
| 3 | Fedora-Original-Kernel 6.19.10 aus demselben ISO (Referenz) | **ok**, 272 s |

`tuned.service` schlägt in allen drei Läufen fehl (kopflose VM, auch beim Original) – irrelevant. Der DTB-Stub findet in QEMU
keine SL7-HWID und nutzt den Firmware-DTB (erwartet). Die X1E-Treiber (spi-hid, ath12k, ADSP …) lassen sich nur am Gerät prüfen.

## 5b. Ventoy (30.09.2026)

Martins Stick ist ein Ventoy-Stick (1.1.17, exFAT). Ventoy hängt seinen Hook nur an initrds, die es in `/boot/grub/grub.cfg`
o. ä. **ohne `$`-Variablen** findet (`ventoy_linux.c`, `ventoy_grub_cfg_initrd_collect`); unser Menü nutzt `$L/initrd-…`, und
Fedoras kiwi-Pfad `/boot/aarch64/loader/initrd` steht in keiner Ventoy-Fallback-Liste. Ohne Hook findet dracut das Medium
nicht (unter Ventoy gibt es kein Gerät mit dem `CDLABEL`). Lösung: `build/fedora/ventoy-initrd.cfg` liegt als `/boot/grub/grub.cfg`
im ISO (nur eine initrd-Liste, vom normalen Bootweg nie gelesen). Ergebnis `Fedora-KDE-Live-44-SL7-20260930.iso` (gleiches
squashfs, SHA256 `3a16e0d6…25f2`), kopiert nach `D:\` (Ventoy-Stick, Prüfsumme verglichen).

Test (`build/fedora/wsl-ventoy-test.sh`): Stick-Nachbau in QEMU (VTOYEFI-Dateien vom echten Stick, Ventoy-MBR-Kennung,
Partition 1 mit dem ISO, als USB-Massenspeicher) → Ventoy → unser GRUB → Kernel B **ok** (graphical.target), Kernel A **ok**, Stock-Kernel **ok**
(Logs `build/fedora/out/logs/qemu-ventoy-*.log`). Am Gerät: Ventoy-Menü → ISO wählen → „Boot in normal mode" →
unser Menü wie gewohnt. Auch mit Ventoy: USB-A-Port, Secure Boot aus.

## 5c. Erster echter Boot und Installation am Gerät (30.09.2026)

**Live-Boot:** Stick (Ventoy) → SL7-Menü → Kernel B, erster Versuch: Desktop, Tastatur, Trackpad mit iptsd-Klick, Touchscreen
(`spi 045E:0C6E`, also die ItsLucas-SPI/GTCH-Variante), Stift-Gerät, WLAN-Scan (FRITZ!Box 5590 mit vollem Signal), Bluetooth-Adapter
mit Fabrik-MAC (sl7-mac), LAN-Adapter, Akku/Thermik-Werte laufen. Gerätebaum automatisch „Surface Laptop 7 (13.8 inch)".
Kein Ton, weil der Standardeintrag den ADSP per Denylist auslässt (gewollt). SELinux ist unter Kernel B **aus** (Ubuntu-Konfiguration,
LSM-Liste ohne selinux) – Anaconda hat deshalb `selinux=0` und `SELINUX=disabled` ins Zielsystem geschrieben.
Logs: `hardware/live-2026-09-30/` (dmesg, journal, Status), Zugriff über `hardware/sl7-ssh.py` (Paramiko, sudo -S).

**Installation** per SSH aus dem Live-System (Martin war essen): Anacondas Sperre „kein Kickstart im Live-Modus" per sed in
`startup_utils.py` aufgehoben, Kickstart (lang/keyboard/timezone, `network --hostname=surface`, rootpw, user martin/wheel,
`services --enabled=sshd`, `ignoredisk --only-use=nvme0n1`, `autopart --type=btrfs`, **kein clearpart**) mit
`LIVECMD='anaconda --liveinst --cmdline --kickstart /root/ks.cfg' liveinst` – dafür braucht Anaconda die Session-Bus-Umgebung
des Live-Users (`PKEXEC_UID`, `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`), sonst stirbt es in `inhibit_screensaver`.
Ergebnis (12 min): `nvme0n1p5` /boot ext4 2 GiB, `nvme0n1p6` btrfs 101,6 GiB (root/home) im freien Bereich, Windows-ESP `p1`
wiederverwendet (`EFI/fedora`, 65 MB frei), Windows-Partitionen unverändert, `efibootmgr`: Fedora (0006) vor Windows (0004).
BLS-Einträge für Stock/A/B (+Rescue), `vmlinuz-<sl7>` = dtbloader-Images, host-only-initramfs enthält spi-hid, q6v5_pas, DSP-
Firmware, board-2.bin, efi_pstore. Denylist `anaconda-denylist.conf` vorhanden → `sl7-postinstall.service` räumt sie beim ersten
Start weg (Audio ab dem zweiten Start).

**Nachgebessert:** `DEFAULTKERNEL=kernel-uki-dtbloader` in `/etc/sysconfig/kernel` machte den Stock-Kernel zum Standard →
`saved_entry` auf Kernel B, `DEFAULTKERNEL=kernel`, Postinstall setzt zusätzlich `grubby --set-default` (auch im Build-Skript
nachgezogen). Windows-Eintrag in `/etc/grub.d/40_custom` (chainloader `bootmgfw.efi`, ESP-UUID 26E3-B840), `menu_auto_hide=0`,
`grub2-mkconfig` im Chroot. Installations-Logs liegen unter `/root/sl7-install-logs/` im Zielsystem.

## 5d. Erster Start des installierten Systems (30.09.2026 abends) – Stand: **läuft**

Nach dem ersten Boot nur Text-Login: die Kickstart-Installation setzte `multi-user.target` (kein `xconfig --startxonboot`) →
`systemctl set-default graphical.target`. GPU-Treiber meldete `failed to load gen70500_sqe.fw`: die host-only-initramfs lädt
`msm` früh, enthielt aber die Adreno-Firmware nicht → `/etc/dracut.conf.d/91-sl7-gpu.conf` (`install_items` sqe/gmu/zap) +
`dracut -f`; danach `glxinfo`: **Adreno X1-85**. WLAN hat Martin per Applet verbunden (FRITZ!Box 5590), LAN-Adapter bekam
neue IP (.113). Trackpad mit `iptsd-calibrate /dev/hidraw1` am 13,8"-Gerät neu vermessen (1926 Samples, SizeMax 1.4 statt
6.2 vom 15"-Modell) → `/etc/iptsd.d/91-calibration-045E-0C77.conf`; rohes spi-hid-Touchpad per udev für libinput ausgeblendet;
natürliches Scrollen via `kcminputrc`. **Audio-Freigabe** mit `sl7-audio-freigeben`: Soundkarte `X1E80100-Romulus`,
**SpkrLeft/Right PA Volume max=6, WSA_RX0/RX1 Digital max=81** → Kernel-Limit wirkt; erst dann Denylist + Bootparameter
entfernt (Stock/Rescue-Einträge bleiben ohne ADSP). Danach Akku 100 %/48,7 Wh, Netzteil, USB-C-Ports sichtbar, YouTube läuft
im Akkubetrieb. Der Lautsprecher-Schutz-Plan (Sperre bis zur Prüfung) und alle Korrekturen sind in `wsl-fedora-rootfs-phase2.sh`
Abschnitt [7b] für künftige ISOs nachgezogen. Logs: `hardware/live-2026-09-30/14…22`.

Noch offen: Suspend im installierten System (Live-System hat einmal sauber geschlafen/aufgewacht), Bluetooth-Kopplung,
Touchscreen-Feinabstimmung, Kamera, `EFI/ubuntu`-Altlasten und alter Ubuntu-UEFI-Eintrag (0005) aufräumen.
Martins Wunsch (30.09.): haptisches Feedback beim Halten/Ziehen auf dem Trackpad. Kernel B hat `CONFIG_HID_HAPTIC=y`, aber das
spi-hid-Gerät meldet keine FF-Fähigkeit (capabilities/ff = 0) und iptsd steuert den Aktor nicht an → braucht Treiberarbeit
(HID-Haptik-Usage-Page 0x0E über spi-hid), Community beobachten.
Installiert am 30.09.: VS Code (Microsoft-Repo, aarch64), Teams for Linux (Flatpak, Flathub eingerichtet), sysbench/glmark2/fio
(Bench: sysbench cpu 127k ev/s @12T, NVMe 3,3/2,3 GB/s, glmark2 5218).

## 6. Offen / Grenzen

* Nicht auf echter Hardware getestet (Martins Gerät). Der QEMU-Test prüft Kernel/initrd/squashfs/GRUB, nicht die X1E-Treiber.
* Touchscreen: zwei widersprüchliche, jeweils „verifizierte" Beschreibungen (SPI/GTCH bei ItsLucas, I²C bei fQwQf) → beide als Auswahl.
* Kamera, NPU, Fingerabdruck: nicht adressiert. Lautsprecher: Kernel-Limit aktiv, trotzdem kein „Pro Audio" und ≤ 70 %.
