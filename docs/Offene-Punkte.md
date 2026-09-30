# Offene Punkte – Surface Laptop 7 13,8" (X1E80100, romulus13)

Stand: 22.09.2026. **Fedora-Track** (siehe `docs/Fedora-ISO-Anleitung.md`) ist der aktuelle Weg; die Punkte unten
stammen aus dem Ubuntu-Track (13.09.) und gelten inhaltlich weiter (Hardware-Risiken, Touchscreen-Varianten).

## 0 Fedora-Track – Stand und offene Punkte (22.09.2026)

- [x] Ubuntu 26.04.1 + Kernel Rev. 3 auf dem Gerät → **Boot-Loop** (14.09., Ubuntu-Logo, dann Neustart; keine Logs; Ursache offen). Konsequenz: Live-ISO statt Nachinstallation, konservativer Standard, Diagnose-Einträge.
- [x] Fedora-KDE-Live-44 als Basis analysiert (kiwi, EROFS, dtbloader-UKI, dracut-Live-initrd) und als Rootfs kopiert, per dnf aktualisiert.
- [x] Kernel B `7.3.0-rc3-sl7b` (Ubuntu 7.3 + ItsLucas r15.1) und Kernel A `7.0.0-rc4-sl7` als Fedora-RPMs; DTB-Varianten standard/exp/i2cts; dtbloader-Images (stubble) wie Fedora.
- [x] iptsd (alex-lentz) als RPM mit Fedoras Toolchain (kein SIGILL-Risiko), sl7-mac, Sleep-Hooks, dracut-/Anaconda-/Postinstall-Konfiguration.
- [x] ISO-Bau (Phase 3): `build/fedora/out/iso/Fedora-KDE-Live-44-SL7-20260922.iso` (4,78 GB, SHA256 daneben, implantisomd5).
- [x] QEMU-Boot-Tests (Phase 4): Kernel B, Kernel A und Fedora-Original booten vom ISO bis `graphical.target`; Installationspfad (`kernel-install add` mit dtbloader-Images, BLS, host-only-initramfs, Postinstall) im Overlay-Chroot nachgestellt – ok.
- [x] Fallstrick behoben: dtbloader-Images ohne `.osrel` (sonst stuft kernel-install sie als UKI ein → installiertes System bootet nicht).
- [ ] **Realtest auf dem Gerät** (Secure Boot aus, USB-A bevorzugt): Reihenfolge Kernel B → Kernel A → Diagnose-Einträge. Bei Boot-Loop: Fotos der Diagnose-Ausgabe machen.
- [ ] Touchscreen: SPI/GTCH (ItsLucas, Kernel B Standard) vs. I²C (fQwQf, `-i2cts`-Einträge) – auf dem Gerät entscheiden, Ergebnis der Community melden.
- [ ] Lautsprecher-Limit nach dem ersten Boot prüfen (`amixer -c0 contents | grep -A3 'PA Volume'` → `platform_max` 6), erst dann Ton.
- [ ] Nach Installation: `/var/lib/sl7/postinstall.log` prüfen (Denylist weg, Kernelparameter gesetzt), `sl7-mac all`, `systemctl status 'iptsd@*'`.
- [ ] Kamera (ov02c10, Kernel A hat den Treiber als Modul), NPU, Fingerabdruck: nicht adressiert.
Maßgeblich ist `C:\Users\Martin\Desktop\Projekt Linux ARM\build\workflow\local-facts.md` inklusive des Abschnitts „Nachrecherche-Ergebnisse“. Diese Liste ist die ausführliche Fassung von Kapitel 9 der Endfassung `C:\Users\Martin\Desktop\Projekt Linux ARM\docs\SL7-Linux-Dossier.md` (beide sind auf dem gleichen Stand; bei Abweichungen gilt diese Liste) und ersetzt Kapitel 9 des alten Entwurfs (liegt abgelegt unter `docs/archiv/`) vollständig. Die ausführbaren Befehle stehen in `docs/Build-Rezept.md`.

**Korrekturen gegenüber dem ersten Entwurf (in der Endfassung bereits eingearbeitet)**
- Lautsprecher: Der Standardschutz ist **nicht** die Modul-Blacklist, sondern Ubuntus Kernel-Volume-Limit. Die Blacklist legt die **gesamte** Soundkarte still (auch Kopfhörer und Mikrofone) – der Entwurf behauptete das Gegenteil.
- Boot-Medium: Der „invalid magic number“-Fehler war ein **korrupter ISO-Download**, kein Ventoy-/arm64-Problem (vom Melder selbst aufgeklärt). Ventoy im **Normalmodus** ist der Primärweg, `dd`/Rufus nur Fallback.
- Neu hinzugekommen (Rev. 3, nicht im Entwurf): CPU-Thermal-Trips, iris-Videodecoder, Touchpad-Reset-Fix, zweite Touchscreen-Variante auf spi10.

---

## 1 Risiken mit Schadenspotenzial

### 1.1 Lautsprecher – dauerhafter Hardwareschaden (kritisch)

- [ ] **Mechanik verstehen:** Linux hat für den X1E **keine aktive Speaker-Protection** (kein Feedback-Pfad, keine Auslenkungsbegrenzung). Bei zu hoher Aussteuerung greift nur ein Hardware-Schutz im Verstärker, der den Lautsprecherausgang bis zum Reboot abschaltet – und darunter kann die Membran schon zerstört sein. Belege: ELLX-Installer-README 01.07.2026 („rechter Lautsprecher dauerhaft zerstört“), ProgrammerIn-wonderland in linux-surface#1590 30.06.2026 („had to get a new surface laptop 7 because it ruined my speakers“), LP #2149808 (Tobias Heider, Canonical, 21.04.2026).
- [ ] **Schutzschicht kennen:** Unser Kernel enthält ab Revision 2 Ubuntus offiziellen Fix (`snd_soc_limit_volume`): WSA/WSA2 RX0/RX1 Digital Volume = 81 (−3 dB), Spkr/Woofer/Tweeter PA Volume = 6 (0 dB). Die wsa884x-Verstärker können −9 bis +9 dB; der Patch deckelt den PA auf 0 dB. Das ist die einzige Schicht, die auch `amixer` und PipeWire „Pro Audio“ abdeckt, weil sie `platform_max` am ALSA-Regler setzt.
- [ ] **Nach dem ersten Boot sofort prüfen, dass das Limit greift** – erst danach überhaupt Ton einschalten.
      `amixer -c0 contents | grep -B2 -A3 -i 'PA Volume'` → `platform_max` muss **6** sein.
- [ ] **Verhaltensregeln (gelten dauerhaft):** Lautstärke nie über ~70 %, niemals 100 %; GNOME-Überverstärkung bleibt aus (setzt der Installer per dconf `allow-volume-above-100-percent=false`); **niemals** das PipeWire-Profil **„Pro Audio“** wählen – genau dieser Klick hat laut #1590 (23.05.2026) den ELLX-Schaden ausgelöst, weil es die rohen ALSA-Regler ohne UCM freilegt.
- [ ] **Erster Ton-Test bewusst klein:** Lautstärke auf ~20 % stellen, kurzen Testton abspielen, Ohr ans Gerät, keine Bass-lastigen Dauerlasten. Erst danach schrittweise erhöhen.
- [ ] **Falle „harte Modulsperre“:** `SL7_NO_SPEAKER=1` im Installer (`blacklist` + `install … /bin/false` + Cmdline `module_blacklist=snd_soc_wsa884x`) macht **die ganze Karte tot**, nicht nur die Lautsprecher: `qcom_snd_parse_of()` löst die Codec-Phandles aller vier DAI-Links auf, ohne wsa884x hängt `X1E80100-Romulus` dauerhaft in `-EPROBE_DEFER` – kein Kopfhörer, kein DMIC, kein DisplayPort-Audio. Nur als Opt-in für einen tonlosen ersten Testboot gedacht.
      Aufheben: `sudo rm /etc/modprobe.d/sl7-no-speaker.conf`, `module_blacklist=` aus `/etc/default/grub.d/90-sl7.cfg` entfernen, `sudo update-grub && sudo dracut --force && reboot`.
- [ ] **UCM-Zuordnung prüfen** – wenn `alsa-ucm-conf` den Romulus13 nicht per DMI-Regex dem `LENOVO-T14s`-Profil zuordnet, laufen alle Regler ungezähmt.
      `cat /sys/devices/virtual/dmi/id/{board_vendor,product_family,board_name}` und `alsaucm -c X1E80100-Romulus list _verbs`. Rückfall: tj90241-Patch (board_name in DMI_info + Surface-Regex).
- [ ] **Wenn das Kernel-Limit nicht genügt** (verzerrt, pumpend, Schutzabschaltung): Amps auf DT-Ebene stilllegen (`&left_spkr`/`&right_spkr`/`&swr0` auf `disabled`, `/delete-node/ wsa-dai-link`, `audio-routing` kürzen). Dann bleiben Kopfhörer und DMICs funktionsfähig – im Gegensatz zur Modul-Blacklist. Noch nicht gebaut (unverifiziert).

### 1.2 Datenverlust bei Installation und Dual-Boot

- [ ] **BitLocker vor dem ersten Fremd-Boot aussetzen und den Recovery-Key sichern** (ausgedruckt oder auf einem zweiten Gerät). Jede Änderung an Secure Boot oder Bootreihenfolge kann sonst Windows in die Recovery-Abfrage zwingen.
      `manage-bde -protectors -disable C: -RebootCount 2` (als Administrator unter Windows).
- [ ] **UEFI-Einstellungen bewusst setzen:** Secure Boot auf **None** (nicht „Microsoft only“), USB-Boot an. Notiere den Ausgangszustand, damit Windows-only wiederherstellbar ist.
- [ ] **Windows-Partition nur mit Windows-Bordmitteln verkleinern** (Datenträgerverwaltung), nicht mit dem Live-Installer, und vorher ein vollständiges Backup der wichtigen Daten ziehen.
- [ ] **`dd`/Rufus nur mit doppelt geprüftem Ziellaufwerk.** Ein Tippfehler beim Zielgerät löscht die interne NVMe. Auf dem SL7 ist `dd` ohnehin nur Fallback (siehe 4.3).
- [ ] **Windows nicht löschen:** UEFI-, EC- und Firmware-Updates für den SL7 kommen ausschließlich über Windows Update bzw. das Surface-MSI. Ohne Windows-Partition gibt es keinen Update-Pfad mehr (fwupd unterstützt das Gerät nicht).

### 1.3 Thermik und Notabschaltung

- [ ] **Ohne unsere DT-Trips gibt es keine Vorwarnstufe:** `hamoa.dtsi` definiert für die zwölf CPU-Zonen nur `critical`-Trips bei 115 °C, also keine passive Drosselung davor. Rev. 3 ergänzt passive Trips bei 85 °C mit 5 °C Hysterese. Läuft ein Kernel **ohne** diesen Zusatz (Rev. 1/Rev. 2, Ubuntu-Stock), unter Dauerlast nicht unbeaufsichtigt lassen.
      `watch -n2 'cat /sys/class/thermal/thermal_zone*/temp | paste -sd" "'`
- [ ] **Lüftersteuerung ist nicht in unserem Kernel:** `SURFACE_FAN` ist bewusst **nicht** gesetzt. Die Annahme, dass der EC den Lüfter autonom regelt, ist **(unverifiziert)** – beim ersten Volllast-Test hörbar kontrollieren, ob der Lüfter überhaupt anläuft.
      `stress-ng --cpu 12 --timeout 120s` parallel zur Temperaturbeobachtung, sofort abbrechen wenn > 100 °C.

### 1.4 Sicherheit der ruhenden Daten

- [ ] **Secure Boot ist aus und die Root-Verschlüsselung hängt an keinem TPM.** Bei Verlust oder Diebstahl schützt nur eine starke LUKS-Passphrase; ohne LUKS liegt alles offen. Bewusste Entscheidung, aber vor der Installation festlegen – nachträglich ist es eine Neuinstallation.
- [ ] **Der Hardware-Dump enthält Seriennummern und MAC-Adressen.** Die ZIP-Datei bleibt lokal, nichts davon ungefiltert in Issues oder Foren posten.

---

## 2 Experimentelles – auf dem Gerät zuerst prüfen

Gemeinsamer Rückfallweg für alle DT-Punkte: Der Standard-Kernel ist das stubble-Image mit eingebetteten DTBs (SMBIOS-Auswahl), ein geänderter DTB wird also normalerweise überschrieben. Zum Testen eines eigenen DTB entweder den vom Installer angelegten GRUB-Eintrag **„SL7 Fallback: 7.0.0-rc4-sl7 (plain + devicetree)“** benutzen (lädt `/boot/vmlinuz-…plain` + `/boot/sl7-romulus13.dtb`) oder dem stubble-Image `stubble.dtb_override=false` mitgeben. Vergleichspakete liegen unter `C:\Users\Martin\Desktop\Projekt Linux ARM\build\out\7.0.0-rc4-sl7-1` (nur dwc3) und `…-2` (+ Speaker-Limit, USB-PHY, i2c8-Touchscreen).

### 2.1 Touchscreen Variante A – i2c8 @0x34, `hid-over-i2c` (unwahrscheinlichere Variante)

- [ ] Patch `0010-romulus13-touchscreen-hid-over-i2c.patch` (linux-input, fQwQf, 07.09.2026): i2c8 @0x34, hid-descr-addr 0x0000, IRQ tlmm 38 level-low, Reset tlmm 31 active-low, 400 kHz. Maintainer Krzysztof Kozlowski hat „Drop“ geantwortet (nur Self-Tested-by) – der Node ist **experimentell** und laut Faktenlage die unwahrscheinlichere der beiden Varianten.
      `dmesg | grep -iE 'i2c.?hid|hid-over-i2c|8a8000.i2c|i2c_designware|0034'`
- [ ] Rückfallplan: Wenn der Node nur Timeouts/Probe-Fehler produziert (oder den i2c8-Bus blockiert), im DTS `status = "disabled"` setzen, DTB neu bauen und über den Fallback-Eintrag booten; Ergebnis an den linux-input-Thread zurückmelden.

### 2.2 Touchscreen Variante B – spi10, HID-over-SPI (wahrscheinlichere Variante)

- [ ] Patch aus Rev. 3: QUP1 SE2 als QSPI, 40 MHz, read-opcode 0xEB, 8 Dummy-Clocks, IRQ gpio51, Reset gpio48, 5 V über gpio64 (`vreg_ts2_5p0`), `gpi_dma1`. Quellen: linux-surface#1590 (horizontblau, 25.08.2026: ACPI-Gerät GTCH mit `_CID PNP0C51` an `\_SB.SP11` = QUP_1_SE2, berichtet „touchscreen läuft“ mit ELLX-Kernel + iptsd) und orvitpng/nix1e `touchscreen.dtsi` (01.07.2026, gleiche Pins).
- [ ] **Beide Varianten sind gleichzeitig im DTB** – der erste Boot entscheidet, welche enumeriert. Erst danach die unterlegene deaktivieren, damit kein Bus doppelt bedient wird.
      `dmesg | grep -iE 'spi.?hid|spi10|88c000|hid-over-spi'` und `ls /sys/bus/hid/devices; ls /dev/hidraw*`
- [ ] Rückfallplan: Enumeriert weder A noch B, beide auf `disabled` und ohne Touchscreen weiterarbeiten (Trackpad bleibt davon unberührt). Bei SIGILL des iptsd-Binaries: `objcopy --remove-section=.note.gnu.property` oder Neubau mit `-mbranch-protection=standard`.

### 2.3 USB-PHY-Versorgungs-Tausch (hamoa-Fix, nur romulus-Hunk)

- [ ] Upstream-Commit 4458dcd „arm64: dts: qcom: hamoa: Fix swapped USB QMP PHY vdda-phy/vdda-pll supplies“ (Manivannan Sadhasivam, 03.08.2026), bei uns nur der `romulus.dtsi`-Teil: `usb_1_ss0/ss1_qmpphy` und `usb_mp_qmpphy0/1` tauschen l1j/l2j, l2d/l2j, l3c/l3e. Nicht in v7.2 enthalten, also auch bei einem Basiswechsel mitzunehmen. Fehlverhalten würde USB-C/USB-A komplett tot legen.
      `dmesg | grep -iE 'qmp|phy|dwc3|xhci' | head -40` sowie `lsusb` mit angestecktem USB-A-Stick und einem USB-C-Gerät, DisplayPort-Alt-Mode separat.
- [ ] Rückfallplan: Bei toten Ports Revision 1 aus `build\out\7.0.0-rc4-sl7-1` installieren (enthält nur die dwc3-Patches, keinen PHY-Tausch) und vergleichen; das isoliert die Ursache eindeutig.

### 2.4 dwc3-Resume-Patches

- [ ] Community-Serie „reinit-phy-on-resume“ 0001–0003 (Oliver White, 02.06.2026) gegen tote USB-Ports nach Standby; im kanonischen Gesamt-Diff `build\patches-upstream\sl7-tree-full.diff` enthalten (dwc3 `core.c`/`core.h` + Binding). Nicht upstream, also bei jedem Rebase erneut zu prüfen.
      `sudo systemctl suspend`, aufwecken per Power-Taste, dann `lsusb` und `dmesg -w | grep -i dwc3` vergleichen (vorher/nachher).
- [ ] Rückfallplan: Falls die Patches selbst Ärger machen (Hänger beim Resume, Fehler beim Probe), Kernel ohne sie bauen – `wsl-apply-sl7-patches.sh` auf frischem Tag-Checkout und die dwc3-Hunks aus dem Diff nehmen. Suspend läuft laut Faktenlage mit `s2idle` und Aufwecken per Power-Taste zuverlässig.

### 2.5 CPU-Thermal-Trips

- [ ] Rev. 3 ergänzt `#cooling-cells` für cpu0..cpu11 und passive Trips bei 85 °C / 5 °C Hysterese in den zwölf Zonen `cpu0-0` bis `cpu2-3-top-thermal` (20 cooling-device-Einträge im DTB). Vorbild: `scuggo/x1e-nixos`, `surface-laptop-7-thermal.dts`. Nötige Optionen sind gesetzt (`CPU_THERMAL=y`, `QCOM_TSENS=y`, Governors `step_wise`/`power_allocator`).
      `grep . /sys/class/thermal/thermal_zone*/type /sys/class/thermal/thermal_zone*/trip_point_*_temp 2>/dev/null | head -40` und unter Last `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq`.
- [ ] Rückfallplan: Drosselt das System zu früh (Leistungseinbruch schon bei moderater Last), Trip-Temperatur im DTS anheben oder die passiven Trips wieder entfernen und DTB neu bauen. Greift gar keine Drosselung, Punkt 1.3 ernst nehmen und Volllast nur beaufsichtigt fahren.

### 2.6 iris-Videodecoder

- [ ] Rev. 3 aktiviert `&iris` mit `firmware-name = "qcom/x1e80100/microsoft/Romulus/qcvss8380.mbn"`, `status = "okay"`; die passende Firmware liegt seit 17:03 im Paket `build\out\sl7-firmware-msi-26100_26.053.36539.0.tar.xz`. Der Knoten `video-codec@aa00000` (`qcom,x1e80100-iris`) stammt aus `hamoa.dtsi`; andere X1E-Boards aktivieren ihn genauso mit Vendor-Firmware – für den Romulus13 ist das **(unverifiziert)**.
      `dmesg | grep -iE 'iris|venus|aa00000'`, `ls /dev/video*`, `v4l2-ctl --list-devices`
- [ ] Rückfallplan: Bei Firmware-Fehlern oder Hängern `status = "disabled"` setzen – Software-Decoding kostet nur Akkulaufzeit, sonst nichts. Browser nutzen den HW-Decoder ohnehin erst nach zusätzlicher Konfiguration.

### 2.7 Touchpad-Reset-Fix („Wedge“)

- [ ] Rev. 3 setzt in `romulus.dtsi` den Regulator `vreg_ts_5p0` auf `regulator-boot-on` und entfernt gpio65 aus den spi19-Reset-States (nur noch gpio120). Quellen: horizontblau in linux-surface#1590 (29.08.2026), deckungsgleich mit orvitpng `touchpad.dtsi`. Ziel ist das Verklemmen des Touchpads nach Suspend.
      `dmesg | grep -iE 'spi_hid|spi19|88c000.spi'`, danach Suspend-Zyklus und Test, ob der Zeiger ohne den Sleep-Hook zurückkommt.
- [ ] Rückfallplan: Bleibt das Touchpad nach Resume tot, greift weiterhin der Sleep-Hook `/lib/systemd/system-sleep/trackpad` (spi_hid unbind/bind), den der Installer mitliefert. Zweite Option: die neuere Chromium-spi-hid-Serie mit `fullduplex.patch` aus `orvitpng/nix1e` („properly powers the trackpad and fixes suspend“) backporten – nicht gebaut, **(unverifiziert)**.

---

## 3 Unverifizierte Annahmen aus der Recherche

- [ ] **UCM-Regex trifft den Romulus13** – nur indirekt belegt (SL7-UCM am 13.06.2025 upstream gemerged, 14.07.2025 „audio functioning“). Prüfbefehl siehe 1.1. **(unverifiziert)**
- [ ] **ELLX-Nachtrag „I think I fixed the bug“** zum Lautsprecherschaden ist bis heute unbelegt; die Warn-README ist unverändert online. Wir behandeln den Schaden als weiterhin möglich. **(unverifiziert)**
- [ ] **`CONFIG_VIDEO_QCOM_IRIS`** ist laut Recherche in der Konfiguration vorhanden, wurde aber nicht wie die übrigen Optionen lokal am Build verifiziert. **(unverifiziert)**
      `grep -i iris /boot/config-7.0.0-rc4-sl7`
- [ ] **Ubuntu 26.04.1 arm64 bootet auf dem romulus13 bis in den Installer, inklusive interner Tastatur** – primär belegt sind nur vladimir-alekseev (20.05.2026, SL7 13,8" mit X Plus, „vanilla arm64 desktop ISO“) und perchbirdd (14.05.2026, 13", offizielles Resolute-Image „mostly“ funktionierend, WLAN/BT erst nach Firmware). Für genau unsere Konfiguration **(unverifiziert)**.
- [ ] **Die Concept-ISO ist keine sichere Alternative:** Bei perchbirdd lief sie in eine Boot-Schleife, während das offizielle Image ging. Als Zweit-ISO mitnehmen, aber nicht als Erstversuch.
- [ ] **Ob dracut `/etc/modprobe.d/*.conf` in die Initramfs übernimmt**, ließ sich aus dem Quelltext nicht belegen – deshalb setzt der Installer bei `SL7_NO_SPEAKER=1` zusätzlich die Kernel-Cmdline. **(unverifiziert, aber umgangen)**
- [ ] **Ob `linux-qcom-x1e 7.2.0-18.18` (Concept-PPA, 09.09.2026) den Speaker-Limit-Patch enthält**, ist ungeprüft; der hamoa-USB-PHY-Fix ist dort sicher **nicht** drin. Vor einem Basiswechsel: `dget` und `grep -n limit_volume sound/soc/qcom/x1e80100.c`. **(unverifiziert)**
- [ ] **Akkulaufzeit, s2idle-Drain und Dauer-Thermik** sind unbekannt (nur 6.14-Berichte aus 2025). Messen mit `powertop`, `upower -i /org/freedesktop/UPower/devices/battery_*` und einem Lauf über Nacht. **(unverifiziert)**
- [ ] **Cmdline-Unsicherheit:** `clk_ignore_unused pd_ignore_unused` sind gesetzt (wie in Ubuntus x1e-Images), shenkis riet 2024 zum Entfernen; `arm64.nopauth` und `efi=noruntime` sind nicht gesetzt. Testreihenfolge: Standard → ohne die beiden → mit `arm64.nopauth` → mit `efi=noruntime` (Letzteres bricht `sl7-mac`). **(unverifiziert)**
- [ ] **RTC-Status unklar** (README meldet funktionierend, Issue #8 widerspricht). `ls /sys/class/rtc; timedatectl` – NTP genügt im Alltag. **(unverifiziert)**
- [ ] **USB4/Thunderbolt fehlt**, DP-Hotplug gilt als unzuverlässig ohne die glathe-Serie (Discourse 07/2026); Docks voraussichtlich nur PD + USB2. Cold-Plug und Full-Featured-USB-C-Kabel verwenden. **(unverifiziert)**
- [ ] **ath12k `board-2.bin`**: Unser Eintrag `subsystem-device 1107` ist upstream nicht vorhanden; die Datei liegt bewusst unter `/lib/firmware/updates`, damit Paketupdates sie nicht überschreiben. Ob künftige Chip-Firmware das Board-Daten-Format ändert, ist offen. **(unverifiziert)**
- [ ] **Kernel-Wartung:** ELLX ist seit 14.05.2026 ohne Push, Community-Maintainer haben Geräte verkauft; spi-hid, QSPI-Hack, ath12k-rfkill-Hack, Kamera-DT und dwc3 sind nicht upstream. Jeder Basiswechsel ist ein manueller Rebase gegen `sl7-tree-full.diff`.
- [ ] **Nicht unterstützt bzw. ohne Quellenstand:** TPM/Pluton, IR-Kamera (Windows Hello), Umgebungslichtsensor, Tastaturbeleuchtung/Fn-Sonderfunktionen, fwupd, Surface-Connect (USB/Display), KVM (Firmware startet in EL1, EL2 nur über TravMurav/slbounce). Kamera-Bildqualität mit Grünstich/Strobing. **(unverifiziert)**
- [ ] **Recherchelücken:** Discourse-Posts ~#1790–#2157 ungelesen, spi-hid-Status jenseits v3 (lore gesperrt), Fedora 45, dtbloader-Release, ELLX-ISO-Basis, ob `proprietary-firmware.tar.gz` und `microsoft-firmware.tar.xz` identisch sind. Nachziehbar über GitHub-/GitLab-API, lkml.iu.edu, ratatoskr.run (git.kernel.org, lore und git.launchpad.net blocken automatisierte Abrufe).

---

## 4 Nächste Schritte in Reihenfolge

### 4.1 Bestandsaufnahme auf dem Surface (noch unter Windows)

- [ ] **Hardware-Dump ausführen** – liefert PnP-IDs, Treiber, ACPI-Tabellen, EDID, Firmware-Blobs, MAC-Adressen, Partitionen, Batterie, `powercfg /a`, Secure-Boot-/TPM-Status. Das ist die Basis, um die offenen i2c-/SPI-Adressen (Touchscreen, Sensoren) sauber zuzuordnen. Dauer 2–4 Minuten, als Administrator.
      `powershell -ExecutionPolicy Bypass -File .\SL7-Hardware-Dump.ps1` (Skript: `C:\Users\Martin\Desktop\Projekt Linux ARM\hardware\SL7-Hardware-Dump.ps1`)
- [ ] **ZIP in den Projektordner kopieren** (`…\Projekt Linux ARM\hardware\`) und ACPI-Dump gezielt nach `GTCH`, `_CID PNP0C51` und `\_SB.SP11` durchsuchen – das entscheidet vorab, welche Touchscreen-Variante überhaupt Sinn ergibt.
- [ ] **Windows aktualisieren** (Windows Update inkl. Surface-Firmware), damit UEFI/EC auf dem neuesten Stand sind, bevor der Dual-Boot steht.
- [ ] **BitLocker aussetzen, Recovery-Key sichern, Backup ziehen, Windows-Partition verkleinern.** Siehe 1.2.
- [ ] **UEFI:** Secure Boot auf **None**, USB-Boot an.

### 4.2 Boot-Medium vorbereiten

- [ ] **Ubuntu 26.04.1 arm64 Desktop-ISO** (cdimage-Listing 26.08.2026) laden und **vor und nach** dem Kopieren per SHA256 gegen `SHA256SUMS` prüfen – der aufgeklärte „invalid magic number“-Fall im Thread war genau das und hat einen halben Tag gekostet.
      `certutil -hashfile <iso> SHA256`
- [ ] **Ventoy 1.1.17** (24.07.2026) auf den Stick, ISO daraufkopieren; die Concept-ISO und `S:\Surface fedora\Fedora-KDE-SurfaceLaptop7-44.aarch64.iso` als Zweit-/Drittoption mit auf denselben Stick.
- [ ] **Im Ventoy-Menü den Normalmodus (Enter) nehmen, nicht den grub2-Modus (Strg+R)**: Nur so lädt der ISO-eigene Ubuntu-GRUB, der stubble und die `.dtbauto`-Sektionen kennt.
- [ ] **Externe USB-Tastatur bereitlegen.** Für direkt geflashte Sticks (`dd`/Rufus) sind auf dem SL7 GRUB-Freezes und eine tote interne Tastatur belegt (Launchpad #2084951; Community-README: „Ventoy is required to enable keyboard support in GRUB“). `dd` bleibt reiner Fallback.

### 4.3 Sichere Testboot-Reihenfolge

- [ ] **Schritt 1 – Live-Boot ohne Installation, ohne Ton.** Vom Ventoy-Stick das offizielle 26.04.1-Image starten und nur schauen: Bild da? Interne Tastatur? Trackpad? Netzwerk über USB-Ethernet? Nichts installieren, nichts an Audio anfassen.
      `uname -r; dmesg | grep -iE 'error|fail|EPROBE' | head -40`
- [ ] **Schritt 2 – Ubuntu neben Windows installieren, mit dem Stock-Kernel booten.** Dieser Stand ist die Rückfallebene: Er bleibt im GRUB-Menü stehen und funktioniert auch dann, wenn unser Kernel später hängt. GRUB-Timeout steht auf 5 s mit Menü.
- [ ] **Schritt 3 – Firmware zuerst, WLAN/BT prüfen.** Erst danach lohnt sich alles Weitere, weil ohne `board-2.bin` und die Microsoft-Blobs kein WLAN läuft.
      `dmesg | grep -iE 'ath12k|adsp|cdsp'`; Paket aus `build\out\sl7-firmware-msi-26100_26.053.36539.0.tar.xz`
- [ ] **Schritt 4 – ersten Boot des eigenen Kernels bewusst tonlos.** Installer mit harter Modulsperre laufen lassen, damit im unbekannten Zustand garantiert kein Lautsprecher angesteuert wird. Alles außer Audio in diesem Boot testen.
      `cd <ordner>/out && sudo SL7_NO_SPEAKER=1 bash sl7-install-on-laptop.sh` → `sudo reboot` → `uname -r` muss `7.0.0-rc4-sl7` zeigen
- [ ] **Schritt 5 – Kernkomponenten abhaken** (in dieser Reihenfolge, weil jeder Punkt den nächsten voraussetzt): Boot und DTB-Auswahl → Tastatur/Trackpad → WLAN/BT → Display/Brightness → USB-A und USB-C → Suspend und Resume → Akku/Batterie-Manager → Touchscreen-Variante A/B → Thermik unter Last → iris/Video.
      `dmesg | grep -iE 'ath12k|adsp|cdsp|msm|spi.hid|battmgr|iris|error' | head -60`
- [ ] **Schritt 6 – Ton freischalten und mit dem Limit-Test beginnen.** Sperre entfernen (siehe 1.1), rebooten, `platform_max` prüfen, dann bei ~20 % einen kurzen Testton. Erst wenn das sauber klingt, in kleinen Schritten hoch – nie über 70 %.
- [ ] **Schritt 7 – Feinschliff:** eigene iptsd-Kalibrierung (`iptsd-find-hidraw`, dann `sudo iptsd-calibrate /dev/hidrawN`), `sl7-mac` prüfen (feste MACs statt zufälliger), Sleep-Hooks testen, Energie messen (`powertop`, Lauf über Nacht), Cmdline-Varianten aus Abschnitt 3 durchprobieren.
- [ ] **Schritt 8 – Ergebnisse festhalten:** `dmesg`, `lsmod`, `/proc/asound/cards`, Thermal-Zonen und die Touchscreen-Entscheidung in `docs/` ablegen und das Dossier-Kapitel 6 entsprechend korrigieren. Erst danach über einen Basiswechsel auf Concept 7.2 nachdenken.

---

## 5 Was man der Community zurückmelden könnte

- [ ] **linux-surface#1590 (aktivster Thread, bis 12.09.2026): welche Touchscreen-Variante auf dem romulus13 wirklich enumeriert** – i2c8 @0x34 oder spi10/HID-over-SPI – mit `dmesg`-Auszug. horizontblau (25.08.2026) und fQwQf (linux-input, 07.09.2026) beschreiben zwei konkurrierende Wege; eine saubere Gegenprobe fehlt bisher.
- [ ] **linux-input / fQwQf-Patch:** Rückmeldung, ob der i2c8-Node auf echter Hardware etwas tut. Krzysztof Kozlowski hat „Drop“ geantwortet, weil nur ein Self-Tested-by vorlag – ein zweiter Test entscheidet die Frage so oder so.
- [ ] **Der Speaker-Limit-Fix fehlt im ELLX-Tree und in beiden Concept-Branches.** Das ist der wichtigste Befund: Der offizielle Ubuntu-Fix aus LP #2149808 (seit 29.04.2026 in `linux 7.0.0-15.15`) ist genau die Schutzschicht, deren Fehlen zum ELLX-Schaden passt. Meldenswert an ProgrammerIn-wonderland (README steht unverändert mit Warnung online), an den Concept-Discourse-Thread und an #1590.
- [ ] **ath12k-Board-Daten:** Den SL7-Eintrag `subsystem-device 1107` aus unserer `board-2.bin` an ath12k-firmware einreichen – upstream fehlt er, jeder SL7-Nutzer patcht ihn aktuell selbst.
- [ ] **iptsd-Paketierung:** Das ELLX-Deb bringt weder `iptsd@.service` noch `50-iptsd.rules` mit (Community-Issue #23, 30.07.2026); zusätzlich der SIGILL-Fall durch BTI/branch-protection-Mismatch mit der Abhilfe `objcopy --remove-section=.note.gnu.property`. Beides als konkrete Ergänzung an das Repo bzw. den Issue.
- [ ] **CPU-Thermal-Trips für die X1E-Boards:** `hamoa.dtsi` hat für die CPU-Zonen nur critical-Trips bei 115 °C. Nach einem Test auf dem Gerät wären die passiven Trips ein sinnvoller Patch an linux-arm-msm (Vorbild `scuggo/x1e-nixos`, `surface-laptop-7-thermal.dts`).
- [ ] **hamoa-USB-PHY-Supply-Fix (Commit 4458dcd, 03.08.2026):** Bestätigen, dass er auf dem romulus13 wirkt, und einen Backport nach v7.2 anregen – dort fehlt er, was jeden Umstieg auf das Concept-PPA betrifft.
- [ ] **dwc3-Resume-Serie (Oliver White, 02.06.2026):** Ein belastbares Tested-by vom romulus13 würde der Serie helfen, upstream zu kommen; bisher trägt sie nur der Community-Fork.
- [ ] **stubble-Wissen dokumentieren:** Dass stubble einen vom Bootloader übergebenen DTB überschreibt und `stubble.dtb_override=false` das abschaltet, taucht im Thread nur verstreut auf (valpackett 19.08.2026, ProgrammerIn-wonderland 23.08.2026). Eine knappe Zusammenfassung im Issue spart anderen viel Rätselraten.
- [ ] **Ventoy-Fehlalarm richtigstellen:** Der „invalid magic number“-Fall (Notliam99, 20.05.2026) war ein korrupter Download und wurde noch am selben Tag aufgeklärt – die Warnung geistert trotzdem weiter herum. Ein kurzer Hinweis „ISO-Hash prüfen, Ventoy-Normalmodus nutzen“ gehört in die Anleitung.
