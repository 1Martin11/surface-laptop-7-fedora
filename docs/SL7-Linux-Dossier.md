# Projekt Linux – Surface Laptop 7 13.8" X Elite (Romulus13)

**Master-Referenz, Endfassung – Stand 13.09.2026**

| | |
|---|---|
| Gerät | Microsoft Surface Laptop 7th Edition, 13,8", Snapdragon X Elite X1E80100, Codename **Romulus13** (DT-compatible `microsoft,romulus13`, SMBIOS-SKU `Surface_Laptop_7th_Edition_2036`; das 15"-Modell ist Romulus15 / SKU 2037) |
| Ziel | Linux „zu 100 %" auf dem Gerät, Dual-Boot neben Windows |
| Build-Host | MSI-PC, Ryzen 9 9950X3D (32 Threads), 31 GB RAM, WSL2 Ubuntu 26.04 (WSL-Kernel 6.6.114), Cross-Compile + arm64-qemu-user-Chroot |
| Kernel-Basis | ELLX-Kernel Tag `7.0.0-rc4-12` (Ubuntu-Concept-Tree qcom-x1e-7.0) + eigene Patches → `7.0.0-rc4-sl7`. **Paket-Revisionen 1, 2 und 3 sind gebaut und im arm64-Chroot getestet.** Kanonischer Patch-Stand = `build/patches-upstream/sl7-tree-full.diff`, angewendet per `build/wsl-apply-sl7-patches.sh`. |
| Distro-Ziel | Ubuntu 26.04.1 LTS arm64 (offizielles Desktop-ISO vom 26.08.2026) + eigener Kernel |
| Quellenlage | Web-Recherche-Korpus (7 Themen, 4 davon skeptisch gegengeprüft), Nachrecherche vom 13.09.2026 und lokal verifizierte Fakten vom Build-Host (12./13.09.2026). Lokale Fakten haben Vorrang. Angaben aus nur einer Quelle oder mit Widerspruch sind mit **(unverifiziert)** markiert. |

> **Sicherheitshinweis vorab (Audio):** Linux hat für den X1E **keine aktive Speaker-Protection**. Mehrere unabhängige Quellen (ELLX-README 01.07.2026, linux-surface#1590 06/2026, Launchpad 2025, LP #2149808 04/2026) berichten dauerhafte Lautsprecherschäden bei hoher Lautstärke.
> **Standardschutz in diesem Projekt ist Ubuntus Kernel-Volume-Limit** (im Kernel ab Paket-Revision 2, identisch mit dem offiziellen Fix aus LP #2149808): WSA Digital −3 dB, PA-Regler 0 dB, gesetzt per `snd_soc_limit_volume` am ALSA-Regler (`platform_max`) – wirkt damit auch gegen `amixer` und gegen das PipeWire-Profil „Pro Audio".
> Die **harte Modulsperre** (`snd_soc_wsa884x` blockieren) ist nur noch **Opt-in per `SL7_NO_SPEAKER=1`** und bedeutet **gar keinen Ton** – sie legt die gesamte Soundkarte still, nicht nur die Verstärker. Details und Hausregeln in Abschnitt 6.5.

---

## 1 Ziel & Ausgangslage

### 1.1 Ziel

Ein vollständig nutzbares Linux auf dem Surface Laptop 7 13,8" (X1E80100): Boot ohne Bastelei am GRUB, Tastatur, Touchpad, Touchscreen, WLAN/Bluetooth mit festen MAC-Adressen, GPU-Beschleunigung, Kamera, Suspend/Resume, Akku-Anzeige, USB-C-Display – und zwar mit einem selbst gebauten, nachvollziehbar gepatchten Kernel, den man bei Bedarf neu bauen kann. Windows bleibt als Dual-Boot erhalten (Firmware-Updates gibt es nur über Windows, und ein Windows-Reboot ist der einfachste Reset für ein hängendes Touchpad).

### 1.2 Was lokal vorhanden ist (Projektordner `C:\Users\Martin\Desktop\Projekt Linux ARM`)

| Bereich | Inhalt |
|---|---|
| `docs/` | dieses Dossier (die abgelöste Entwurfsfassung liegt unter `docs/archiv/`), `Build-Rezept.md` (ausführbare Befehlsfolge) und `Offene-Punkte.md` (Risiken, Experimente, Reihenfolge auf dem Gerät – ausführliche Fassung von Kapitel 9); `dts/` mit der Romulus-DTS-Kopie (`x1e80100-microsoft-romulus.dtsi` 36 KB, `x1e80100-microsoft-romulus13.dts` 292 Bytes und `x1e80100-microsoft-romulus15.dts` 290 Bytes, beide nur model/compatible); `quellen/` mit Rohdaten (u. a. Kopie der 2026-Kommentare aus linux-surface#1590 als `ls1590-comments-2026.json`, Kopien von `nix1e` und `x1e-nixos`) |
| `build/` | WSL-Skripte `wsl-*.sh` (Toolchain, Klonen, Patchen, Build, stubble, Firmware, Chroot-Tests, Verifikation), `inspect/` (Diagnose-Skripte inkl. `wsl-check-safety.sh`), `patches-upstream/` (kanonischer `sl7-tree-full.diff` + Einzelpatches zur Herkunftsdokumentation), `ellx-ref/` (`microsoft-firmware.tar.xz` von ELLX zum Abgleich), `workflow/` (Recherche-Korpus, `local-facts.md`), `out/` (Artefakte, siehe unten) |
| `build/out/` | `7.0.0-rc4-sl7-1/` (Rev. 1: dwc3-Patches), `7.0.0-rc4-sl7-2/` (Rev. 2: + Speaker-Limit + hamoa-USB-PHY + i2c8-Touchscreen) und **`7.0.0-rc4-sl7-3/` (Rev. 3, fertig gebaut 13.09.2026 17:09: + spi10-Touchscreen + Touchpad-Reset-Fix + iris-Videodecoder + CPU-Thermal-Drosselung)** mit je `linux-image` (156 MB), `linux-headers` (9,8 MB), `config-7.0.0-rc4-sl7`, `x1e80100-microsoft-romulus13.dtb` (Rev. 3: 227 316 Bytes), `romulus15.dtb`, `vmlinuz-7.0.0-rc4-sl7.stubble` (21,1 MB, 32 `.dtbauto`-Sektionen), `SHA256SUMS`; `sl7-firmware-msi-26100_26.053.36539.0.tar.xz` (**20 MB, seit 13.09.2026 17:03 inkl. Video-Firmware**) + `.sha256` + `.list.txt`; `sl7-mac_1.0.2_all.deb`; `ellx-iptsd/` (`iptsd_3.1.0-1_arm64.deb`, `91-calibration-045E-0C77.conf`, `instructions.txt`); `ellx-fixes/` (`display-fix`, `trackpad`); `sl7-install-on-laptop.sh` (Ziel-Installer) |
| `hardware/` | `SL7-Hardware-Dump.ps1` – auf dem Surface unter Windows ausführen; sammelt PnP-IDs, Treiber, ACPI-Tabellen aus der Registry, EDID, Firmware-Blobs aus dem DriverStore, MAC-Adressen, Partitionen, Batterie, `powercfg /a`, Secure-Boot/TPM-Status |
| `gits/` | Community-Repos: `giantdwarf17_linux-surface-laptop-7` und `bryce-hoehn_linux-surface-laptop-7` (gleiches Repo, umgezogen), `linux-surface-laptop-7-main` (alte README-Kopie, Stand 06.08.2026, mit `patches/`, `fix-board-2-wifi.sh`, `romulus-firmware-extract.sh`), `dwhinham_linux-surface-pro-11`, `valeronm_sl7-mac`, `alex-lentz_iptsd` |
| ISOs (außerhalb des Projektordners) | `Downloads\questing-desktop-arm64+x1e.iso` (Ubuntu-Concept-Image 20260314, 25.10-Basis, Kernel 6.19.0-13-qcom-x1e); `S:\Surface fedora\`: `Fedora-KDE-Desktop-Live-44-1.7.aarch64.iso`, `Fedora-KDE-SurfaceLaptop7-44.aarch64.iso` (eigener Umbau vom Mai 2026 mit GRUB-Snapdragon-Fixes), nochmals `questing-desktop-arm64+x1e.iso`. Die alte `Ubuntuconcept.iso`, `Beschreibung.txt` und `Links.txt` liegen nicht mehr im Projektordner. |
| WSL (`/work/sl7/`) | `kernel/ellx-7.0-sl7` (ELLX-Tree, Arbeitszweig `sl7-build` auf Tag 7.0.0-rc4-12), `kernel/concept-qcom-x1e-7.0` (Ubuntu-Concept-Referenz), `out/`, `stubble/`, `firmware/` (MSI entpackt, Staging), `chroot-arm64/` (Ubuntu 26.04 arm64 via debootstrap), `patches/community/` |

### 1.3 Stand der Community (Kurzfassung)

- **Launchpad-Bug #2084951** („[X1E] Add support for Surface Laptop 7", ubuntu-concept) ist seit dem 21.07.2025 inaktiv (111 Nachrichten, keine Kommentare aus 2026). Er taugt nur noch als Archiv für die Rezepte von 2024/2025.
- **Aktuelle Diskussion:** GitHub `linux-surface/linux-surface#1590` (Kommentare bis 12.09.2026) und das Community-Repo `bryce-hoehn/linux-surface-laptop-7` (ehemals giantdwarf17; letzter Push 06.08.2026). Der Repo-Maintainer hat sein Gerät verkauft (Issue #12 „Maintainer Needed", 28.01.2026), Hauptbeitragender OliW07 (Kamera/libcamera, dwc3-Patches) wechselt zu Framework, orvitpng (nix1e) hat sein Gerät im September 2026 verkauft. Das linux-surface-Wiki führt den SL7 unter „Unsupported – see bryce-hoehn/linux-surface-laptop-7".
- **ELLX** (ProgrammerIn-wonderland): Kernel-Repo mit einzigem Tag 7.0.0-rc4-12, letzter Push 14.05.2026; Prebuilts, `microsoft-firmware.tar.xz` (14.05.2026), iptsd-Deb und Fixes auf public.hgci.org; Installer-ISO `surface-laptop-7-20260610.iso` (2.236.123.136 Bytes, 11.06.2026) mit README-Warnung (01.07.2026). Der ELLX-Autor hat sich seine Lautsprecher zerstört und ein neues Gerät gekauft.
- **Ubuntu:** 26.04 LTS (23.04.2026) hat erstmals ein offizielles generisches arm64-Desktop-ISO für „Snapdragon based WoA devices"; 26.04.1 vom 26.08.2026. Für den SL7 gibt es dazu **Primärberichte** (Abschnitt 5.1). Das Concept-PPA `~ubuntu-concept/x1e` liefert seit 09.09.2026 `linux-qcom-x1e 7.2.0-18.18` für resolute (26.04) – neuere Basis, aber ohne die SL7-Out-of-tree-Teile.
- **Mainline:** Romulus-DTs seit v6.12; es fehlen upstream weiterhin Touchpad (hid-over-spi/QSPI), Touchscreen, Kamera-DT, dwc3-Resume-Quirk, ath12k-rfkill-Workaround.

---

## 2 Hardware-Inventar

Basis: lokaler Romulus-DT (ELLX-Stand) abgeglichen mit dem Mainline-dtsi (torvalds/master, 13.09.2026), Microsoft Learn Tech Specs (29.09.2025), iFixit Chip-ID (22.06.2024, X-Plus-Gerät), Notebookcheck (04.07.2024). Martins Gerät ist die **X1E-80-100**-Variante (12 Kerne); im 13,8" wird auch der X1P-64-100 (10 Kerne) verkauft.

| Komponente | Chip | Kernel-Treiber | Firmware | Status Linux |
|---|---|---|---|---|
| SoC | Qualcomm Snapdragon X Elite X1E80100 (12 Oryon-Kerne, 3 Cluster), Die-Name „8380" (Firmware-Dateinamen) | ARCH_QCOM, cpufreq über SCMI (`scmi-cpufreq`) + `qcom-cpucp-mbox`, Interconnect x1e80100 | – | funktioniert; cpufreq-Treiber-Bindung auf dem Gerät noch zu prüfen |
| GPU | Adreno X1-85 (a741 in Mesa freedreno_devices.py; 3,8 TFLOPS lt. Notebookcheck) | `drm/msm` (DRM_MSM=m) | Zap-Shader `qcom/x1e80100/microsoft/qcdxkmsuc8380.mbn` (nur aus MSI/ELLX) + generisch `qcom/gen70500_sqe.fw`, `gen70500_gmu.bin` (linux-firmware) | funktioniert mit Zap-Shader; ohne: llvmpipe |
| RAM | LPDDR5x-8448 onboard, 16/32/64 GB (Micron MT62F1G32D2DS-023 auf dem iFixit-Board) | – | – | ok; 64-GB-Modelle brauchten früher `cutmem` in GRUB (seit Image 2024-12-05 gefixt) |
| SSD | M.2 2230 NVMe PCIe Gen4 x4 an `pcie6a` (Regler tlmm 18, Reset tlmm 152, Wake tlmm 154); Testgerät Notebookcheck: Samsung PM9B1 512 GB (modellabhängig) | `nvme`, `pcie-qcom` (PCIE_QCOM=y) | – | funktioniert; SSD austauschbar |
| Display | Sharp LQ138P1JX61 IPS 2304x1536 3:2, bis 120 Hz, 600 nits, 1400:1 (MS) / 1409:1 (gemessen), ohne PWM; eDP an `mdss_dp3`, 4 Lanes bis HBR3 (8,1 GHz), Panel-Regler tlmm 70 | msm DPU/DP, `panel-edp` | – | funktioniert; „quiet splash" kann schwarzes Bild erzeugen |
| Backlight | pwm-backlight über `pmk8550_pwm`, Enable `pmc8380_3` gpio4 | `pwm-backlight`, `pwm-qcom-lpg` | – | funktioniert (Community ✅) |
| Touchscreen | ITCH MSHW0468 (Touch-Controller); ACPI: Gerät GTCH mit `_CID PNP0C51` (= HID-over-SPI) an `\_SB.SP11` = QUP1 SE2 (`spi10`). Alternativ-Hypothese: HID-over-I2C an `i2c8` @0x34 | `spi-hid` (out-of-tree) bzw. `i2c-hid-of`; Userspace iptsd | – | **experimentell**: kein DT-Node in Mainline; ab Rev. 3 liegen **beide** DT-Varianten im DTB (Abschnitt 6.9); Touch funktioniert im UEFI/GRUB |
| Touchpad | HID-over-SPI an `spi19` (QUP2 SE3 als QSPI, 20 MHz, Read-Opcode 0xEB, 8 Dummy-Clocks, GPI-DMA `gpi_dma2`), IRQ tlmm 3, Reset tlmm 120 (gpio65 ab Rev. 3 aus den Reset-States entfernt), `vreg_ts_5p0` mit `regulator-boot-on`; HID-ID 045E:0C77 | `spi-hid` (ELLX, Surface-Duo-Treiber 2022) + gepatchte `spi-geni-qcom.c`/`gpi.c` (QSPI-„Protokoll 9"-Hack); iptsd (alex-lentz-Fork) | – | funktioniert nur mit ELLX-Stack + iptsd + Kalibrierung; nicht Mainline |
| Tastatur / EC | Surface Aggregator Module (SAM), EC = NXP MIMXRT633SFFOB (Cortex-M33 + HiFi4) an `uart2`, 4 MBaud, IRQ tlmm 91 (edge-rising) | `surface_aggregator` (serdev), `_registry`, `_hub`, `surface_hid`, `surface_kbd` | – | funktioniert (Mainline-DT) |
| WLAN | Qualcomm WCN7850 (Modul WCN7851-501 / FastConnect 7800, Wi-Fi 7) an `pcie4` als PCI 17cb:1107; `qcom,wcn7850-pmu` (wlan-enable tlmm 117, bt-enable tlmm 116, VREG_WCN_3P3 tlmm 214) | `ath12k` (=m), `wcn7850-pmu` | `ath12k/WCN7850/hw2.0/{amss.bin,m3.bin,board-2.bin}`; board-2.bin **mit SL7-Eintrag** nötig | funktioniert mit rfkill-Hack + gepatchter board-2.bin; MAC zufällig → sl7-mac |
| Bluetooth | WCN7850 BT an `uart14`, `qcom,wcn7850-bt`, 3,2 MBaud, aus wcn7850-pmu-LDOs | `hci_qca`/`btqca` (BT_QCA=m, BT_HCIUART_QCA=y) | `qca/hmtbtfw20.tlv` (RAMPATCH) + `qca/hmtnv20.bin` (+ `.b10f/.b112/.b201/.b202`), Version 2.0.1-00349, aus Ubuntus `linux-firmware` | funktioniert (Community-Issue #6 geschlossen 18.05.2026); MAC zufällig → sl7-mac |
| Audio-Codec | Qualcomm WCD9385 (Reset tlmm 191; Soundwire `swr1` RX, `swr2` TX; MBHC-Headset-Erkennung 3,5-mm-Klinke) | `snd_soc_wcd938x(_sdw)`, `soundwire-qcom` | ADSP-Firmware (siehe Remoteprocs) | funktioniert; Kopfhörer nutzbar – aber **nur solange die WSA-Module geladen sind** (Abschnitt 6.5) |
| Lautsprecher | 2x WSA8845 Smart-Amps (`sdw20217020400`, swr0 @0,0 links / @0,1 rechts, gemeinsamer Reset `lpass_tlmm 12`); Soundkarte `qcom,x1e80100-sndcard` „X1E80100-Romulus" über q6apm | `snd_soc_wsa884x`, `snd_soc_x1e80100`, LPASS-Makros, q6apm | ADSP; Topologie `qcom/x1e80100/X1E80100-Romulus-tplg.bin` (upstream seit 29.09.2025) | **nutzbar mit Kernel-Volume-Limit** (Rev. ≥ 2: Digital −3 dB, PA 0 dB) und Hausregeln (max. 70 %, nie „Pro Audio"); keine aktive Speaker-Protection → Abschnitt 6.5 |
| Mikrofone | 2 DMICs am VA-Makro | `snd_soc_lpass_va_macro` | ADSP | funktioniert; Verzerrung (#20) war ein Fehler auf OliW07s eigenem Branch, gelöst 17.07.2026 |
| USB-C (2x, links; hinten = `usb_1_ss0`, vorne = `usb_1_ss1`) | dwc3-Host, eUSB2-Repeater in SMB2360_0/_1, Parade PS8830-Retimer an `i2c3` @0x08 (Reset pm8550 gpio10) bzw. `i2c7` @0x08 (Reset tlmm 176), Orientation über pmic-glink (tlmm 121/123), DP 1.4a Alt-Mode über `mdss_dp0/dp1`; Microsoft: USB4 | `dwc3-qcom`, `phy-qcom-qmp-combo`, `phy-qcom-snps-eusb2`, `ps883x` (TYPEC_MUX_PS883X=m), `ucsi_glink`, `pmic_glink_altmode` | ADSP (`battmgr.jsn` u. a. für PD/UCSI) | USB 3.x + DP-Alt-Mode ja; **kein USB4/Thunderbolt-Tunneling**; an TB4-Docks nur PD + USB2 (Abschnitt 6.13) |
| USB-A (rechts) | USB 3.1 Gen2 über `usb_mp` MP1 + NXP PTN3222 eUSB2-Repeater an `i2c5` @0x4f (Reset tlmm 7) | `dwc3`, `phy-nxp-ptn3222` (PHY_NXP_PTN3222=m) | – | funktioniert; nach Resume Reinit nötig (dwc3-Patches) |
| Surface Connect | `usb_mp` MP0 + eUSB2-Repeater SMB2360_2; Laden über PD | `dwc3`, `phy-qcom-eusb2-repeater` | – | Laden ja; USB/Display über Surface Connect „not tested" (Community) |
| Kopfhörerbuchse | 3,5 mm über WCD9385 MBHC | s. Codec | – | nutzbar |
| Kamera (RGB) | OmniVision OV02C10 2 MP an `cci1_i2c1` @0x36, `csiphy4`, 2 Lanes, 400 MHz, MCLK4 19,2 MHz, Reset tlmm 237, PM8010-LDOs (L5M 2,8 V / L1M 1,2 V / L3M 1,8 V); Kamera-LED tlmm 225 (in Mainline) | `ov02c10` (VIDEO_OV02C10=m, Treiber Mainline seit 6.15), `qcom-camss`, `cci`; libcamera + ov02c10.yaml-Tuning | – | funktioniert mit DT-Patch (im ELLX-Tag); Restprobleme Grünstich/Strobing; DT-Node nicht Mainline (Patch v2 Oliver White 09.04.2026 wartet) |
| Video-Codec (HW) | Qualcomm iris (`video-codec@aa00000`, compatible `qcom,x1e80100-iris`, Knoten liegt in `hamoa.dtsi`) | `qcom-iris` (VIDEO_QCOM_IRIS=m) | `qcom/x1e80100/microsoft/Romulus/qcvss8380.mbn` (aus dem MSI; seit 13.09.2026 im eigenen Firmware-Paket, zusammen mit `qcvss8380_pa.mbn` und `qcav1e8380.mbn`) | **ab Rev. 3 im DT aktiviert** (`status = "okay"` + `firmware-name`); Bindung auf dem Gerät noch zu prüfen (Abschnitt 7.5) |
| IR-Kamera (Windows Hello) | Sensor auf Romulus nicht identifiziert (kein DT-Node); auf Purwa/Zenbook A14 ist es Himax HM1092 (Treiberserie 10.06.2026, nicht gemergt) | – | – | **nicht unterstützt** (unverifiziert, welcher Sensor) |
| Akku / Laden | 54 Wh nominal / 52 Wh min (4755 mAh); Charger-ICs SMB2360-002 / SMB2361-002; 39-W-Netzteil, Fast Charge ab 65 W via Surface Connect oder USB-C PD | `qcom_battmgr` über pmic-glink (BATTERY_QCOM_BATTMGR=m), `ucsi_glink` | ADSP-Firmware + `battmgr.jsn` (aus MSI/ELLX) | funktioniert nur mit ADSP-Firmware; ohne: EAGAIN/keine Anzeige |
| PMICs | PMC8380-001, PMC8380VE-001, PMC1010H-001-02/-06 (Charge Pump & Buck; DT-/Treibername `qcom,pm8010`), PMK8550-Funktionen (PWM, RTC) | `qcom-spmi-pmic`, `pwm-qcom-lpg`, `rtc-pm8xxx` | – | ok |
| RTC | PMIC-RTC (Treiber `rtc-pm8xxx`, RTC_DRV_PM8XXX=m) bzw. EFI-RTC; kein RTC-Node im Board-DTSI | `rtc_pm8xxx` / `rtc_efi` | – | **unklar**: Community-README ✅, Issue #8 aber ohne Fix geschlossen („RTC time: n/a") – auf dem Gerät prüfen |
| Lid | Hall-Sensor an tlmm 2 als `gpio-keys` SW_LID, wakeup-source | `gpio-keys` (INPUT_GPIO_KEYS) | – | funktioniert |
| Sensoren | Microsoft nennt nur „Ambient color sensor"; im DT unidentifizierte I2C-Geräte `i2c0` @39/@3e/@44 (100 kHz) und `i2c4` @18/@2c/@2e | – | – | **nicht unterstützt** |
| TPM / Pluton | Microsoft Pluton TPM 2.0 im SoC; kein diskreter TPM-Chip (iFixit); DT reserviert tlmm 44–47 „SPI (TPM)" (firmware-eigen), kein Linux-TPM-Node | – | – | **nicht verfügbar** unter DT-Boot (unverifiziert) → keine TPM-LUKS-Entsperrung planen |
| microSD | Realtek RTS5261 an `pcie3` (Gen1 x1) – nur im 15"-Modell; im 13,8" ist pcie3 vermutlich unbestückt | `rtsx_pci` | – | entfällt beim 13,8" |
| Boot-Flash | Macronix MX25U51293GZ4I40 (64 MB, UEFI) + MX25U1633FZUI (2 MB, EC) | – | – | nicht von Linux angesprochen |
| Lüfter / Thermik | Thermalmodul mit Lüfter (Microsoft: austauschbar), EC-gesteuert; SoC-Temperatursensoren über `tsens` | `qcom_tsens` (QCOM_TSENS=y), `qcom_lmh` (=m), CPU-Cooling über `cpufreq` (CPU_THERMAL=y), Governor step_wise/power_allocator; `surface_fan` **nicht** in der Config | – | Lüfter läuft EC-autonom; **ab Rev. 3 drosselt der Kernel die CPUs bei 85 °C** (passive Trips + `#cooling-cells`, Abschnitt 6.15); Lüftersteuerung unter Linux weiterhin unverifiziert |
| Remoteprocs | ADSP (Audio, Batterie/PD, Sensoren) und CDSP | `qcom_q6v5_pas`, `pd-mapper` | `qcom/x1e80100/microsoft/Romulus/{qcadsp8380.mbn, adsp_dtbs.elf, qccdsp8380.mbn, cdsp_dtbs.elf}` + `*.jsn` | funktioniert mit MSI-/ELLX-Firmware |
| Virtualisierung | Firmware startet Linux in EL1 | KVM=y in der Config, aber ohne EL2 wirkungslos | – | **kein /dev/kvm**; EL2 nur über TravMurav/slbounce (Secure Launch) + Kernel-Patch (`has_cntpoff()` → false) – optionales Nebenprojekt |

**Anmerkungen**

- *Mainline-Abgleich (torvalds/master, 13.09.2026):* vorhanden sind SAM-EC, ADSP/CDSP-Firmware-Namen, Lid, PS8830/PTN3222, WCN7850-PMU/Wi-Fi/BT, Sound (WSA8845 + DMICs), eDP, Kamera-LED, PCIe-Port-Knoten sowie der iris-Knoten in `hamoa.dtsi` (dort ohne `firmware-name`, `status = "disabled"`). Es **fehlen** ov02c10-Kamera, spi19-Touchpad (hid-over-spi), jeder Touchscreen-Knoten, `snps,reinit-phy-on-resume` und CPU-Cooling-Trips (die CPU-Zonen in `hamoa.dtsi` haben nur critical-Trips bei 115 °C). `romulus13.dts` ist in master ein reiner Stub – die lokalen Touchscreen-Patches kollidieren daher nicht mit Mainline-Inhalten.
- *ACPI-Bezeichner:* Touchscreen = GTCH (`_CID PNP0C51`), an SP11 (QUP1 SE2); der Touchpad-QUP meldet SE-Protokoll 9 (native QSPI, 6 Pins), Windows lädt dafür `SurfaceUpdate/spiextrom8380/BSRC_QSPI_ROM.bin`.
- *Panel-EDID:* shenki meldete im Nov. 2024 „Panel SHP 0x1572 unbekannt" – das Panel läuft trotzdem über panel-edp mit generischen Timings.
- *Firmware-Blob-Sicht (MSI):* Die **Video-Firmware `qcvss8380.mbn` / `qcvss8380_pa.mbn` / `qcav1e8380.mbn` ist seit dem 13.09.2026 Bestandteil unseres Firmware-Pakets** (iris nutzt `qcvss8380.mbn`). Ungenutzt bleiben Bluetooth `hpbtfw21.tlv`, Windows-WLAN `wlanfw20.mbn`, Kamera-ISP `CAMERA_ICP.mbn`, EVA `evass.mbn`, HDCP – siehe Abschnitt 4.3.
- *Nicht ermittelt:* Tastaturbeleuchtung, Fn-Tasten, fwupd/LVFS-Status – keine Quellen mit konkretem Linux-Status gefunden (die Tastatur läuft über SAM; die Beleuchtung dürfte ebenfalls ein SAM-Subsystem sein, unverifiziert).

---

## 3 Kernel-Entscheidung

### 3.1 Warum ELLX 7.0.0-rc4-12 als Basis

| Kandidat | Stand 13.09.2026 | Bewertung für Romulus13 |
|---|---|---|
| **ELLX-Kernel** (ProgrammerIn-wonderland/ELLX-Kernel, Tag `7.0.0-rc4-12`, Commit 0e9944fa4 vom 14.05.2026 „webcam dtb patch for Surface Laptop 7") | Fork des Ubuntu-Concept-Trees (Branch qcom-x1e-7.0 = 7.0.0-rc4, Packaging linux-qcom-x1e 7.0.0-22.22 questing, 26.03.2026) + „scuggo's SL7 changes"; seit 14.05.2026 kein Push | **gewählt.** Einzige Basis, in der alle SL7-Out-of-tree-Teile nachweislich zusammen laufen: `drivers/hid/spi-hid` (Surface-Duo-HID-over-SPI, Maximilian Luz 2022), ath12k-rfkill-„Surface Laptop 7 Enumeration hack", OV02C10-Kamera (DTS + Treiberanpassung), `spi-geni-qcom.c`-QSPI-Hack, `dma/qcom/gpi.c`, `typec/mux/ps883x.c`. Ubuntu-Packaging (annotations, Flavour qcom-x1e) ist enthalten. |
| Ubuntu-Concept `linux-qcom-x1e 7.2.0-18.18` (PPA ~ubuntu-concept/x1e, resolute, 09.09.2026) | Neuere Basis (7.2), gepflegt von tobhe/Canonical; Quellbranch nicht identifiziert (`qcom-x1e-7.2` existiert nicht, 404) → Quellpaket per `dget`/`pull-ppa-source` aus der PPA | **mittelfristig.** SL7-Teile (spi-hid, rfkill-Hack, Kamera, QSPI) müssten rebased werden; Speaker-Limit-Patch und hamoa-USB-PHY-Fix dort prüfen (7.2 enthält den PHY-Fix **nicht**). |
| Mainline 7.2.5 / 7.3-rc2 | Romulus-DT vollständig bis auf Touch/Kamera/dwc3; USB-PHY-Supply-Fix ab 7.3-rc1 | Kein SL7-Vorteil gegenüber Concept 7.2, verliert Ubuntu-SAUCE-Patches und Packaging; nur sinnvoll, wenn die dwc3-Lösung auf den upstream-`needs_full_reinit`-Mechanismus (7.1) umgestellt werden soll. |
| jhovold/linux (wip/x1e80100-6.16) | letzter Push 19.09.2025, kein 6.17+/7.x | **tot** als Basis – alles Wesentliche ist inzwischen Mainline. |
| Ubuntu-generic `linux 7.0` (26.04) via stubble | bootet X1E (Phoronix 24.07.2026, Acer Swift), aber GPU auf llvmpipe (MSM-Init-Fehler), Akku tot; keine SL7-Patches | ungeeignet als Alltagskernel; genau richtig als **Installer-Kernel** (Abschnitt 5). |
| Fedora-/Arch-ARM-Mainline-Kernel | reines Mainline | ohne spi-hid keine Tastatur-/Touchpad-Nutzung des Romulus13 (spi-hid ist nicht Mainline; Serie v4 09.06.2026 nicht „applied" – unverifiziert über v3 hinaus). |

Entscheidend gegen ELLX-Prebuilts und **für den Eigenbau**: ELLX-Tree und beide Concept-Branches (qcom-x1e-7.0, resolute-x1e) enthalten den Ubuntu-Speaker-Limit-Patch (LP #2149808) **nicht** (lokal per grep verifiziert, `build/inspect/wsl-check-safety.sh`). Der Eigenbau erlaubt außerdem das Backporten des USB-PHY-Supply-Fixes, die Touchscreen-Experimente, den iris-Videodecoder und die CPU-Thermal-Trips.

### 3.2 Angewendete Patches (Arbeitszweig `sl7-build` auf Tag 7.0.0-rc4-12)

**Kanonischer Stand seit Rev. 3:** `build/patches-upstream/sl7-tree-full.diff` – der komplette Diff gegen den Tag (571 Zeilen, 6 Dateien: `drivers/usb/dwc3/core.c`, `core.h`, das dwc3-DT-Binding, `x1e80100-microsoft-romulus.dtsi`, `x1e80100-microsoft-romulus13.dts`, `sound/soc/qcom/x1e80100.c`). Angewendet wird er mit `build/wsl-apply-sl7-patches.sh` (frischer Checkout des Tags + `git apply`), danach `PKGREV=<n> bash wsl-build-kernel.sh`. Grund für die Umstellung: die handgeschriebenen Einzelpatches `0011`/`0012` hatten falsche Hunk-Zähler und ließen sich nicht zuverlässig anwenden. Die Einzelpatchdateien im selben Ordner bleiben als **Herkunftsnachweis** liegen, sind aber nicht mehr der Anwendungsweg.

| Nr. | Patch / Änderung | Herkunft / Autor / Datum | Inhalt | Upstream-Status | Paket-Rev. |
|---|---|---|---|---|---|
| – | im Tag enthalten | ELLX | spi-hid, rfkill-Hack, Kamera-DT (= Community-0004), ov02c10.c-Anpassung (ersetzt defektes Community-0005), QSPI-Hack (`spi-geni-qcom.c`, `gpi.c`), ps883x | nicht upstream (spi-hid-Serie v4 Jingyuan Liang 09.06.2026 offen; OV02C10-DT v2 Oliver White 09.04.2026 offen; QSPI-Treiber von Qualcomm angekündigt 01.07.2026, kein Patch bis 09/2026) | 1–3 |
| – | Community `upstreamed/0003-fix-duplicate-battery.patch` | OliW07, April 2026 (PR #15, 01.05.2026) | `surface_aggregator_registry.c`: surface_battery/surface_charger beenden sich bei qcom_battmgr (keine Duplikat-Batterie) | Community markiert „upstreamed" **(unverifiziert)** | im Tag |
| 1–3 | `dwc3-usb/0001…0003` (Community `patches/community/outgoing/dwc3-usb/`) | Oliver White (OliW07), 02.06.2026 | DT-Binding `snps,reinit-phy-on-resume`, Quirk in `dwc3/core.c`, Property im Romulus-dtsi → USB (auch USB-A, externe Tastatur) nach Standby wieder initialisieren | **nicht upstream** (dwc3/core.c seit 2025-10 nur `needs_full_reinit`-Flag NXP 25.02.2026) | 1 |
| 4 | `ubuntu-speaker-limit.patch` | Ubuntu SAUCE „ASoC: qcom: x1e80100: limit speaker volumes" (LP #2149808, Fix Released; im Archiv-`linux` resolute ab 7.0.0-15.15, Changelog 22.04.2026, ausgeliefert seit 29.04.2026; stonking 7.2.0-5.5, 18.08.2026), entnommen aus resolute linux 7.0.0-38.38 master-next (04.09.2026) | `snd_soc_limit_volume`: WSA/WSA2 RX0/RX1 Digital Volume = 81 (−3 dB), Spkr/Woofer/Tweeter PA Volume = 6 (0 dB) – setzt `platform_max` am ALSA-Regler, wirkt daher auch gegen `amixer` und das PipeWire-Profil „Pro Audio" | Ubuntu-only; fehlte im ELLX-Tree und in beiden Concept-Branches; ob linux-qcom-x1e 7.2.0-18.18 ihn hat, ungeprüft | 2–3 |
| 5 | `hamoa-usb-qmp-phy-supplies-romulus-only.patch` (Vollversion `hamoa-usb-qmp-phy-supplies.patch`) | upstream 4458dcd „arm64: dts: qcom: hamoa: Fix swapped USB QMP PHY vdda-phy/vdda-pll supplies", Manivannan Sadhasivam, Author 03.08.2026, Commit 05.08.2026 | nur der romulus.dtsi-Hunk: `usb_1_ss0/ss1_qmpphy`, `usb_mp_qmpphy0/1` – vdda-phy/vdda-pll (0,88 V / 1,2 V: l1j/l2j, l2d/l2j, l3c/l3e) getauscht | **in v7.3-rc1**, nicht in v7.2/7.2.5 (Stable-Backport nicht nachgewiesen) | 2–3 |
| 6 | `0010-romulus13-touchscreen-hid-over-i2c.patch` (Variante A) | linux-input „[PATCH 2/2] arm64: dts: qcom: microsoft-romulus13: enable touchscreen", fQwQf, 07.09.2026; lokal um pinctrl ergänzt | `i2c8` 400 kHz, `touchscreen@34` `hid-over-i2c`, hid-descr-addr 0x0000, IRQ tlmm 38 level-low (pull-up), Reset tlmm 31 active-low (bias-disable) | **abgelehnt**: Maintainer Krzysztof Kozlowski „Drop" (Self-Tested-by), Bot bemängelte fehlendes pinctrl; **EXPERIMENTELL**, die unwahrscheinlichere Variante | 2–3 |
| 7 | Touchscreen `spi10` (Variante B) – nur im Gesamt-Diff | horizontblau in linux-surface#1590 (25.08.2026, Writeup horizontblau.de) + orvitpng/nix1e `devicetree/hardware/touch/touchscreen.dtsi` (01.07.2026) | HID-over-SPI auf `spi10` (QUP1 SE2, `qcom,geni-spi-qspi`, 40 MHz, Read-Opcode 0xEB, 8 Dummy-Clocks, `gpi_dma1`, IRQ gpio51, Reset gpio48, 5 V über `vreg_ts2_5p0`/gpio64) | nicht upstream; horizontblau meldet „Touchscreen läuft" (ELLX + iptsd); Beiträge umstritten (KI-Vorwurf), Pins decken sich aber mit orvitpngs unabhängigen DTs und dem ACPI-Bezeichner GTCH/SP11 → **EXPERIMENTELL, plausibel** | 3 |
| 8 | Touchpad-Reset-/Regulator-Fix („Wedge") – nur im Gesamt-Diff | horizontblau 29.08.2026, deckungsgleich mit orvitpng `touchpad.dtsi` | `romulus.dtsi`: `vreg_ts_5p0` bekommt `regulator-boot-on`; gpio65 aus den `spi19`-Reset-States entfernt (nur noch gpio120) | nicht upstream | 3 |
| 9 | iris-Videodecoder – nur im Gesamt-Diff | eigene Ableitung; Vorbild andere X1E-Boards mit Vendor-Firmware | `&iris { firmware-name = "qcom/x1e80100/microsoft/Romulus/qcvss8380.mbn"; status = "okay"; }` – aktiviert den HW-De-/Encoder (`video-codec@aa00000` aus `hamoa.dtsi`), CONFIG_VIDEO_QCOM_IRIS=m | Knoten upstream vorhanden, Romulus-Aktivierung nicht | 3 |
| 10 | CPU-Thermal-Drosselung – nur im Gesamt-Diff | Vorbild scuggo/x1e-nixos `surface-laptop-7-thermal.dts` | `#cooling-cells` für cpu0…cpu11 und passive Trips **85 °C / 5 °C Hysterese** in den 12 Zonen `cpu0-0-top-thermal` … `cpu2-3-top-thermal` → 20 `cooling-device`-Einträge im DTB (Mainline hat dort nur critical bei 115 °C); CONFIG_CPU_THERMAL=y, QCOM_TSENS=y, Governors step_wise/power_allocator vorhanden | nicht upstream | 3 |

Beide Touchscreen-Varianten (i2c8 und spi10) liegen ab Rev. 3 gleichzeitig im DTB; auf dem Gerät zeigt `dmesg`, welche enumeriert. Falls die i2c8-Variante Probleme macht (Bus-Timeouts, spurious IRQs), den Node per Patch auf `status = "disabled"` setzen. Rev. 3 baut sauber: `romulus13.dts` 377 Zeilen, DTB 227 316 Bytes.

Alle Community-Patches von `/mnt/c` hatten CRLF-Zeilenenden: `git apply` scheitert, `patch -p1` (bzw. `sed 's/\r$//'`) funktioniert – die Build-Skripte erledigen das.

### 3.3 Kernel-Cmdline

| Parameter | Verwendung | Begründung / Quelle |
|---|---|---|
| `clk_ignore_unused pd_ignore_unused` | **gesetzt** (Installer: `/etc/default/grub.d/90-sl7.cfg`; auch im Fallback-Eintrag) | verhindert, dass CCF/genpd nach late_init Clocks/Power-Domains abschaltet, die von firmware-initialisierter Hardware noch gebraucht werden („resource handover"); das Ubuntu-x1e-ISO 20260314 setzt sie per `smbios`-Erkennung für „Snapdragon", jhovold ebenso. **Widerspruch:** shenki (Launchpad #40, 27.11.2024, frühes oracular-Image) hielt das *Entfernen* der beiden Parameter für entscheidend; das bezog sich auf einen 6.11/6.12-Stand. Empfehlung: mit Parametern starten; bei Boot-Hängern beide testweise entfernen. |
| `arm64.nopauth` | **nicht gesetzt** | X13s-Relikt (Firmware ohne korrekte Pointer-Auth); das Ubuntu-x1e-ISO setzt es für Snapdragon, jhovolds T14s-Wiki nicht. Nur nachrüsten, wenn der Boot ohne hängt. |
| `efi=noruntime` | **nicht gesetzt** | jhovold-Standard wegen EFI-Runtime-Bugs; Ubuntu-ISO/Installer setzen es nicht. Achtung: ohne EFI-Runtime funktioniert `efivarfs` nicht → `sl7-mac` kann die UEFI-Variable nicht lesen. Nur bei Runtime-Service-Abstürzen nachrüsten. |
| `module_blacklist=snd_soc_wsa884x` | **nur bei `SL7_NO_SPEAKER=1`** | kernelseitig erzwungene Modulsperre, unabhängig von initramfs/modprobe.d. Bedeutet **gar keinen Ton** (Abschnitt 6.5). Im Normalfall nicht gesetzt. |
| `cutmem 0x8800000000 0x8fffffffff` (GRUB-Befehl, keine Cmdline) | nur 64-GB-Modelle | Ubuntu-ISO macht das automatisch (außer im Lockdown); seit Image 2024-12-05 im Concept-GRUB gefixt. |
| `stubble.dtb_override=false` | nur wenn ein stubble-Kernel mit GRUB-`devicetree` kombiniert wird | stubble überschreibt einen vom Bootloader übergebenen DTB (valpackett, 19.08.2026). |
| `quiet splash` | ggf. entfernen | schwarzer Bildschirm auf manchen X1E-Panels (cicorias-Gist 09.09.2026, 15"-Modell). |
| `iommu.strict=0`, `preempt=voluntary` | optional, Messung (Abschnitt 7) | Config hat IOMMU_DEFAULT_DMA_STRICT=y und PREEMPT_DYNAMIC. |

### 3.4 Config-Highlights (`build/out/7.0.0-rc4-sl7-*/config-7.0.0-rc4-sl7`)

Erzeugt aus `debian/scripts/misc/annotations --arch arm64 --flavour qcom-x1e --export` (11 983 Optionen), dann angepasst: `SYSTEM_TRUSTED_KEYS=""`, `SYSTEM_REVOCATION_KEYS=""`, `MODULE_SIG_FORCE=n`, `DEBUG_INFO_NONE=y`, `LOCALVERSION=""` (+ Umgebungsvariable `LOCALVERSION=-sl7`, damit `setlocalversion` kein „+" anhängt), `SPI_HID` und `VIDEO_OV02C10` erzwungen. Kernelrelease `7.0.0-rc4-sl7`.

- **Boot/Image:** EFI_ZBOOT=y (`vmlinuz.efi`), KEXEC_FILE=y, ARM64_4K_PAGES=y, VA/PA 52 Bit + LPA2, ARM64_PSEUDO_NMI=y, MODULE_COMPRESS_ZSTD=y, FW_LOADER_COMPRESS_ZSTD=y (nötig für Ubuntus `.zst`-Firmware), LTO_NONE (GCC 15.2).
- **Scheduler/Power:** HZ_1000, PREEMPT_DYNAMIC (Full als Default), NO_HZ_FULL=y, RCU_LAZY=y, ARM_SCMI_CPUFREQ=y, QCOM_CPUCP_MBOX=m, ARM_QCOM_CPUFREQ_HW=m (Beifang), ENERGY_MODEL=y, schedutil Default, CPU_IDLE_GOV_TEO=y, SCHED_CLUSTER=y, UCLAMP_TASK=y, ARM64_AMU_EXTN=y; QCOM_TSENS=y, QCOM_LMH=m, **CPU_THERMAL=y** (Voraussetzung für die 85-°C-Trips aus Rev. 3), Thermal-Governor step_wise (power_allocator verfügbar); HIBERNATION aus.
- **SL7-Geräte:** SPI_HID=m, I2C_HID_OF=m, HID_MULTITOUCH, SURFACE_AGGREGATOR/_REGISTRY/_HUB=m, SURFACE_HID=m, SURFACE_KBD=m, TYPEC_MUX_PS883X=m, PHY_NXP_PTN3222=m, PHY_QCOM_EUSB2_REPEATER=y, BATTERY_QCOM_BATTMGR=m, UCSI_PMIC_GLINK=m, QCOM_PMIC_GLINK=y, SND_SOC_WSA884X=m, SND_SOC_WCD938X(_SDW)=m, SND_SOC_X1E80100=m, VIDEO_QCOM_CAMSS=m, VIDEO_OV02C10=m, **VIDEO_QCOM_IRIS=m** (ab Rev. 3 auch im DT aktiviert), VIDEO_QCOM_VENUS=m, ATH12K=m, BT_QCA=m, BT_HCIUART_QCA=y, DRM_MSM=m, PCIE_QCOM=y, PHY_QCOM_QMP_PCIE/USB/COMBO=y, USB_DWC3(_QCOM)=y, USB4=m, RTC_DRV_PM8XXX=m, QCOM_ICC_BWMON=m, INTERCONNECT_QCOM_X1E80100=y. **Nicht gesetzt:** SURFACE_FAN.
- **Speicher/FS:** ZSWAP=y (nicht default-on, lzo), ZRAM=m (lzo-rle; zstd/lz4 als Module), ZSMALLOC=y, THP=madvise, ARM64_CONTPTE=y, EXT4 built-in, BTRFS/F2FS/XFS=m, CMA 32 MB, IOMMU_DEFAULT_DMA_STRICT=y, ARM_SMMU_V3=y, KVM=y (wirkungslos in EL1).

### 3.5 DTB-Mechanismus: stubble vs. GRUB-`devicetree`

- **Ubuntu 26.04 (linux-qcom-x1e und linux-generic arm64):** Das Kernel-Image wird mit `ukify build --linux=vmlinuz.efi --stub=/usr/lib/stubble/stubble.efi --hwids=/usr/share/stubble/hwids --sbat=@/usr/share/stubble/sbat --devicetree-auto=<dtb>…` gebaut (`debian/rules.d/2-binary-arch.mk`, `do_stubble=true`, DTB-Liste über `/usr/libexec/stubble/finddtbs.py`). `/boot/vmlinuz-<ver>` ist dann ein UKI-artiges PE mit `.dtbauto`-Sektionen; der Stub wählt den DTB per SMBIOS-HWIDs (Paket `stubble` 9-1; `hwids/x1e80100-microsoft-romulus13.json`, compatible `microsoft,romulus13`). **GRUB braucht keine `devicetree`-Zeile.** Belegt an der questing-x1e-ISO 20260314: `casper/vmlinuz` = 20 MB, 39 Sektionen, enthält „X1E80100-Romulus"; die ISO-`grub.cfg` hat keine devicetree-Zeile, nur `smbios --type 4 --get-string 5` → bei „Snapdragon": `cutmem` und Cmdline `clk_ignore_unused pd_ignore_unused arm64.nopauth`. Das installierte Concept-System (Ubuntu 25.10, 6.19.0-13-qcom-x1e) hat kein `/boot/dtb*`, `/etc/grub.d/10_linux` mit Standard-Upstream-Logik (devicetree nur, wenn `/boot/dtb-<ver>` oder `/boot/dtb` existiert), Initramfs-Generator = **dracut** (`/etc/kernel/postinst.d`: dracut, xx-update-initrd-links, zz-update-grub); `update-initramfs` gibt es im 26.04-arm64-Chroot nicht.
- **ELLX:** baut **ohne** stubble (plain `vmlinuz`, DTBs unter `/usr/lib/linux-image-7.0.0-rc4+/<vendor>/`); dort wirkt eine GRUB-`devicetree`-Zeile direkt (ProgrammerIn-wonderland, 23.08.2026). Launchpad-Berichte über „manuelles GRUB-Editing fürs DTB" beziehen sich auf diesen Weg bzw. auf frühe Concept-Images.
- **Eigener Build:** liefert beides – das plain `vmlinuz` im `.deb` (DTBs unter `/usr/lib/linux-image-7.0.0-rc4-sl7/qcom/`) **und** `vmlinuz-7.0.0-rc4-sl7.stubble` (21,1 MB, 32 `.dtbauto`-Sektionen inkl. romulus13/15; auf dem x86-Host mit systemd-ukify 259.5 + `stubble:arm64`-Stub + `finddtbs.py` gebaut). `sl7-install-on-laptop.sh` setzt das stubble-Image als `/boot/vmlinuz-<ver>` (Original als `.plain` gesichert) und legt einen GRUB-Fallback-Eintrag „SL7 Fallback" mit plain-Kernel + `devicetree /boot/sl7-romulus13.dtb` an. `build/wsl-verify-out.sh` prüft für eine Revision, dass das romulus13-DTB (mit den Rev.-3-Merkmalen `qcvss8380`, `cooling-device`, `touchscreen@0`, `touchscreen@34`) tatsächlich im stubble-Image und im `.deb` steckt, und rechnet die SHA256-Summen nach.
- **Alternative:** TravMurav/dtbloader (EFI-Treiber, DMI-basierte DTB-Auswahl, Surface Laptop 7 gelistet; Install als `/EFI/systemd/drivers/dtbloaderaa64.efi` oder per efibootmgr/`bcfg driver add`, DTBs unter `/dtbloader/dtbs/`, `dtbs/` oder ESP-Root; Secure-Boot-Hash-Prüfung) – nicht nötig, solange stubble funktioniert.
- Test im arm64-qemu-user-Chroot (Ubuntu 26.04 arm64 via debootstrap): `dpkg -i linux-image-7.0.0-rc4-sl7*.deb` OK (postinst-Hooks laufen), DTBs am erwarteten Ort, 7 932 Module, `dracut --force --kver 7.0.0-rc4-sl7` OK. Das gilt auch für Rev. 3.

### 3.6 Wann wechseln?

| Auslöser | Ziel |
|---|---|
| Concept `linux-qcom-x1e 7.2.x` (resolute) mit bestätigtem Speaker-Limit-Patch, und Zeit für den Rebase der SL7-Teile (spi-hid: dann die Upstream-Serie v4 statt des 2022er Luz-Patches; ELLX-Branches `qcom-x1e-6.19-SPIHID`/`use-march-03-HID-SPI` als Referenz) | Concept 7.2 + SL7-Patchsatz; hamoa-USB-PHY-Fix, iris-Aktivierung und Thermal-Trips mitnehmen (nicht in 7.2) |
| spi-hid-Serie „applied" (hid.git for-next, Ziel 7.4) **und** Qualcomm-GENI-QSPI-Treiber upstream | Mainline-nahe Basis (7.4+), nur noch Kamera-/Touchscreen-/Thermal-DT-Overlays lokal |
| Ubuntu-generic arm64 bekommt funktionierende GPU/Akku auf X1E (Phoronix-Regression behoben) | Distro-Kernel als Fallback-Eintrag im GRUB behalten |
| Aktive Speaker-Protection (Feedback/Smart-Amp) upstream | Kernel-Volume-Limit kann gelockert werden – bis dahin bleibt es gesetzt (Abschnitt 6.5) |

---

## 4 Firmware

### 4.1 Übersicht: Datei | Quelle | Zielpfad | Zweck

Alles Eigene liegt **unkomprimiert unter `/lib/firmware/updates/…`**: Der Kernel sucht (`firmware_loader/main.c`) in der Reihenfolge `firmware_class.path`, `/lib/firmware/updates/<release>`, `/lib/firmware/updates`, `/lib/firmware/<release>`, `/lib/firmware` – zuerst den unkomprimierten Namen in allen Verzeichnissen, erst bei ENOENT `.zst` (CONFIG_FW_LOADER_COMPRESS_ZSTD), dann `.xz`. Eine unkomprimierte Datei in `updates/` gewinnt also gegen jede `.zst`-Datei aus Ubuntus `linux-firmware`, und Paket-Updates überschreiben nichts.

| Datei | Quelle | Zielpfad (im Tarball `sl7-firmware-msi-26100_26.053.36539.0.tar.xz`) | Zweck |
|---|---|---|---|
| `qcadsp8380.mbn` (21 940 664 B) + `adsp_dtbs.elf` (73 528 B) | Microsoft-MSI `SurfaceUpdate/` (= ELLX `microsoft-firmware.tar.xz`) | `/lib/firmware/updates/qcom/x1e80100/microsoft/Romulus/` (+ Kopie flach in `microsoft/`) | ADSP-Remoteproc: Audio, Batterie/PD (battmgr), Sensoren – DT-Pfad `remoteproc_adsp` |
| `qccdsp8380.mbn` (3 195 304 B) + `cdsp_dtbs.elf` (40 760 B) | MSI | `…/microsoft/Romulus/` (+ flach) | CDSP-Remoteproc (Compute) – DT-Pfad `remoteproc_cdsp` |
| `adspr.jsn`, `adsps.jsn`, `adspua.jsn`, `battmgr.jsn`, `cdspr.jsn` | MSI | `…/microsoft/Romulus/` (+ flach) | Protection-Domain-/Battmgr-Konfiguration für pd-mapper/qcom_battmgr |
| `qcdxkmsuc8380.mbn` (12 088 B) | MSI | `/lib/firmware/updates/qcom/x1e80100/microsoft/qcdxkmsuc8380.mbn` (DT verlangt **ohne** `Romulus/`; zusätzlich in `Romulus/`) | GPU-Zap-Shader (Adreno X1-85, `memory-region gpu_microcode_mem`); ohne ihn llvmpipe / `VK_ERROR_INITIALIZATION_FAILED` |
| **`qcvss8380.mbn` (2 323 048 B)** | MSI `qcdx8380/` – **neu seit 13.09.2026** | `…/microsoft/Romulus/` (+ flach) | **Video-Firmware für den iris-De-/Encoder**; genau dieser Pfad steht in `&iris { firmware-name = … }` (Rev. 3) |
| `qcvss8380_pa.mbn` (2 323 048 B), `qcav1e8380.mbn` (4 607 848 B) | MSI `qcdx8380/` – **neu seit 13.09.2026** | `…/microsoft/Romulus/` (+ flach) | weitere Video-/AV1-Encoder-Blobs; derzeit von keinem DT-Knoten referenziert, liegen für Versuche bereit |
| `qcdxkmsucpurwa.mbn` (12 088 B) | MSI | wie oben (nur der Vollständigkeit halber) | Zap-Shader für X1P42100 „Purwa" (Surface Pro 12", Surface Laptop 13") – **für Romulus13 irrelevant** |
| `ath12k/WCN7850/hw2.0/board-2.bin` (2 254 080 B) | codelinaro `ath12k-firmware` main (letzter Commit fd7ddeb4, 30.01.2026) + eigener SL7-Eintrag per `ath12k-bdencoder` | `/lib/firmware/updates/ath12k/WCN7850/hw2.0/board-2.bin` | WLAN-Board-Daten (Abschnitt 4.4) |
| `ath12k/WCN7850/hw2.0/amss.bin`, `m3.bin` | Ubuntu `linux-firmware` (`.zst`) | `/lib/firmware/ath12k/WCN7850/hw2.0/` | WLAN-Firmware |
| `qcom/gen70500_sqe.fw`, `qcom/gen70500_gmu.bin` | Ubuntu `linux-firmware` | `/lib/firmware/qcom/` | GPU-Mikrocode/GMU (generisch, unsigniert) |
| `qcom/x1e80100/X1E80100-Romulus-tplg.bin` | Ubuntu `linux-firmware` (upstream seit d5541743, 29.09.2025; zuletzt bfc1d743 10.01.2026) | `/lib/firmware/qcom/x1e80100/` | Audio-Topologie der Soundkarte |
| `qcom/x1e80100/qupv3fw.elf`, generische `adsp.mbn`/`cdsp.mbn` + `*.jsn` | Ubuntu `linux-firmware` | `/lib/firmware/qcom/x1e80100/` | QUP-Firmware; generische ADSP/CDSP werden vom Romulus-DT **nicht** benutzt |
| `qca/hmtbtfw20.tlv`, `qca/hmtnv20.bin` (+ `.b10f`, `.b112`, `.b201`, `.b202`) | Ubuntu `linux-firmware` (Commit 2a8ffa36 Zijun Hu, 09.10.2024, MR !328 gemerged 14.10.2024 von Josh Boyer; `.b201/.b202` am 02.09.2026) | `/lib/firmware/qca/` | Bluetooth WCN7850 (UART), Version 2.0.1-00349 |

Eigenes Paket: `build/out/sl7-firmware-msi-26100_26.053.36539.0.tar.xz` (**20 MB** = 19 995 088 Bytes, Neubau 13.09.2026 17:03 mit der Video-Firmware; **29 Dateien** = 14 Blobs doppelt abgelegt + `board-2.bin`, Liste in `.list.txt`, SHA256 in `.sha256`). Inhalt entspricht dem ELLX-`microsoft-firmware.tar.xz` vom 14.05.2026 **plus** den drei Video-Blobs; wie ELLX legen wir alle Dateien zusätzlich flach unter `qcom/x1e80100/microsoft/` ab.

### 4.2 Microsoft-Treiberpaket (MSI)

- Download-Center „Surface Laptop 7th Edition" (id=106120, „Date Published" 25.06.2026) listet genau eine Snapdragon-Datei: **`SurfaceLaptop7_ARM_Win11_26100_26.053.36539.0.msi`**, Direktlink `https://download.microsoft.com/download/b7ca2c3f-d320-4795-be0f-529a0117abb4/SurfaceLaptop7_ARM_Win11_26100_26.053.36539.0.msi` – lokal per HEAD verifiziert: HTTP 200, **523 874 304 Bytes**, Last-Modified 25.06.2026 (die Webseite zeigt 499,6 MB). 13,8" und 15" Snapdragon teilen sich das Paket.
- Die alte URL aus dem Community-Skript `romulus-firmware-extract.sh` (`…/0a7d6bec-…/…_25.013.35106.0.msi`) liefert **404**. Die Support-Seite nennt als Beispiel `…_25.101.12926.0.msi` und verlinkt auf id=106120.
- Alternative zu MSI + msiextract: Ubuntu/Debian-Paket `qcom-firmware-extract` zieht die Blobs aus der Windows-Partition. Achtung: die in Ubuntu 26.04 enthaltene Version 17 meldet auf neueren X1E-Geräten „Device is currently not supported" (Phoronix brauchte v20 aus dem 26.10-Archiv); shenkis Branch `surface-laptop-7` (27.11.2024) kopiert die 10 Dateien nach `qcom/x1e80100/microsoft/Romulus/` – laut Seitenzusammenfassung auch den Zap-Shader dorthin, was **nicht** zum DT-Pfad passt (unverifiziert, Branch-Quelltext prüfen). Unser Tarball ist deshalb der verlässlichere Weg.

### 4.3 Was das MSI sonst noch enthält (nicht verwendet)

`qcbluetooth8380/hpbtfw21.tlv` (Windows-BT-Firmware; Linux nutzt `qca/hmt*`), `qcwlanhmt8380/{wlanfw20.mbn, phy_ucode20.elf, bdwlan*.elf}` (Windows-WLAN-Firmware, nicht im ath12k-Format), `qccamisp8380/CAMERA_ICP.mbn` (Kamera-ISP), `qceva8380/evass.mbn` (EVA), `qctreeextqcom8380/hdcp*.mbn` (HDCP), `spiextrom8380/BSRC_QSPI_ROM.bin` (Touchpad-QSPI-ROM, wird von Windows geladen).

**Nicht mehr in dieser Liste:** `qcdx8380/{qcvss8380.mbn, qcvss8380_pa.mbn, qcav1e8380.mbn}` – die Video-Blobs sind seit dem 13.09.2026 Bestandteil unseres Firmware-Pakets (Abschnitt 4.1) und werden vom iris-Knoten aus Rev. 3 gebraucht. orvitpng/nix1e nutzt dieselben Blobs für HW-Video (H.264/HEVC-Encode, H.264/HEVC/AV1/VP9-Decode). Das Skript `wsl-extract-firmware.sh` listet alle `.mbn/.jsn/.elf/.tlv` des MSI zur Information.

### 4.4 ath12k `board-2.bin`: Ursache und Fix

- **Ursache:** Der WCN7850 im Surface Laptop 7 meldet die PCI-Subsystem-ID **17cb:1107** (= Device-ID, generisch) mit `qmi-board-id 255`. `board-2.bin` kennt für diese Kombination nur den Referenz-Eintrag `subsystem-vendor=17cb,subsystem-device=3378`. ath12k bricht ab mit `failed to fetch board data for bus=pci,vendor=17cb,device=1107,subsystem-vendor=17cb,subsystem-device=1107,qmi-chip-id=2,qmi-board-id=255` (Launchpad #94, 18.04.2025). Zusätzlich meldet der Chip Hard-Block (rfkill), weil der rfkill-Pin firmwareseitig gesetzt ist (Konrad Dybcio im WCN7850-DT-Commit 09.09.2025) → ELLX-Treiber-Hack in `ath12k/core.c` („Surface Laptop 7 Enumeration hack").
- **Fix:** Board-Daten des 3378-Eintrags per `ath12k-bdencoder` (qca-swiss-army-knife) zusätzlich unter dem 1107-Namen eintragen (Launchpad #95, 22.04.2025, Thayalan; Community `fix-board-2-wifi.sh`). `wsl-extract-firmware.sh` macht genau das automatisch (Python-Schritt auf `board-2.json`) und legt das Ergebnis unkomprimiert nach `/lib/firmware/updates/ath12k/WCN7850/hw2.0/board-2.bin`.
- **Upstream-Status (13.09.2026, per codelinaro-/GitLab-API geprüft):** Der letzte board-2.bin-Commit fd7ddeb4 (30.01.2026, Jeff Johnson) fügt nur `1eac:8004` und `1eac:8001` (QCNCM865-Module) hinzu; kein Commit nennt 17cb:1107, 3378, Surface oder Microsoft – weder in codelinaro main noch in linux-firmware (dort gibt es zudem einen Revert von Mario Limonciello; beide Bäume können abweichen, das Skript holt korrekt von codelinaro main). **Der Surface-Eintrag ist nicht upstream; der Patch bleibt nötig.** Eine Einreichung an ath12k-firmware mit den Surface-IDs lohnt.
- Nach dem Boot: `rfkill list` (kein Hard-Block), `dmesg | grep ath12k`, `sl7-mac all` für die Werks-MAC.

### 4.5 Bluetooth-Firmware

Keine Extra-Dateien aus dem MSI nötig. `hci_qca` lädt `qca/hmtbtfw20.tlv` (RAMPATCH) und eine NVM-Datei `qca/hmtnv20.bin` bzw. Board-Variante `hmtnv20.bXXX` (Auswahl per Board-ID aus dem Chip – welche Variante der SL7 zieht, in `dmesg` prüfen, **unverifiziert**). Voraussetzung: Ubuntus `linux-firmware` mindestens Stand 11/2024 (`ls /lib/firmware/qca/hmt*`); der Installer prüft das und warnt, wenn die Datei fehlt. Bluetooth funktioniert laut Community-Issue #6 (geschlossen 18.05.2026); Nutzer scheiterten im Juni 2026 nur an fehlender Firmware-Installation.

### 4.6 GPU-Zap-Shader

Der DT-Knoten `gpu_zap_shader` verlangt `qcom/x1e80100/microsoft/qcdxkmsuc8380.mbn` (Zeilen 926–929 im Romulus-dtsi, upstream identisch). Da dieser DT-Pfad nicht über `MODULE_FIRMWARE` in die Initramfs gelangt, muss die Datei entweder vom Root-FS geladen werden (msm bindet nach dem Root-Mount – normal) oder die Initramfs nach Firmware-Änderungen neu gebaut werden (`sudo dracut --force`; auf Ubuntu 26.04 gibt es kein `update-initramfs` – das Skript-Ende von `wsl-extract-firmware.sh` nennt noch `update-initramfs -u`, der Installer verwendet dracut). Generische `gen70500_sqe.fw`/`gen70500_gmu.bin` liegen im Ubuntu-Paket.

---

## 5 Distro-Empfehlung & Installationsablauf

### 5.1 Rangliste

| Rang | Weg | Begründung |
|---|---|---|
| **1** | **Ubuntu 26.04.1 LTS, offizielles `ubuntu-26.04.1-desktop-arm64.iso` (3,9 GB, 26.08.2026) + eigener Kernel `7.0.0-rc4-sl7` + `sl7-install-on-laptop.sh`** | Für genau dieses Image gibt es **SL7-Primärberichte** (siehe unten). Canonicals FAQ listet den SL7 als getestet; ELLX-/Community-Patches sind Ubuntu-Packaging; der generische 26.04-Kernel bootet X1E via stubble bis zum Installer. Ohne eigenen Kernel bleiben GPU (llvmpipe), Akku, Tastatur/Touchpad und WLAN unzuverlässig – daher direkt danach Kernel + Firmware. Initramfs = dracut. |
| 2 | Ubuntu-Concept-Image `questing-desktop-arm64+x1e.iso` (20260314, 25.10-Basis, 6.19.0-13-qcom-x1e) – lokal vorhanden | Laut tobhe (10.04.2026) durch das offizielle 26.04-ISO praktisch abgelöst. Nützlich als **Live-Test** und als Notfall-Installer; **Achtung:** perchbirdd (14.05.2026) lief mit dem Concept-Image in eine Boot-Schleife, während das offizielle Resolute-arm64-Image bei ihm startete – das Concept-Image ist also nicht automatisch die „sicherere" Wahl. |
| 3 | ELLX-Installer-ISO `surface-laptop-7-20260610.iso` | Nur Fallback/Live-Test. Basis-Distro und Kernelstand nicht verifiziert; die README des Autors verdächtigt **den Installer** (nicht den Kernel) als Ursache des Lautsprecherschadens und rät selbst: erst reguläres Ubuntu installieren, dann den ELLX-Kernel obendrauf – genau unser Rang-1-Weg. |
| 4 | Debian 13 arm64 + ELLX-/eigene Debs | „should also work on Debian" (Community-README) – **unverifiziert**, keine Primärquelle; Trixie-Kernel 6.12 hat die Romulus-DTS, aber keine SL7-Patches. Experiment. |
| 5 | Fedora 44/45 (auch das lokale `Fedora-KDE-SurfaceLaptop7-44.aarch64.iso` vom Mai 2026) | Automatische DTB-Auswahl im Kernel-Image ist elegant (Change von Hans de Goede), aber Fedora-Kernel = reines Mainline: **keine Tastatur/kein Touchpad** ohne Eigenbau-Kernel-RPM (spi-hid nicht Mainline); Wiki nennt nur ThinkPads/Yoga und verlangt `clk_ignore_unused pd_ignore_unused systemd.tpm2_wait=0 modprobe.blacklist=qcom_q6v5_pas`; Fedora 45 ungeprüft. |
| 6 | Arch Linux ARM / Omarchy (cicorias-Gist 09.09.2026, ALARM 7.2.3, UKI mit `.dtbauto`) | Explizit ungetestet („No one has booted this stack on a Surface Laptop 7"), zielt auf das 15"-Modell, Audio tot, Akku ohne ADSP fehlerhaft. |
| 7 | NixOS (kuruczgy/x1e-nixos-config; orvitpng/nix1e) | DTB auf Yoga Slim 7x hardcoded, SL7 nicht in der Matrix; nix1e ist eine gute **DT-Referenz**, kein Installationsweg. |

**Primärbelege für das offizielle 26.04-arm64-ISO auf dem SL7** (Nachrecherche 13.09.2026, alle aus linux-surface#1590):

- vladimir-alekseev, 20.05.2026, SL7 13,8" X Plus: „successfully reinstall Ubuntu 26.04 … using vanilla arm64 desktop ISO and ProgrammerIn-wonderland's fixes".
- perchbirdd, 14.05.2026, 13"-Modell: mit dem offiziellen Resolute-arm64-Image funktionieren die Schritte „mostly" (Trackpad ja, WLAN/BT erst nach Firmware) – das Concept-Image lief bei ihm dagegen in eine Boot-Schleife.
- OliW07: „Ventoy fixed most of my problems".

Damit ist das frühere Risiko „kein SL7-Primärbericht für das offizielle 26.04-ISO" **erledigt** und aus der Risikoliste gestrichen.

### 5.2 Boot-Medium: Ventoy (Primärweg)

- **Ventoy 1.1.17 (24.07.2026)** auf einen USB-Stick installieren, ISOs einfach darauf kopieren. Im Ventoy-Menü den **Normalmodus** wählen (Eingabetaste) – **nicht** den grub2-Modus (Strg+R): im Normalmodus lädt der ISO-eigene Ubuntu-GRUB, der stubble und `.dtbauto` kennt.
- **ISO vor und nach dem Kopieren per SHA256 prüfen:** unter Windows `certutil -hashfile <datei> SHA256`, Vergleich gegen `SHA256SUMS` von cdimage.ubuntu.com. Das ist die wichtigste Einzelmaßnahme – siehe der aufgeklärte Fehlalarm unten.
- **Der „invalid magic number"-Fehler war ein korrupter ISO-Download, kein Ventoy-Problem.** Notliam99 meldete am 20.05.2026 (SL7 mit X1P-64-100) „invalid magic number / you need to load a kernel first" und klärte den Fall selbst um 09:27 UTC auf: „omg it was a corupted file"; um 11:38 UTC war das Gerät mit Ventoy „fully setup". Es gibt kein Ventoy-Issue zu „invalid magic number" mit arm64/Ubuntu 26.04; alle auffindbaren Fälle sind x86 mit beschädigtem Image.
- **dd/Rufus nur als Fallback:** Für direkt geflashte Sticks sind auf dem SL7 GRUB-Freezes und eine tote interne Tastatur belegt (Launchpad 2084951; Community-README: „Ventoy is required to enable keyboard support in GRUB"). Gegenmittel wären eine externe USB-Tastatur am USB-A-Port bzw. `terminal_output gfxterm` im GRUB – für 26.04.1 auf dem SL7 aber nicht primär belegt.
- **UEFI-Checkliste (bestätigt):** Secure Boot auf **None** (nicht „Microsoft only"), USB-Boot erlaubt, BitLocker vorher aussetzen und den Recovery-Key sichern.

### 5.3 Schritt für Schritt

**A. Unter Windows vorbereiten**
1. Alle Surface-Firmware-/Windows-Updates einspielen (später nur noch über Windows möglich). Optional das aktuelle MSI 26.053.36539.0 installieren.
2. `hardware\SL7-Hardware-Dump.ps1` ausführen und den Dump sichern (PnP-IDs, ACPI, EDID, MACs, Partitionen, TPM/Secure-Boot).
3. BitLocker aussetzen bzw. deaktivieren und den Recovery-Key sichern (Microsoft-Konto/Ausdruck) – nach Secure-Boot-Änderung fragt Windows sonst beim Boot nach dem Key.
4. `C:` in der Datenträgerverwaltung um mindestens 60–100 GB verkleinern (unpartitioniert lassen). Windows-Partition und Windows-Boot-Manager unangetastet lassen.
5. Surface-Recovery-Image (Microsoft, per Seriennummer) auf einen zweiten Stick laden.
6. **Ventoy 1.1.17** auf den Stick installieren und `ubuntu-26.04.1-desktop-arm64.iso` daraufkopieren (optional `questing-desktop-arm64+x1e.iso` als Zweit-ISO). **SHA256 vor und nach dem Kopieren prüfen** (`certutil -hashfile … SHA256` gegen `SHA256SUMS`).
7. Ordner `build\out\` komplett auf den Stick (oder einen zweiten) kopieren.

**B. Surface-UEFI** (Gerät aus; **Lautstärke +** gedrückt halten und Power drücken, halten bis das Surface-Logo erscheint)
- Security → Secure Boot → **None** (Secure Boot aus; unsere Kernel sind unsigniert).
- Boot configuration → USB-Boot erlauben und vor die SSD ordnen (oder per Wischen im UEFI-Bootmenü / Vol-Up + Power vom Stick booten).
- Alles andere lassen (TPM/Pluton ist für Windows relevant).

**C. Installation**
1. Vom Ventoy-Stick starten, Ubuntu-ISO wählen, **Normalmodus** (Eingabetaste), nicht grub2-Modus. Falls schwarzer Bildschirm: GRUB-Eintrag editieren und `quiet splash` entfernen.
2. Live-System: Netzwerk (WLAN geht hier vermutlich nicht – board-2.bin fehlt; USB-Ethernet/USB-Tethering nutzen), Tastatur/Touchpad prüfen (Touchpad läuft ohne spi-hid nicht → Maus mitnehmen).
3. Installer: „Alongside Windows" (Dual-Boot), **„Install third-party/additional drivers" anhaken**, Netzwerk verbunden lassen. Keine LUKS-mit-TPM-Option wählen (kein TPM unter Linux). ext4 (oder btrfs) für `/`.
4. Erster Boot ins installierte 26.04.1 (Ubuntu-generic-Kernel, stubble; GPU ggf. llvmpipe – normal).
5. `build/out` auf den Laptop kopieren, dann erst einen Probelauf, danach die Installation:
   ```
   cd <ordner>/out
   sudo DRYRUN=1 bash sl7-install-on-laptop.sh    # zeigt nur, was passieren würde
   sudo bash sl7-install-on-laptop.sh
   ```
   Das Skript (idempotent, ändert den Windows-Bootloader nicht, zählt Warnungen und prüft vorab `/sys/firmware/devicetree/base/model`) macht in 9 Schritten: `dpkg -i` linux-image/-headers `7.0.0-rc4-sl7` (höchste Revision neben dem Skript) → stubble-Image nach `/boot/vmlinuz-<ver>` (Original als `.plain`) + `/boot/sl7-romulus13.dtb` → Firmware-Tarball nach `/` (Plausibilitätsprüfung: mindestens 10 Dateien unter `…/Romulus/`, Bluetooth-Firmware vorhanden?) → **Lautsprecher-Schutz** (GNOME-Überverstärkung aus; nur bei `SL7_NO_SPEAKER=1` zusätzlich die harte Modulsperre) → `/etc/default/grub.d/90-sl7.cfg` (`clk_ignore_unused pd_ignore_unused`, Menü, Timeout 5, os-prober an) + `/etc/grub.d/42_sl7_fallback` (erkennt eine eigene `/boot`-Partition und setzt die Pfade entsprechend) → `dracut --force` + `update-grub` → iptsd-Deb + `/etc/iptsd.d/91-calibration-045E-0C77.conf` + `iptsd@.service` + `50-iptsd.rules` (beides fehlt im ELLX-Deb, Issue #23) → `sl7-mac` + Sleep-Hooks `display-fix`/`trackpad` nach `/lib/systemd/system-sleep/` → Zusammenfassung mit Warnungszähler.
6. `sudo reboot`, im GRUB-Menü den neuen Kernel (Standard) wählen.

**D. Nach dem ersten Boot prüfen**
```
uname -r                                   # 7.0.0-rc4-sl7
cat /proc/device-tree/model                # Microsoft Surface Laptop 7 (13.8 inch)
dmesg | grep -iE 'ath12k|adsp|cdsp|msm|spi.hid|hid-over|battmgr|ov02c10|iris|error' | head -80
rfkill list; nmcli dev; ip link            # WLAN ohne Hard-Block, MAC = Werks-MAC (sl7-mac all)
glxinfo -B | grep -i renderer; vulkaninfo --summary | grep -iE 'driver|apiVersion'   # freedreno a741 / Turnip
upower -i $(upower -e | grep BAT)          # Akku über qcom_battmgr
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver; cat /sys/devices/system/cpu/cpufreq/boost
ls /sys/class/rtc; timedatectl             # RTC-Status (offen)
cat /sys/power/mem_sleep                   # s2idle [deep]
systemctl status 'iptsd@*'; libinput list-devices | grep -iA3 touch
ls /dev/video*; v4l2-ctl --list-devices    # Kamera (ov02c10/camss), Video (iris)
bluetoothctl show                          # BT-Adapter mit fester MAC
grep -n devicetree /boot/grub/grub.cfg     # nur im Fallback-Eintrag erwartet
ls /dev/kvm 2>/dev/null || echo "kein KVM (EL1) - erwartet"
```

**Audio-Prüfung direkt nach dem ersten Boot** (vor dem ersten Ton, Abschnitt 6.5):
```
cat /proc/asound/cards                     # X1E80100-Romulus muss auftauchen
aplay -l
ls /sys/bus/soundwire/devices
lsmod | grep wsa884x
dmesg | grep -iE 'wsa884x|sndcard|EPROBE'  # kein Dauer-EPROBE_DEFER
amixer -c0 contents | grep -A3 -i 'PA Volume'   # platform_max muss 6 sein (Kernel-Limit aktiv)
cat /sys/devices/virtual/dmi/id/{board_vendor,product_family,board_name}
alsaucm -c X1E80100-Romulus list _verbs    # greift das UCM-Profil?
```

**Thermik/Video (neu in Rev. 3):**
```
cat /sys/class/thermal/thermal_zone*/type | sort | uniq -c
grep . /sys/class/thermal/thermal_zone*/trip_point_*_temp | head
ls /sys/class/thermal/cooling_device*/type          # cpufreq-Cooling erwartet
dmesg | grep -i iris; v4l2-ctl --list-devices       # iris gebunden?
```

Dann: Suspend testen (Deckel zu / `systemctl suspend`, Aufwecken per **Power-Taste**), danach Display (Hook `display-fix` schaltet chvt 20 und zurück), Touchpad (Hook `trackpad` bindet `spi_hid` neu), USB-A-Gerät nach Resume. Touchpad kalibrieren: `sudo iptsd-calibrate /dev/hidrawN` (N per `iptsd-find-hidraw`), „e" entlang der Ränder und über die Fläche ziehen; ohne Kalibrierung fühlt sich das Pad „really awful" an (ELLX-Anleitung).

**E. Recovery / Fallback**
- GRUB-Eintrag „SL7 Fallback: 7.0.0-rc4-sl7 (plain + devicetree)": plain-Kernel + `devicetree /boot/sl7-romulus13.dtb`, falls das stubble-Image nicht bootet.
- Ubuntu-generic-Kernel bleibt installiert (Untermenü „Advanced options"); dort niemals `devicetree` mit stubble kombinieren (bzw. `stubble.dtb_override=false` setzen).
- Bei GRUB-Totalschaden: im Surface-UEFI den Windows Boot Manager als Standard setzen, Ventoy-Stick als Rettungssystem (chroot, `update-grub`), Surface-Recovery-Stick als letzte Stufe.
- Hängendes Touchpad („Touch-Wedge"): komplett ausschalten (nicht nur neu starten) oder nach Windows booten und zurück – der Reboot über Windows setzt den Controller zurück.
- Kernel-Rückbau: `sudo apt remove linux-image-7.0.0-rc4-sl7 linux-headers-7.0.0-rc4-sl7 && sudo update-grub`; Firmware bleibt harmlos liegen.

---

## 6 Komponenten-Status & Fixes

### 6.0 Statusübersicht

| Komponente | Status mit `7.0.0-rc4-sl7` Rev. 3 (erwartet) | Voraussetzung / Fix | Quelle |
|---|---|---|---|
| Boot (stubble, DTB-Auswahl) | ✅ erwartet (Chroot-Test OK, Gerät noch nicht gebootet) | stubble-Image oder Fallback-Eintrag | lokal |
| NVMe | ✅ | – | Community-README |
| GPU (freedreno/Turnip) | ✅ | Zap-Shader-Pfad exakt | LP #99–#102, README |
| Display / Backlight | ✅ | pwm-backlight; „quiet splash" ggf. weg | README, DTS |
| Tastatur (SAM) | ✅ | Mainline-DT | fQwQf 09/2026, README |
| Touchpad | ✅ mit Einschränkungen (Multitouch „wonky") | spi-hid + QSPI-Hack + iptsd (alex-lentz) + Kalibrierung + Service/udev; Reset-Fix in Rev. 3 | README, #5, #23, #1590 |
| Touchscreen | ⚠️ experimentell | beide DT-Varianten (spi10 + i2c8) im DTB | #1590, linux-input 09/2026 |
| WLAN | ✅ | rfkill-Hack + board-2.bin-Patch + sl7-mac | LP #94–#97, README |
| Bluetooth | ✅ | linux-firmware ≥ 11/2024 + sl7-mac | #6 |
| Audio Kopfhörer/Mikro | ✅ | ADSP-Firmware, UCM-Match; **setzt geladene WSA-Module voraus** | #2, #20, lokal |
| Audio Lautsprecher | ⚠️ **nutzbar mit Limit und Hausregeln** | Kernel-Volume-Limit (Rev. ≥ 2), max. 70 %, nie „Pro Audio"; harte Sperre nur als Opt-in | s. 6.5 |
| Kamera OV02C10 | ✅ (Grünstich/Strobing) | DT im Tag, libcamera-Tuning, Firefox-Flag | #4 |
| Video-Decode (iris) | ⚠️ neu, ungetestet | DT-Aktivierung + `qcvss8380.mbn` (Rev. 3) | lokal, 7.5 |
| IR-Kamera, ALS, Fn-Beleuchtung | ❌ / unbekannt | – | – |
| Suspend/Resume | ✅ (deep) | Sleep-Hooks, dwc3-Patches | #7, #18, #19, #1590 |
| Akku / Laden | ✅ | ADSP + battmgr.jsn; Duplikat-Batterie-Patch | #15, README |
| USB-A / USB-C Daten | ✅ | dwc3-Resume-Patches | README |
| USB-C DisplayPort | ✅ Cold-Plug | ab 6.16.0-10; Hotplug erst mit glathe-Patch | LP #110, #11, glathe 07/2026 |
| USB4 / Thunderbolt | ❌ | kein Tunneling in Linux auf x1e80100 | glathe, TUXEDO |
| RTC | ❓ | prüfen | #8 vs. README |
| Thermik (CPU-Drosselung) | ✅ neu in Rev. 3 (ungetestet) | passive Trips 85 °C + cooling-cells | lokal, scuggo |
| Lüfter | ❓ (EC-autonom) | `SURFACE_FAN` nicht in der Config | #7 (2025) |
| MAC-Adressen | ✅ mit sl7-mac | UEFI-Variable | valeronm |
| KVM | ❌ (EL1) | slbounce-Nebenprojekt | LP #106–#109 |
| TPM | ❌ | – | DT/iFixit |

### 6.1 WLAN (WCN7850, ath12k)

- Symptome ohne Fix: `failed to fetch board data …subsystem-device=1107…` und `rfkill: Hard blocked: yes`.
- Fix im Projekt: gepatchte `board-2.bin` unter `/lib/firmware/updates/ath12k/WCN7850/hw2.0/` (Tarball) + ELLX-„Surface Laptop 7 Enumeration hack" in `ath12k/core.c` (im Tree; `wsl-build-kernel.sh` prüft „rfkill-hack: im Tree"). Kein manuelles Modul-Neubauen nach Kernel-Updates nötig, solange unser Kernel läuft (Launchpad-Rezept #97/#105 war für den Concept-Kernel).
- MAC: der Chip hat keine eingebrannten Adressen → zufällige MAC bei jedem Boot. `sl7-mac` (valeronm, `sl7-mac_1.0.2_all.deb` lokal gebaut) liest die UEFI-Variable `MacAddressEmulationAddress-b7f95555-4ea5-4786-b088-78ba350a1b56` (speichert die Ethernet-MAC = base+2; Wi-Fi = base+0, BT = base+1) und setzt sie; braucht `efivarfs` (also kein `efi=noruntime`). Bestätigt auf X Plus 13,8" (Issue #21).
- Community-Issue #1 (WLAN) ist formal offen (03.06.2026), praktisch gelöst.

### 6.2 Bluetooth

Firmware `qca/hmtbtfw20.tlv` + `hmtnv20.*` aus Ubuntus linux-firmware; `hci_qca` über `uart14`. Issue #6 geschlossen 18.05.2026. MAC per sl7-mac (sonst brechen Pairings). Launchpad #111 (07/2025) behalf sich noch mit USB-Dongle – nicht mehr nötig.

### 6.3 GPU (Adreno X1-85)

Zap-Shader `qcom/x1e80100/microsoft/qcdxkmsuc8380.mbn` (Pfad exakt, sonst llvmpipe / „could not get GPU ID"). Mesa 26.0.3 in Ubuntu 26.04 reicht; für a7xx-Fixes `ppa:kisak/kisak-mesa` (26.2.x, Anleitung 07.09.2026). Prüfen: `glxinfo -B` (freedreno a741, OpenGL 4.5/ES 3.2), `vulkaninfo --summary` (Turnip, Vulkan 1.4 auf a7xx). Phoronix' llvmpipe-Rückfall (24.07.2026) betraf den Ubuntu-generic-Kernel ohne passende Firmware.

### 6.4 Display / Backlight

eDP-Panel über `mdss_dp3`, pwm-backlight (`/sys/class/backlight/…`; Issue #3 nannte aus SP11-Notizen `dp_aux_backlight`, der Romulus-DT definiert pwm-backlight – README ✅). Nach Resume kann das Bild korrupt sein (rechte Hälfte schwarz, Issue #18): Hook `display-fix` (`chvt 20; chvt $CURRENTVT` im `post`-Fall) behebt es; manuell Strg+Alt+F3 → F2. 120 Hz/VRR: GNOME 50 hat VRR per Default; Frequenzwechsel im Panel-Menü prüfen. Fraktionale Skalierung: Abschnitt 7.

### 6.5 Audio – Lautsprecher (Schutzkonzept)

> ### ⚠️ WARNUNG: Lautsprecherschaden ist real, aber die Gegenmaßnahme hat sich geändert
> **Linux hat für den X1E keine aktive Speaker-Protection.** Bei voller Lautstärke greift nur die Hardware-Schutzabschaltung im Verstärker – und die schützt nachweislich nicht zuverlässig:
> - ELLX-Installer-README (01.07.2026): „I permanently damaged my speakers by enabling sound! Do NOT enable it." – rechter Lautsprecher dauerhaft tot. Nachtrag „I lied and I think I fixed the bug!" ohne jede technische Angabe; der ELLX-Kernel-Branch hat seit 10.04.2026 keine Audio-Commits – ein Fix läge also nicht im Kernel **(unverifiziert)**. Die Warn-README steht bis heute unverändert online.
> - **Auslöser laut #1590 (23.05.2026): der Klick auf das PipeWire-Profil „Pro Audio"** – das umgeht das UCM und stellt rohe ALSA-Regler. „Ubuntu concept had some protections which I didn't include in my ISO" passt genau auf den fehlenden Speaker-Limit-Patch.
> - linux-surface#1590: ameenjuz (10.06.2026) – bei 100 % Lautstärke fällt der Ton bis zum Reboot aus; valpackett: „Proper feedback-based speaker protection is not wired up yet", die Abschaltung ist die letzte Hard-Sicherung, „normal volume to 100% is too much"; ProgrammerIn-wonderland (30.06.2026): „had to get a new surface laptop 7 because it ruined my speakers".
> - Launchpad #109/#110 (20.07.2025): Sound „CAN PERMANENTLY DAMAGE YOUR HARDWARE".
> - Ubuntu LP #2149808 (Tobias Heider, Canonical, 21.04.2026, ThinkPad T14s): „Speaker overdrive causes hardware protection shutdown" → SAUCE-Patch „limit speaker volumes", in Ubuntus `linux` seit 29.04.2026 (7.0.0-15.15) – **fehlte in ELLX und in beiden Concept-x1e-Branches**.
> - Ubuntu-Discourse #2158 (02.09.2026, ASUS Vivobook S15): nach einem Kernel-Update sehr leise, pumpende, verzerrte Lautsprecher mit „Unsorted reg_defaults" im WSA-Codec-Treiber – der WSA-Stack ist auch 2026 noch instabil.
> - NixOS-x1e-Config: „High volume can damage speakers."

**Standardschutz in diesem Projekt: Ubuntus Kernel-Volume-Limit.**
Der SAUCE-Patch aus LP #2149808 ist ab Paket-Revision 2 im Kernel: `snd_soc_limit_volume` setzt WSA/WSA2 RX0/RX1 Digital Volume auf 81 (−3 dB) und Spkr/Woofer/Tweeter PA Volume auf 6 (0 dB). Die wsa884x-Verstärker bieten eine PA-Skala von −9 bis +9 dB in 1,5-dB-Schritten; der Patch deckelt sie damit auf 0 dB. Entscheidend: Das Limit wird als `platform_max` **am ALSA-Regler selbst** gesetzt – es wirkt deshalb auch gegen `amixer`, gegen alsactl-States und gegen das PipeWire-Profil „Pro Audio". Es ist die einzige Schicht, die das leistet, und deshalb der Standardweg.

**Hausregeln für den Betrieb (gelten immer):**
1. **Niemals** das PipeWire-Profil „Pro Audio" auswählen – das war der belegte Auslöser des ELLX-Schadens.
2. Lautstärke **höchstens 70 %**; Überverstärkung über 100 % bleibt systemweit aus (der Installer schreibt `allow-volume-above-100-percent=false` in die dconf-System-DB).
3. **Keine manuellen Änderungen an den WSA- und PA-Reglern** (`amixer`, alsamixer, UCM-Overrides, alsactl-Restore-Dateien). Wer dort dreht, hebelt genau die Schicht aus, die schützt.
4. Erste Tests kurz und leise, Hand am Gehäuse (Erwärmung). Fällt der Ton bis zum Reboot aus, hat die Hardware-Schutzabschaltung gegriffen → sofort leiser, Vorfall notieren.

**Harte Modulsperre = nur noch Opt-in (`SL7_NO_SPEAKER=1`), und sie bedeutet gar keinen Ton.**
Die frühere Annahme „Blacklist sperrt nur die Verstärker, Kopfhörer und Mikrofon bleiben nutzbar" ist **widerlegt**: Der Romulus-Sound-Knoten hat vier DAI-Links (va-dai-link/DMICs, wcd-capture, wcd-playback, wsa-dai-link/Lautsprecher). `qcom_snd_parse_of()` (`sound/soc/qcom/common.c`) löst die Codec-Phandles **aller** vorhandenen Links auf; fehlt `snd_soc_wsa884x`, existieren `left_spkr`/`right_spkr` nicht und die Karte **X1E80100-Romulus bleibt dauerhaft in `-EPROBE_DEFER`** – kein Kopfhörer, kein DMIC, kein DisplayPort-Audio. Sinnvoll ist das nur für einen ersten Testboot, bei dem garantiert kein Ton entstehen soll.
Technisch: `blacklist` allein verhindert nur das Auto-Laden, ein manuelles `modprobe` lädt das Modul trotzdem. Der Installer setzt deshalb bei `SL7_NO_SPEAKER=1` zusätzlich `install snd_soc_wsa884x /bin/false` in `/etc/modprobe.d/sl7-no-speaker.conf` **und** `module_blacklist=snd_soc_wsa884x` auf die Kernel-Cmdline (vom Kernel selbst erzwungen, unabhängig davon, ob dracut die `modprobe.d`-Dateien in die Initramfs übernimmt – das ließ sich aus dem Quelltext nicht belegen).
Aufheben:
```
sudo rm /etc/modprobe.d/sl7-no-speaker.conf
sudo sed -i 's/ module_blacklist=snd_soc_wsa884x//' /etc/default/grub.d/90-sl7.cfg
sudo update-grub && sudo dracut --force && sudo reboot
```

**Prüfbefehle nach dem ersten Boot** (siehe auch Abschnitt 5.3 D):
```
cat /proc/asound/cards
aplay -l
ls /sys/bus/soundwire/devices
lsmod | grep wsa884x
dmesg | grep -iE 'wsa884x|sndcard|EPROBE'
amixer -c0 contents | grep -A3 -i 'PA Volume'     # platform_max muss 6 sein
```
Zeigt `PA Volume` ein `platform_max` von 6, ist das Kernel-Limit aktiv. Hängt die Karte in `EPROBE_DEFER` und ist `SL7_NO_SPEAKER` nicht gesetzt, stimmt etwas anderes nicht (Firmware/ADSP) – dann nicht „mit mehr Lautstärke" gegenprobieren.

**ALSA-UCM:** `ucm2/Qualcomm/x1e80100/x1e80100.conf` ordnet Geräte per DMI-Regex (board_vendor – product_family – board_name) dem Profil `LENOVO-T14s.conf` zu (Includes: WCD938x, „WSA884x dual-speaker", WSA-/RX-/TX-/VA-Macro; BootSequence setzt HPHL/HPHR Volume 20) – die Gains stammen also vom ThinkPad T14s. Dass der Regex den Romulus13 real matcht, ist nur indirekt belegt (SL7-UCM am 13.06.2025 upstream gemerged, 14.07.2025 „audio functioning"). Auf dem Gerät prüfen: `cat /sys/devices/virtual/dmi/id/{board_vendor,product_family,board_name}` und `alsaucm -c X1E80100-Romulus list _verbs`. Greift das UCM nicht, ist das tj90241-Rezept (05.05.2025) das bekannte Mittel: `board_name` in `DMI_info` aufnehmen und den Surface-Regex ergänzen.

**Spätere Option (nicht gebaut, abgeleitet): Verstärker auf DT-Ebene stilllegen.** `&left_spkr`, `&right_spkr` und `&swr0` auf `status = "disabled"` setzen, dazu `/delete-node/ wsa-dai-link` und ein gekürztes `audio-routing`. Das entfernt die Lautsprecher sauber aus der Karte, **ohne** Kopfhörer und Mikrofone mitzunehmen – der saubere Ersatz für die Modulsperre. Sinnvoll erst, wenn sich auf dem Gerät zeigt, dass das Kernel-Limit nicht genügt.

Community-README (06.08.2026) führt „Audio" unter „What Works" (vixalien 14.07.2025: UCM upstream, „audio functioning") – das ist die Funktions-, nicht die Sicherheitsaussage.

### 6.6 Mikrofon

2 DMICs über VA-Makro/ADSP. Issue #20 „Corruption in internal microphone" (03.06.–17.07.2026, Samples nahe int16-Maximum) war ein Fehler auf OliW07s eigenem Branch, nicht im ELLX-Tag. Prüfen: `arecord -l`, kurze Testaufnahme. Achtung: Mit `SL7_NO_SPEAKER=1` sind auch die Mikrofone tot (Abschnitt 6.5).

### 6.7 Kamera (OV02C10)

DT-Patch (PM8010-Regler, camss/csiphy4, `cci1_i2c1 camera@36`, MCLK/pinctrl) ist im ELLX-Tag; Community-0005 (Metadata) ist als Patchdatei defekt und in ELLX bereits in `ov02c10.c` eingearbeitet. Nutzung über V4L2/libcamera/PipeWire; Firefox: `media.webrtc.camera.allow-pipewire=true`. libcamera-Tuning `config/OV02C10-camera/ov02c10.yaml` + IPA-Patch aus dem Community-Repo (Grünstich/Strobing). Upstream: Treiber seit 6.15 (Flip-/Bayer-Fixes 01/2026 in 7.0), DT-Patch v2 (Oliver White, 09.04.2026, Reviewed-by Bryan O'Donoghue) wartet – zielt auf das gemeinsame romulus.dtsi. Kamera-LED tlmm 225 ist Mainline.

### 6.8 Touchpad (spi-hid + iptsd)

- Hardware: HID-over-SPI an `spi19` (native QSPI, „Protokoll 9") – tj90241 (04/2025) hielt das für einen „dead end"; ELLX/scuggo lösten es mit gepatchtem `spi-geni-qcom.c`/`gpi.c`. Qualcomm (Mukesh Savaliya, 01.07.2026) will einen GENI-QSPI-Treiber upstreamen – bis 09/2026 kein Patch. Bleibt Out-of-tree.
- Das Gerät liefert nur Roh-Heatmaps (IPTS-artig); HID-Multitouch wird beworben, sendet aber keine Daten (orvitpng) → **iptsd bleibt nötig**, alex-lentz-Fork für den physischen Klick.
- Installation (macht der Installer): `iptsd_3.1.0-1_arm64.deb`, `/etc/iptsd.d/91-calibration-045E-0C77.conf` (ELLX-Kalibrierung vom 15"-Gerät – eigene Kalibrierung ist besser), `iptsd@.service` (Template, `ExecStart=/usr/bin/iptsd /%I`, `BindsTo=%i.device`) und `/etc/udev/rules.d/50-iptsd.rules` (`iptsd-check-device` → `SYSTEMD_WANTS=iptsd@<hidraw>.service`) – beides fehlt im ELLX-Deb (Issue #23, 30.07.2026), sonst kein Zwei-Finger-Scroll. hidraw-Nummern sind instabil → nicht an `/dev/hidrawN` binden.
- udev-Feinheit (horizontblau): `LIBINPUT_IGNORE_DEVICE=1` nur für `ID_PATH=platform-88c000.spi-cs-0` **und** `ID_INPUT_TOUCHPAD=="1"`, damit der Mouse-Node für den Klick sichtbar bleibt.
- **SIGILL-Hinweis:** Das gelieferte iptsd-Binary stürzte bei horizontblau mit SIGILL (BTI/branch-protection-Mismatch). Abhilfe: `objcopy --remove-section=.note.gnu.property /usr/bin/iptsd` oder Neubau aus Quelle mit `-mbranch-protection=standard` (im arm64-Chroot möglich; Build-Deps sind in `wsl-arm64-chroot.sh` vorgesehen).
- Nach Suspend kann das Pad hängen → Hook `trackpad` (unbind/bind aller `spiN.M` unter `/sys/bus/spi/drivers/spi_hid`). **Rev. 3 räumt das Reset-/Regulator-Handling auf** (`vreg_ts_5p0` mit `regulator-boot-on`, gpio65 raus aus den `spi19`-Reset-States, nur noch gpio120) – ob das den „Touch-Wedge" (enumeriert, aber tot) entschärft, muss das Gerät zeigen; bisher half nur komplettes Ausschalten.
- Erfahrung hybris (06.08.2026, X Plus 13,8"): Multitouch weiterhin „wonky", „okay, but not Windows-like".

### 6.9 Touchscreen (experimentell)

- Fakten: Im UEFI/GRUB funktioniert der Touch (Launchpad #80, 03/2025); unter Linux fehlt jeder DT-Node (Mainline `romulus13.dts` = Stub). Controller ITCH MSHW0468; ACPI-Gerät GTCH mit `_CID PNP0C51` (HID-over-SPI) an `\_SB.SP11` = QUP1 SE2 → das ist der `spi10`-Bus.
- **Variante A (i2c8, seit Rev. 2):** HID-over-I2C an `i2c8` @0x34 (fQwQf, linux-input 07.09.2026) – Maintainer Krzysztof Kozlowski: „Drop"; **unwahrscheinlicher**, bleibt zum Test im DTB.
- **Variante B (spi10, seit Rev. 3):** QSPI, 40 MHz, Read-Opcode 0xEB, 8 Dummy-Clocks, IRQ gpio51, Reset gpio48, 5 V über `vreg_ts2_5p0`/gpio64, `gpi_dma1`, Report-Adressen 0x1000/0x1004/0x2000 – horizontblau (25.08.2026) berichtet „läuft" mit ELLX + iptsd, orvitpng/nix1e nutzt dieselben Pins und meldet den Touchscreen als „fine". Die Beiträge horizontblaus sind umstritten (KI-Vorwurf), die Pins sind aber durch zwei unabhängige Quellen + ACPI plausibel → **die wahrscheinlichere Variante**.
- Beide Nodes liegen gleichzeitig im DTB. Vorgehen nach dem Boot: `dmesg | grep -iE 'spi10|a88000|i2c8|hid-over|spi_hid|touchscreen'`, `libinput list-devices`. Wirft eine Variante Fehler (Bus-Timeouts, Probe-Fehler, Resume-Probleme): Node auf `status = "disabled"` und neu bauen. Ergebnis in Community-Issue #13 melden. dwhinham (02.09.2026) testet orvitpngs Touchscreen-Code auf Jingyuan Liangs spi-hid v4 (Surface Pro 11 inkl. Stift) und will QSPI/Touchscreen upstreamen – ein Tested-by vom Romulus13 wäre dort willkommen.

### 6.10 Tastatur / SAM

Surface Aggregator (`microsoft,surface-sam`, uart2, 4 MBaud, IRQ gpio91) ist Mainline und im ELLX-`romulus.dtsi` enthalten; `surface_aggregator`, `_registry`, `_hub`, `surface_hid`, `surface_kbd` als Module. Der Duplikat-Batterie-Patch (#15) sorgt dafür, dass `surface_battery`/`surface_charger` sich zugunsten von `qcom_battmgr` zurückziehen. Nach Resume hängende Modifier an **externen USB-Tastaturen** (#19, 01.06.2026) → dwc3-Reinit-Patches (im Build) bzw. Replug. Tastaturbeleuchtung/Fn-Tasten: kein Quellenstand.

### 6.11 Suspend / Resume

- Mit ELLX: `/sys/power/mem_sleep` = `s2idle [deep]`, Aufwecken per Power-Taste zuverlässig (horizontblau 23.08.2026); kein Hibernate (HIBERNATION aus, kein `disk` in `/sys/power/state`). Der Lid-Hall-Sensor ist Wakeup-Quelle (DT).
- Bekannte Resume-Artefakte und Gegenmittel: Display korrupt → `display-fix`; Touchpad tot → `trackpad`; USB/USB-A tot → dwc3 `reinit-phy-on-resume` (Rev. 1+); externe Tastatur Modifier → dwc3/Replug.
- Aus orvitpng/nix1e: eine neuere Chromium-spi-hid-Serie mit `fullduplex.patch` soll „properly power the trackpad and fix suspend" – Kandidat für den nächsten Rebase.
- Akku-Drain: alte Berichte (6.14, 03–04/2025, Issue #7) nennen kompletten Drain in ~12 h s2idle und fehlenden cpufreq-Treiber – mit 7.0 nicht neu gemessen. NixOS (Yoga Slim 7x) meldet spurious wakeups und ~3,8 %/h. **Messen** (`upower`, über Nacht).

### 6.12 Akku / Laden

`qcom_battmgr` über pmic-glink braucht die ADSP-Firmware + `battmgr.jsn`; ohne ADSP: EAGAIN/keine Anzeige (cicorias, Phoronix). USB-C-PD/UCSI (`ucsi_glink`) ist ebenfalls ADSP-abhängig. Laden über beide USB-C-Ports und Surface Connect (39-W-Netzteil; Fast Charge ab 65 W). `qcom_battmgr` bekam 2026 Fixes (Use-after-free 01.08., String-Terminierung 27.07., Chemie-`strncmp` 12.08. → 7.3, Cc stable) – für den 7.0-Tree Backport prüfen, wenn Abstürze im battmgr-Pfad auftreten.

### 6.13 USB-C / DisplayPort / USB4

- Funktioniert: USB 3.x Daten, PD, DP-Alt-Mode (USB-C-Displays, „ab 6.16.0-10 still messy" LP #110; README ✅). Hotplug von DP-Displays ist unzuverlässig – glathe (Discourse 20.07.2026) behebt das mit 20 ms Delay nach der PS8830-Retimer-Konfiguration bzw. USB3-Downgrade-Modus im DT (Patchserie, nicht in unserem Tree) → **Cold-Plug** (Display vor dem Boot bzw. vor dem Anstecken einschalten) und **Full-Featured-USB-C-Kabel** statt Thunderbolt-Kabel.
- Nicht: USB4/Thunderbolt-Tunneling auf x1e80100 in Linux; an TB4-Docks (z. B. Lenovo 40B0) „almost nothing works, except for power delivery and USB2". TUXEDO nennt fehlende volle USB4-Raten als einen Grund für die Einstellung ihres X1E-Notebooks.
- Surface Connect: Laden ja; USB/Display „not tested".

### 6.14 RTC

Widersprüchlich: README ✅ (mit Verweis auf Issue #8), Issue #8 aber ohne dokumentierten Fix geschlossen (08.04.2025; `timedatectl` „RTC time: n/a", `rtc_surface` half nicht). Das Board-DTSI hat keinen RTC-Node; die Config hat `RTC_DRV_PM8XXX=m` (PMK8550-RTC über hamoa-pmics, unverifiziert) und EFI-RTC. Auf dem Gerät prüfen; notfalls reicht `systemd-timesyncd` für die Uhrzeit.

### 6.15 Thermik / Lüfter

- SoC-Sensoren über `qcom_tsens` (`/sys/class/thermal/thermal_zone*`), Limits über `qcom_lmh`; Thermal-Governor step_wise (power_allocator verfügbar).
- **Neu in Rev. 3:** Der DTB bringt eine echte CPU-Drosselung mit. `#cooling-cells` für `cpu0`…`cpu11` plus **passive Trips bei 85 °C mit 5 °C Hysterese** in allen 12 Zonen `cpu0-0-top-thermal` … `cpu2-3-top-thermal` ergeben 20 `cooling-device`-Einträge im DTB. Vorher – und in Mainline – hatten die CPU-Zonen nur critical-Trips bei 115 °C, also Notabschaltung statt Drosselung. Vorbild: `scuggo/x1e-nixos`, `surface-laptop-7-thermal.dts`. Die Config-Voraussetzungen sind erfüllt (CPU_THERMAL=y, QCOM_TSENS=y).
- Prüfen: `sensors`, `cat /sys/class/thermal/thermal_zone*/type` und `…/temp`, `ls /sys/class/thermal/cooling_device*/type` (cpufreq-Cooling erwartet), Trip-Punkte auslesen, Lastlauf beobachten.
- Der Lüfter bleibt EC-Sache (SAM); `SURFACE_FAN` ist nicht in der Config, und ob der SL7-EC ein Fan-/Thermal-Subsystem exponiert, ist unbekannt (2025-Berichte: Lüfter regelt bei geschlossenem Deckel nicht hoch, keine Sensoren erkannt – Stand 6.14). Phoronix (Acer Swift, 12/2025) sah Hard-Shutdowns durch Power-/Thermal-Schwellen; die neuen passiven Trips sollen genau das verhindern.

### 6.16 MAC-Adressen

Siehe 6.1: `sl7-mac all` nach dem Boot (der Installer ruft es auf und meldet die gefundenen Adressen; das Paket bringt die Automatik mit). Ohne: DHCP-Reservierungen und BT-Pairings brechen.

### 6.17 KVM / Virtualisierung

Die Firmware startet Linux in EL1 → kein `/dev/kvm`. EL2 nur über TravMurav/slbounce („Secure Launch") – stangor (LP #108/#109, 07/2025) brauchte zusätzlich einen Cache-Flush-Patch in `sl_ExitBootServices` und `return false` in `has_cntpoff()` (`include/kvm/arm_arch_timer.h`). Optionales Nebenprojekt; ohne KVM auch kein muvm (16K-Ausweg) und keine VMs.

### 6.18 TPM / Secure Boot

Pluton/TPM ist unter DT-Boot nicht erreichbar (kein Node, SPI-Pins reserviert; unverifiziert) → keine TPM-gebundene LUKS-Entsperrung. `systemd.tpm2_wait=0` (Fedora-Rezept) vermeidet 90-s-Wartezeiten, falls systemd auf TPM wartet. Secure Boot bleibt aus (unsignierter Kernel); dtbloader würde Secure Boot mit DTB-Hash unterstützen, ist aber nicht im Einsatz.

---

## 7 Optimierung

### 7.1 CPUfreq, Boost, Governor

- X1E80100 nutzt **kein** `qcom-cpufreq-hw`, sondern SCMI-Perf über den CPUCP-Mailbox-Controller (Serie „qcom: x1e80100: Enable CPUFreq", Sibi Sankar, V6 12.06.2024; Treiber `qcom-cpucp-mbox` + `scmi-cpufreq`). Boost ist in scmi-cpufreq seit 6.9 standardmäßig aktiv (turbo-OPPs). Config passt: ARM_SCMI_CPUFREQ=y, QCOM_CPUCP_MBOX=m, ENERGY_MODEL=y, schedutil, TEO, SCHED_CLUSTER, UCLAMP. Da QCOM_CPUCP_MBOX ein Modul ist, gehört es in die Initramfs (dracut hostonly nimmt es nach dem ersten Boot mit), sonst läuft der Kernel bis zum Root-Mount ohne cpufreq.
- Prüfen: `scaling_driver` (erwartet `scmi`), `scaling_available_frequencies`, `cpuinfo_max_freq`, `/sys/devices/system/cpu/cpufreq/boost`, `/sys/kernel/debug/energy_model`, `sysctl kernel.sched_energy_aware`. EAS setzt asymmetrische Kapazitäten voraus – bei 12 identischen Oryon-Kernen bleibt EAS vermutlich inaktiv, nur Cluster-Packing wirkt (Hintergrundwissen, unverifiziert).
- Governor: schedutil belassen; auf Akku Boost abschalten (`echo 0 > /sys/devices/system/cpu/cpufreq/boost`) statt Governor-Wechsel.
- Seit Rev. 3 hat die CPU-Drosselung bei 85 °C Vorrang vor dem Boost – wer unter Dauerlast misst, sollte die Thermal-Zonen mitprotokollieren (Abschnitt 6.15).
- Patch „arm64/cpufreq: report and track frequencies above 4.19 GHz" (Oleg Keri, 06.09.2026; u64-Überlauf in `arch_freq_get_on_cpu()`, stale `capacity_freq_ref` bei nachträglichem Boost) ist primär X2-Elite-relevant, der zweite Teil evtl. auch X1E – Merge-Status offen.

### 7.2 TLP oder power-profiles-daemon

- Ubuntu-Default ist ppd (GNOME-/KDE-Integration). Ob ppd auf X1E ohne ACPI `platform_profile` und ohne intel/amd-pstate mehr als den Placeholder-Treiber hat, ist **unverifiziert** – Profile könnten wirkungslos sein. (scuggo/x1e-nixos führt einen `platform-profile-no-acpi.patch` – Kandidat, falls Profile gewünscht sind.)
- TLP-Variante (ppd dann deinstallieren): `CPU_SCALING_GOVERNOR_ON_AC/BAT=schedutil`, `CPU_BOOST_ON_AC=1`, `CPU_BOOST_ON_BAT=0`, `RUNTIME_PM_ON_BAT=auto`, `PCIE_ASPM_ON_BAT=powersupersave` (Achtung: die NixOS-Config nennt SSD-ASPM als mögliche Lockup-Ursache – bei Hängern zuerst ASPM lockern), `WIFI_PWR_ON_BAT=on`, `USB_AUTOSUSPEND=1`.
- Alternativ ppd behalten und Boost per udev-/systemd-Unit auf Akku schalten.
- Referenz ohne Linux-Zahlen: Windows 13,8" bis 20 h Video (Hersteller), Reviews ~22 h 50 min; TUXEDO stellte sein X1E-Gerät u. a. ein, weil Windows-Akkulaufzeiten unter Linux nicht erreichbar waren. Eigene Messung mit `powertop`/`upower` ist Pflicht (Idle-Leistung, s2idle-Drain über Nacht).

### 7.3 Thermik

`sensors`, `cat /sys/class/thermal/thermal_zone*/type` und `…/temp`, Cooling-Devices beobachten. Seit Rev. 3 drosselt der Kernel ab 85 °C selbst (Abschnitt 6.15); der Governor `power_allocator` (in der Config vorhanden) ist erst interessant, wenn `step_wise` unter Dauerlast unbefriedigend regelt. Der Lüfter bleibt EC-Sache.

### 7.4 GPU-Stack

Ubuntu 26.04: `mesa-vulkan-drivers 26.0.3-1ubuntu1`. Für aktuelle a7xx-Fixes `ppa:kisak/kisak-mesa` (26.2.x; Rückbau `ppa-purge`). Turnip auf a7xx ist Vulkan-1.4-konform (die Mesa-Doku nennt veraltet „1.3 für 6xx"); Freedreno OpenGL 4.5 / ES 3.2, a7xx seit Mesa 24.3; Zink nur bei GL-4.6-Bedarf. Das Concept-PPA hat eigene mesa-Pakete – nicht mischen.

### 7.5 Video-Decode (iris)

- `VIDEO_QCOM_IRIS=m` (Treiber seit 6.15, X1E80100 auf Dell XPS 13 9345 getestet; H.264/H.265/VP9-Decode, H.264/H.265-Encode) und `VIDEO_QCOM_VENUS=m` sind beide gesetzt.
- **Neu in Rev. 3:** Der iris-Knoten (`video-codec@aa00000`, compatible `qcom,x1e80100-iris`, definiert in `hamoa.dtsi`) wird im Romulus-DT aktiviert und bekommt die Vendor-Firmware zugewiesen: `&iris { firmware-name = "qcom/x1e80100/microsoft/Romulus/qcvss8380.mbn"; status = "okay"; }`. Die Datei liegt seit dem 13.09.2026 im Firmware-Paket. Andere X1E-Boards aktivieren den Knoten genauso mit Vendor-Firmware; für den Romulus ist das **noch nicht auf Hardware getestet**.
- Nach dem Boot prüfen, ob und was bindet: `dmesg | grep -iE 'iris|venus'`, `v4l2-ctl --list-devices`. Nutzung nur über V4L2-stateful: GStreamer `v4l2h264dec`/`v4l2h265dec`, `mpv --hwdec=v4l2m2m`; Browser dekodieren weiterhin per CPU. Wenn `venus` stört, im nächsten Build `VIDEO_QCOM_VENUS` abschalten.
- `qcvss8380_pa.mbn` und `qcav1e8380.mbn` (AV1-Encoder) liegen ebenfalls im Paket, werden aber von keinem Knoten referenziert – orvitpng/nix1e nutzt sie für HW-Encode/Decode (H.264/HEVC/AV1/VP9), für unseren Kernel **unverifiziert**.

### 7.6 Desktop, Wayland, Skalierung

2304x1536 auf 13,8" ≈ 201 ppi → 150 % (logisch 1536x1024) oder 175 %. GNOME 50 (Ubuntu 26.04) ist Wayland-only mit fraktionaler Skalierung und VRR per Default; KDE Plasma 6.3+ hat sauberes Fractional Scaling (6.6.3 mit geringerem Ressourcenverbrauch). Firefox als `.deb`/Flatpak statt Snap (Snap-Abstürze laut Community-README); Chrome arm64 `.deb` mit `--ozone-platform=wayland`. Für VRR-Experimente führt scuggo/x1e-nixos einen `msm-vrr-avr.patch` (nicht in unserem Tree).

### 7.7 Seitengröße: 4K bleibt

FEX braucht einen 4K-Host-Kernel, der Ubuntu-Steam-Snap für arm64 (FEX-basiert, 01/2026) läuft nicht auf 16K, Asahi listet weiterhin kaputte 16K-Software (hardened_malloc, notion-app, Waydroid; Chromium/Electron ≥ 102 und Wine ≥ 10.5 gefixt). Der 16K-Ausweg muvm setzt KVM voraus – auf dem SL7 nicht vorhanden. Entscheidung: **ARM64_4K_PAGES** (so gebaut).

### 7.8 zram, Swap, Dateisystem

- zram statt zswap: `systemd-zram-generator` oder `zram-tools`, Algorithmus zstd (`CRYPTO_ZSTD=m`), Größe ~50 % RAM, `zswap.enabled=0` sicherstellen (ZSWAP ist nicht default-on), `vm.swappiness` ~150–180 für zram. Kein Hibernate.
- Dateisystem: ext4 (built-in, geringstes Risiko) oder btrfs mit `compress=zstd:1` + Snapshots (BTRFS=m); `discard=async`/`fstrim.timer`. Keine X1E-spezifischen Einschränkungen bekannt.

### 7.9 Boot-Zeit

Ubuntu 26.04 arm64 nutzt **dracut** (nicht initramfs-tools): `dracut --force` erzeugt standardmäßig hostonly-Images; nach dem ersten erfolgreichen Boot neu bauen, damit nur benötigte Module drin sind. NVMe an pcie6a braucht keine Firmware; GPU-Zap-/ADSP-/WLAN-Firmware dürfen vom Root-FS geladen werden (msm/ath12k nicht in die Initramfs zwingen). `systemd-analyze blame`/`critical-chain` messen; stubble-Image beibehalten; `GRUB_TIMEOUT=5` (Installer) ggf. senken. TPM-Wartezeiten: `systemd.tpm2_wait=0`, falls beobachtet.

### 7.10 x86-Kompatibilität: FEX, box64, Steam, Widevine

- FEX: `ppa:fex-emu/fex` oder `InstallFEX.py`, Paket `fex-emu-armvX.X`, RootFS Ubuntu 24.04 (FEXRootFSFetcher); FEX-2609 (08.09.2026) bringt einen JIT-Disk-Cache (`FEX_DISKCACHE=1`); Tutorial (20.10.2025, u. a. T14s Gen6 X1E): Portal/Portal 2/Rimworld/Deadlock liefen, Dota 2 nicht. Steam über den Canonical-Steam-Snap für arm64 (FEX integriert) – funktioniert nur mit 4K-Pages.
- box64: in dieser Recherche nicht verifiziert.
- Widevine: Google Chrome für arm64 Linux ist seit Juli/August 2026 offiziell (Chrome 150, `google-chrome-stable_current_arm64.deb`/APT-Repo) mit nativem Widevine unter `/opt/google/chrome/WidevineCdm/_platform_specific/linux_arm64/` – nur L3/„Software Secure", Streaming bis 720p/1080p. Für Firefox/Chromium: AsahiLinux/widevine-installer.

### 7.11 Kernel-Config-Feinschliff für den nächsten Build

| Option | Jetzt | Vorschlag |
|---|---|---|
| IOMMU_DEFAULT_DMA_STRICT=y | strict | erst `iommu.strict=0` auf der Cmdline messen (NVMe/WLAN-Durchsatz), dann ggf. Config auf lazy |
| PREEMPT_DYNAMIC (Full) | ok | `preempt=voluntary` testbar ohne Rebuild |
| NO_HZ_FULL=y | harmlos ohne `nohz_full=` | belassen |
| SURFACE_FAN | nicht gesetzt | =m aktivieren, um zu sehen, ob der SAM-EC ein Fan-Subsystem meldet (harmlos) |
| SURFACE_PLATFORM_PROFILE | prüfen | =m, falls SAM Profile anbietet (Performance-Modi wie unter Windows); dazu passt scuggos `platform-profile-no-acpi.patch` |
| ZRAM_DEF_COMP | lzo-rle | zstd oder lz4 als Default |
| ZSWAP | =y, nicht default-on | aus lassen (zram) |
| LTO | none (GCC) | Clang-ThinLTO nicht priorisieren (kein belegter X1E-Nutzen, Build-Risiko, Ubuntu-Packaging auf GCC) |
| VIDEO_QCOM_VENUS | =m | deaktivieren, falls iris bindet und venus stört (Abschnitt 7.5) |
| RTC_DRV_EFI | prüfen | =y als Fallback für die RTC-Frage |
| Thermal-Trips | 85 °C passiv (Rev. 3) | nach Lastmessung nachjustieren; `power_allocator` erst bei Bedarf |
| Speaker-Schutz | Kernel-Volume-Limit (Rev. ≥ 2) | falls das Limit nicht genügt: Amps im DTS stilllegen (`&left_spkr`/`&right_spkr`/`&swr0` auf `disabled`, `wsa-dai-link` löschen) – erhält Kopfhörer und Mikrofone, anders als die Modulsperre |
| MODULES=dep-Äquivalent | dracut hostonly | nach erstem Boot `dracut --force --hostonly` |

---

## 8 Build-Rezept WSL2 (Cross-Compile auf dem x86-PC)

Alle Skripte liegen unter `C:\Users\Martin\Desktop\Projekt Linux ARM\build\` und werden **als root in WSL2 (Ubuntu 26.04)** ausgeführt. WSL aus **PowerShell** starten (`wsl -d Ubuntu -u root`), nicht aus Git-Bash (verbiegt `/mnt/c`-Pfade). In WSL: `bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/<skript>.sh"`. Arbeitsverzeichnis ist `/work/sl7/` im WSL-Dateisystem (schnell, 925 GB frei). Stolperfallen (gelöst): CRLF/Modus 777 bei Kopien von `/mnt/c` (`sed 's/\r$//'`, `chmod`), `LC_ALL=C`, `bindeb-pkg -j32` hat eine mkdir-Race in `dtbs_install` (→ `-j1`), `linux-headers` braucht `libssl-dev:arm64`, `qemu-user-static` existiert in 26.04 nicht mehr (→ `qemu-user` + `qemu-user-binfmt`), `pipefail` + `grep -q` bricht Pipelines ab.

### 8.1 Reihenfolge

| # | Skript | Was es tut | Dauer |
|---|---|---|---|
| 1 | `wsl-setup-toolchain.sh` | `apt-get install` der Cross-Toolchain (`gcc-aarch64-linux-gnu`, binutils, libc6-dev-arm64-cross), Kernel-Build-Deps (bc, bison, flex, libssl-dev, libelf-dev, dwarves, kmod, cpio, fakeroot, devscripts, debhelper, dpkg-dev, equivs), `device-tree-compiler`, `msitools` (msiextract), `qemu-user` + `qemu-user-binfmt`, `debootstrap`, `zstd`, `xz-utils`, `ccache`, clang/lld (optional), squashfs/xorriso; Versionsausgabe; prüft binfmt `qemu-aarch64` | einmalig, Minuten |
| 2 | `wsl-clone-kernels.sh` | klont `ProgrammerIn-wonderland/ELLX-Kernel` Branch `7.0-sl7` nach `/work/sl7/kernel/ellx-7.0-sl7` und Ubuntu-Concept `~ubuntu-concept/ubuntu/+source/linux/+git/resolute` Branch `qcom-x1e-7.0` nach `concept-qcom-x1e-7.0` (je `--depth 1 --single-branch`); zeigt HEAD, Makefile-Version und Romulus-DTS-Dateien. **Danach `git fetch --tags --depth 1 origin` im ELLX-Klon**, sonst fehlt der Tag `7.0.0-rc4-12` | einmalig |
| 3 | `wsl-setup-multiarch.sh` | `dpkg --add-architecture arm64`, beschränkt archive/security.ubuntu.com auf amd64, legt `arm64-ports.sources` (ports.ubuntu.com resolute) an, installiert `libssl-dev:arm64` + `libelf-dev:arm64`; ruft am Ende `wsl-build-kernel.sh` auf – deshalb **mit `NOBUILD=1` starten**, sonst läuft sofort ein vollständiger Build mit `PKGREV=1` | einmalig |
| 4 | **`wsl-apply-sl7-patches.sh` (kanonisch)** | setzt `sl7-build` frisch auf Tag `7.0.0-rc4-12` (lokale Änderungen werden verworfen), stellt `debian`, `debian.master`, `debian.qcom-x1e` wieder her, wendet `patches-upstream/sl7-tree-full.diff` per `git apply` an (CRLF-Strip), zeigt `git diff --stat` und baut den romulus13-DTB als Testlauf | Sekunden |
| 5 | `wsl-build-kernel.sh` (`TAG`, `PKGREV`, `NOBUILD=1` nur konfigurieren, `RECONFIG=1` .config neu erzeugen) | [1] Arbeitszweig `sl7-build` (vorhandene Patches bleiben); [2] wendet die dwc3-Patches aus `/work/sl7/patches/community/outgoing/dwc3-usb/` an (der Ordner **muss** existieren, sonst bricht das Skript ab) und prüft: `reinit-phy-on-resume` im DTS, rfkill-Hack, `drivers/hid/spi-hid`; [3] `.config` aus `annotations --arch arm64 --flavour qcom-x1e --export` + `scripts/config`-Anpassungen + `olddefconfig`; [4] `make -j32 Image.gz vmlinuz.efi modules dtbs` (Log `/work/sl7/out/build.log`); [5] `make -j1 bindeb-pkg DPKG_FLAGS=-d KDEB_PKGVERSION=7.0.0~rc4-sl7-$PKGREV`, kopiert `.deb`, romulus13/15.dtb, `.config` nach `/work/sl7/out/7.0.0-rc4-sl7-$PKGREV/`; [6] Kopie nach `build/out/…` + `SHA256SUMS`, stellt `debian/`, `debian.master`, `debian.qcom-x1e` per `git checkout` wieder her (bindeb-pkg überschreibt sie); [7] ruft `wsl-build-stubble.sh` auf | ~12 min Kernel + ~10 min Paketierung |
| 6 | `wsl-build-stubble.sh` (`PKGREV` beachten) | installiert `systemd-ukify`, `python3-libfdt`, `python3-pefile`; lädt `stubble:arm64` (`apt-get download`, `dpkg-deb -x` nach `/work/sl7/stubble/a64`); `finddtbs.py` sucht die zu den HWIDs passenden DTBs; `ukify build --linux=vmlinuz.efi --stub=stubble.efi --hwids=… --sbat=@… --devicetree-auto=<dtb>…` → `vmlinuz-7.0.0-rc4-sl7.stubble`; prüft Sektionen (`objdump -h`) und „Romulus"-Strings; kopiert nach `build/out/…` und hängt SHA256 an | Sekunden |
| 7 | **`wsl-verify-out.sh` (`REV=<n>`)** | prüft eine fertige Revision: Zahl der `.dtbauto`-Sektionen, ob der romulus13-DTB (Größe als Hex) im stubble-Image steckt, ob `qcvss8380`/`cooling-device` als Strings enthalten sind, ob `touchscreen@0`, `touchscreen@34`, `cooling-device` und `qcvss8380` im DTB stehen, ob der DTB im `.deb` liegt, Paketversion, `sha256sum -c SHA256SUMS` | Sekunden |
| 8 | `wsl-extract-firmware.sh` (`MSI_URL=…` oder `MSI_FILE=…`) | [1] lädt das MSI; [2] `msiextract` nach `/work/sl7/firmware/msi`, legt die Blobs (ADSP/CDSP/`*.jsn`/Zap-Shader/**Video**) nach `lib/firmware/updates/qcom/x1e80100/microsoft/Romulus/` + flache Kopie in `microsoft/`; listet alle weiteren `.mbn/.jsn/.elf/.tlv`; [3] holt `board-2.bin` (codelinaro main) + `ath12k-bdencoder`, `-e` → JSON, Python fügt den 1107-Namen zum 3378-Eintrag hinzu, `-c` → neue `board-2.bin`; [4] `tar -cJf build/out/sl7-firmware-msi-<ver>.tar.xz lib` + `.list.txt` + `.sha256` | Minuten (500 MB Download) |
| 9 | `wsl-arm64-chroot.sh` | prüft binfmt `qemu-aarch64` (F-Flag/statisch), `debootstrap --arch=arm64 --variant=minbase resolute` nach `/work/sl7/chroot-arm64`, sources.list, bind-mounts, installiert im Chroot initramfs-tools, zstd, kmod, grub-efi-arm64-bin, linux-firmware und die iptsd-Build-Deps (meson, ninja, cli11, eigen3, fmt, spdlog, inih, gsl, sdl2, hidrs) | einmalig, ~10 min |
| 10 | `wsl-chroot-test-kernel.sh` | kopiert das neueste `linux-image-*_arm64.deb` ins Chroot, `dpkg -i` (postinst-Hooks), listet `/boot`, DTBs unter `/usr/lib/linux-image-<ver>/qcom/`, Modulzahl und ob ath12k, spi-hid, qcom_q6v5_pas, msm, phy-qcom-qmp-pcie, pcie-qcom, qcom_battmgr, ucsi_glink, snd-soc-x1e80100/wcd9385/wsa884x, ov02c10, qcom-camss, hid-multitouch, pmic_glink_altmode enthalten sind | Minuten (qemu) |
| 11 | `wsl-chroot-test-dracut.sh` (`KVER`) | installiert dracut im Chroot und baut `dracut --force --kver 7.0.0-rc4-sl7` – der auf Ubuntu 26.04 tatsächlich verwendete Weg; zeigt Module/Firmware/DTB im Image | Minuten (qemu) |
| – | `build/inspect/*.sh` | Diagnose- und Hilfsskripte außerhalb des Build-Pfads: `wsl-check-safety.sh` (Speaker-Limit-Grep im ELLX-Tree und im Concept-Branch `resolute-x1e`, Tabelle aller SL7-relevanten Config-Optionen), `wsl-fix-dts-0011-0012.sh` (Reparatur der alten, fehlerhaften Einzelpatches – durch den Gesamt-Diff abgelöst), `wsl-inspect-*` (ELLX-Prebuilts, Community-Patches, questing-x1e-ISO, stubble, Boot-Mechanismus), `wsl-inspect-extras.sh` (Thermal-Zonen, SAM-EC- und iris-Knoten im Tree), `wsl-test-installer.sh` (Probelauf des Ziel-Installers im arm64-Chroot mit `DRYRUN=1`), `wsl-shellcheck.sh`, `wsl-syntax-check.sh` | – |
| – | `wsl-apply-extra-patches.sh` | **veralteter Weg** (Einzelpatches nacheinander, 0010/hamoa/speaker-limit). Nur noch Referenz für die Patch-Herkunft; anzuwenden ist `wsl-apply-sl7-patches.sh` | – |

Sonstige Artefakte (nicht per Skript, aber vorhanden): `sl7-mac_1.0.2_all.deb` (aus `gits/valeronm_sl7-mac` gebaut), `ellx-iptsd/` (ELLX-Deb + Kalibrierung + Anleitung), `ellx-fixes/` (`display-fix`, `trackpad` – ELLX-Sleep-Hooks), `build/ellx-ref/microsoft-firmware.tar.xz` (ELLX-Firmware zum Abgleich).

### 8.2 Kompaktablauf (reproduzierbarer Neubau bis Rev. 3)

```
# in WSL als root
B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build"
G="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/gits"
bash "$B/wsl-setup-toolchain.sh"
bash "$B/wsl-clone-kernels.sh"
# Tag nachladen (der Klon ist --depth 1 --single-branch, sonst schlaegt der Checkout fehl):
git -C /work/sl7/kernel/ellx-7.0-sl7 fetch --tags --depth 1 origin
# dwc3-Community-Patches an die von wsl-build-kernel.sh erwartete Stelle (Pflicht, sonst bricht [2/6] ab):
mkdir -p /work/sl7/patches && rm -rf /work/sl7/patches/community
cp -r "$G/giantdwarf17_linux-surface-laptop-7/patches" /work/sl7/patches/community
NOBUILD=1 bash "$B/wsl-setup-multiarch.sh"  # ohne NOBUILD=1 startet direkt ein voller Rev.-1-Build
bash "$B/inspect/wsl-check-safety.sh"       # Speaker-Limit im Tree? -> fehlt, daher im Gesamt-Diff
bash "$B/wsl-apply-sl7-patches.sh"          # frischer Tag + sl7-tree-full.diff (= Rev.-3-Stand)
PKGREV=3 bash "$B/wsl-build-kernel.sh"      # baut Kernel + Pakete + stubble-Image
REV=3 bash "$B/wsl-verify-out.sh"           # Artefakte und Prüfsummen kontrollieren
MSI_URL="https://download.microsoft.com/download/b7ca2c3f-d320-4795-be0f-529a0117abb4/SurfaceLaptop7_ARM_Win11_26100_26.053.36539.0.msi" \
  bash "$B/wsl-extract-firmware.sh"
bash "$B/wsl-arm64-chroot.sh"
bash "$B/wsl-chroot-test-kernel.sh"
KVER=7.0.0-rc4-sl7 bash "$B/wsl-chroot-test-dracut.sh"
```

### 8.3 Installation auf dem Zielgerät

`build\out\` (kompletter Ordner: Kernel-Revisionen, Firmware-Tarball, iptsd, sl7-mac, ellx-fixes, `sl7-install-on-laptop.sh`) auf USB → auf dem Laptop erst `sudo DRYRUN=1 bash sl7-install-on-laptop.sh`, dann `sudo bash sl7-install-on-laptop.sh` (Details Abschnitt 5.3 C/D). Das Skript nimmt automatisch die höchste Revision `7.0.0-rc4-sl7-*` neben sich und zählt am Ende die Warnungen.

### 8.4 Fallback-Boot

GRUB-Eintrag „SL7 Fallback" (plain-Kernel + `devicetree /boot/sl7-romulus13.dtb`, gleiche Cmdline; bei eigener `/boot`-Partition ohne `/boot`-Präfix). Falls auch das nicht bootet: Ubuntu-generic-Kernel aus „Advanced options"; im Notfall vom Ventoy-Stick starten, `mount` + `chroot`, `apt remove linux-image-7.0.0-rc4-sl7`, `update-grub`.

### 8.5 Rebuild nach Änderungen

1. Änderung im Tree vornehmen (`/work/sl7/kernel/ellx-7.0-sl7`, Zweig `sl7-build`).
2. **Gesamt-Diff neu erzeugen** – das ist der kanonische Stand:
   ```
   cd /work/sl7/kernel/ellx-7.0-sl7
   git diff 7.0.0-rc4-12 -- . ':!debian' ':!debian.master' ':!debian.qcom-x1e' \
     > "$B/patches-upstream/sl7-tree-full.diff"
   ```
   (Gegen den **Tag** diffen, nicht gegen HEAD – sonst ist der Diff leer, sobald Änderungen commitet wurden; die drei Ubuntu-Packaging-Verzeichnisse werden ausgeschlossen, weil `bindeb-pkg` sie überschreibt. Identischer Befehl in `Build-Rezept.md` 9.3. Die Einzelpatchdateien nur noch als Herkunftsnachweis pflegen – handgeschriebene Hunk-Zähler waren die Fehlerquelle bei 0011/0012.)
3. Nur DTB testen: `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/x1e80100-microsoft-romulus13.dtb` und mit `dtc -I dtb -O dts` kontrollieren; für den Einsatz braucht das Kernel-Paket trotzdem einen Rebuild, weil die DTBs im `.deb` liegen (schneller Test auf dem Gerät: DTB per GRUB-`devicetree` beim plain-Kernel).
4. Config-Änderung: `RECONFIG=1` (neu aus den Annotations) oder `scripts/config` im Tree, dann `PKGREV=<n+1> bash wsl-build-kernel.sh` (inkrementell, `.config` bleibt), danach `REV=<n+1> bash wsl-verify-out.sh`.
5. Ergebnis in `build/out/7.0.0-rc4-sl7-<n>/` inkl. neuem stubble-Image; auf dem Laptop erneut `sl7-install-on-laptop.sh` (idempotent; nimmt die höchste Revision).
6. Basiswechsel (Concept 7.2): `dget` des `.dsc` aus der PPA, neuen Tree unter `/work/sl7/kernel/`, `K=` in den Skripten anpassen, SL7-Patchsatz rebasen (spi-hid v4-Serie, rfkill-Hack, Kamera-DT, QSPI-Hack, dwc3, hamoa-PHY, Touchscreen, iris, Thermal), Speaker-Limit prüfen.

---

## 9 Offene Punkte & Risiken (nach Schwere geordnet)

| # | Risiko / offener Punkt | Schwere | Stand / Gegenmaßnahme |
|---|---|---|---|
| 1 | **Lautsprecherschaden** durch Audio ohne aktive Speaker-Protection | **kritisch (Hardware)** | Standardschutz = Ubuntus Kernel-Volume-Limit (Rev. ≥ 2, `platform_max` am ALSA-Regler, wirkt auch gegen `amixer` und „Pro Audio"); Hausregeln: max. 70 %, nie das Profil „Pro Audio", keine manuellen WSA-/PA-Regleränderungen. Harte Modulsperre nur als Opt-in (`SL7_NO_SPEAKER=1`) und dann **ohne jeden Ton**. Nach dem ersten Boot `amixer -c0 contents | grep -A3 'PA Volume'` (platform_max = 6). Offen: ob der UCM-DMI-Regex real matcht; spätere saubere Lösung = Amps im DTS stilllegen (Abschnitt 6.5). |
| 2 | **Kein Boot-Test auf dem Gerät**: Kernel Rev. 3, stubble-Image, Firmware und Installer sind nur im arm64-Chroot geprüft; das Surface war in dieser Sitzung nicht erreichbar | hoch | Ventoy 1.1.17 + SHA256-Prüfung, Concept-ISO als Zweit-ISO, GRUB-Fallback-Eintrag, Recovery-Stick, `DRYRUN=1` vor der Installation. (Dass das offizielle 26.04-arm64-ISO auf dem SL7 startet, ist inzwischen primär belegt – Abschnitt 5.1.) |
| 3 | **Touchscreen-DT-Nodes experimentell** – zwei Varianten gleichzeitig (spi10/i2c8); die i2c8-Variante wurde upstream abgelehnt, die spi10-Variante stammt aus umstrittenen Beiträgen; Fehlverhalten (Bus-Timeouts, Probe-Fehler, Resume-Probleme) möglich | hoch | Nach dem Boot `dmesg` prüfen; störenden Node auf `status = "disabled"` und neu bauen; Ergebnis in Issue #13 / #1590 melden |
| 4 | **Kernel-Wartung**: ELLX seit 14.05.2026 tot, Community-Maintainer haben ihre Geräte verkauft; SL7-Teile (spi-hid, QSPI-Hack, rfkill-Hack, Kamera-DT, dwc3, iris, Thermal) sind nicht upstream – jeder Basiswechsel ist ein manueller Rebase | hoch | Eigenbau-Pipeline hält den Stand reproduzierbar (`sl7-tree-full.diff` + `wsl-apply-sl7-patches.sh`); spi-hid v4/QSPI-Upstreaming (dwhinham) und Concept-7.2-PPA beobachten |
| 5 | **Backports ungetestet**: hamoa-USB-PHY-Supply-Fix (7.3-rc1) und dwc3-Reinit-Patches wirken auf die USB-PHY-Versorgung; Fehlverhalten → USB-C/USB-A tot | mittel–hoch | Rev. 1 (nur dwc3) als Vergleichspaket behalten; USB nach Boot und nach Resume testen |
| 6 | **Touchpad** hängt von Out-of-tree-QSPI-Hack, iptsd-Fork, Kalibrierung, Service/udev ab; Multitouch „wonky"; Wedge nach Suspend; iptsd-SIGILL (BTI) möglich | mittel | Installer legt Service/udev/Kalibrierung an; Hook `trackpad`; Reset-/Regulator-Aufräumen in Rev. 3; `objcopy --remove-section=.note.gnu.property` oder Neubau im Chroot; Windows-Reboot als Reset |
| 7 | **Neu in Rev. 3, ungetestet:** iris-Videodecoder (DT-Aktivierung + `qcvss8380.mbn`) und CPU-Thermal-Trips bei 85 °C. Fehlerbilder: iris bindet nicht oder bricht ab, Drosselung greift zu früh/zu spät | mittel | `dmesg | grep -i iris`, `v4l2-ctl --list-devices`, Thermal-Zonen und Cooling-Devices unter Last beobachten; beide Änderungen lassen sich im DTS einzeln zurücknehmen |
| 8 | **Firmware-Updates nur über Windows**; UEFI-/EC-Updates kommen per Windows Update/MSI | mittel | Windows behalten (Dual-Boot), regelmäßig booten |
| 9 | **Cmdline-Unsicherheit**: `clk_ignore_unused pd_ignore_unused` (gesetzt) vs. shenkis 2024-Rat, sie zu entfernen; `arm64.nopauth`/`efi=noruntime` nicht gesetzt | mittel | Boot-Tests in dieser Reihenfolge: Standard → ohne die beiden → mit `arm64.nopauth` → mit `efi=noruntime` (letzteres bricht `sl7-mac`) |
| 10 | **Akkulaufzeit / s2idle-Drain / Thermik** unbekannt (nur 6.14-Berichte 2025; Phoronix-Shutdowns auf Acer) | mittel | Messen (`powertop`, `upower`, über Nacht); TLP/Boost-off; Thermal-Zonen beobachten; Lüfter EC-autonom, `SURFACE_FAN` im nächsten Build |
| 11 | **USB4/Thunderbolt** fehlt; DP-Hotplug unzuverlässig ohne glathe-Patch; TB4-Docks nur PD+USB2 | mittel | Cold-Plug, Full-Featured-USB-C-Kabel; glathe-Serie (Discourse 07/2026) ggf. backporten |
| 12 | **Concept 7.2 / Speaker-Limit**: ob `linux-qcom-x1e 7.2.0-18.18` den SAUCE-Patch enthält, ist ungeprüft; Quellbranch unbekannt; 7.2 hat den USB-PHY-Fix nicht | mittel | vor dem Umstieg `dget` + grep in `sound/soc/qcom/x1e80100.c`; PHY-Fix, iris und Thermal mitnehmen |
| 13 | **RTC** unklar (README ✅ vs. Issue #8) | niedrig | `ls /sys/class/rtc; timedatectl`; RTC_DRV_EFI/PM8XXX prüfen; NTP reicht |
| 14 | **MAC-Adressen** zufällig ohne sl7-mac; `efi=noruntime` würde es brechen | niedrig | sl7-mac wird installiert und beim Setup aufgerufen |
| 15 | **KVM** fehlt (EL1) → keine VMs, kein muvm | niedrig (Feature) | slbounce-Nebenprojekt (Cache-Flush-Patch + `has_cntpoff()`) |
| 16 | **TPM/Pluton, IR-Kamera, Ambient-Color-Sensor, Tastaturbeleuchtung/Fn, fwupd, Surface-Connect-USB/Display** ohne Linux-Support bzw. ohne Quellenstand | niedrig | dokumentiert als nicht unterstützt; `i2c0`/`i2c4`-Adressen per `i2cdetect`/ACPI-Dump identifizieren |
| 17 | **Kamera-Bildqualität** (Grünstich/Strobing); DT-Patch nicht Mainline | niedrig | libcamera-Tuning aus dem Community-Repo |
| 18 | **board-2.bin nicht upstream** – bei jedem linux-firmware-Update bleibt unsere Datei in `updates/` maßgeblich (gewollt), aber Chip-Firmware-Updates (amss.bin) könnten das Board-Daten-Format ändern | niedrig | Einreichung der Surface-IDs an ath12k-firmware; nach Firmware-Updates `dmesg | grep ath12k` |
| 19 | **Secure Boot aus**, kein TPM-LUKS | niedrig | akzeptiert; dtbloader-Weg mit DTB-Hash wäre eine Option |
| 20 | Recherche-Lücken: Discourse-Posts ~#1790–#2157 ungelesen; spi-hid-Status über v3 hinaus (lore gesperrt); Fedora 45; dtbloader-Release; ELLX-ISO-Basis; ob `proprietary-firmware.tar.gz` und `microsoft-firmware.tar.xz` identisch sind | Info | bei Bedarf über GitLab-/GitHub-API und lkml.iu.edu/ratatoskr.run nachziehen (git.kernel.org, lore, git.launchpad.net blocken automatisierte Abrufe) |

**Gestrichen gegenüber dem Entwurf:** das Risiko „kein SL7-Primärbericht für das offizielle 26.04-ISO" (durch drei Primärbelege erledigt, Abschnitt 5.1) und das Risiko „Ventoy/`invalid magic number`" (war ein korrupter ISO-Download, vom Melder selbst aufgeklärt, Abschnitt 5.2).

---

## 10 Quellen

### 10.1 Lokal (Build-Host, 12./13.09.2026 – Vorrang vor Web-Angaben)
- `C:\Users\Martin\Desktop\Projekt Linux ARM\build\workflow\local-facts.md` (lokal verifizierte Fakten inkl. Nachrecherche-Ergebnissen vom 13.09.2026)
- `C:\Users\Martin\Desktop\Projekt Linux ARM\build\workflow\corpus.md` / `corpus.json` (Recherche-Korpus, 7 Themen)
- `C:\Users\Martin\Desktop\Projekt Linux ARM\build\wsl-*.sh`, `build\inspect\*.sh`, `build\patches-upstream\*` (kanonisch `sl7-tree-full.diff`), `build\out\*` (Artefakte, Stand 13.09.2026)
- `C:\Users\Martin\Desktop\Projekt Linux ARM\build\out\sl7-install-on-laptop.sh`, `ellx-fixes\display-fix`, `ellx-fixes\trackpad`, `ellx-iptsd\instructions.txt`
- `C:\Users\Martin\Desktop\Projekt Linux ARM\docs\dts\x1e80100-microsoft-romulus.dtsi`, `x1e80100-microsoft-romulus13.dts` (ELLX-Stand)
- `C:\Users\Martin\Desktop\Projekt Linux ARM\gits\linux-surface-laptop-7-main\README.md`, `patches\`, `fix-board-2-wifi.sh`, `romulus-firmware-extract.sh` (Community-Repo, 06.08.2026)
- `C:\Users\Martin\Desktop\Projekt Linux ARM\docs\quellen\ls1590-comments-2026.json`, `nix1e\`, `x1e-nixos\`
- `C:\Users\Martin\Desktop\Projekt Linux ARM\hardware\SL7-Hardware-Dump.ps1`

### 10.2 Ubuntu / Distro / Installation
- https://documentation.ubuntu.com/release-notes/26.04/ (2026-04-23)
- https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/ (2026-04-23)
- https://cdimage.ubuntu.com/releases/26.04/release/ (Listing 2026-08-26; dort auch `SHA256SUMS`)
- https://www.ventoy.net/ (Ventoy 1.1.17, 2026-07-24)
- https://discourse.ubuntu.com/t/ubuntu-concept-snapdragon-x-elite/48800/1788 (tobhe, 2026-04-10)
- https://discourse.ubuntu.com/t/ubuntu-concept-snapdragon-x-elite/48800/1879 (2026-05-24)
- https://discourse.ubuntu.com/t/ubuntu-concept-snapdragon-x-elite/48800/2039 (glathe, USB-C/TB4, 2026-07-20)
- https://discourse.ubuntu.com/t/ubuntu-concept-snapdragon-x-elite/48800/last (Posts #2158 2026-09-02 / #2159 2026-09-03)
- https://discourse.ubuntu.com/t/faq-ubuntu-25-04-25-10-on-snapdragon-x-elite/61016 (2025-05-13, Edit 2025-06-25)
- https://discourse.ubuntu.com/t/faq-ubuntu-25-04-on-snapdragon-x-elite/61016/47 (2025-07-13)
- https://discourse.ubuntu.com/t/ubuntu-24-10-concept-snapdragon-x-elite/48800/216 (WLAN-Firmware, 2024/2025)
- https://www.phoronix.com/review/ubuntu-2604-snapdragon-x-elite (2026-07-24)
- https://www.phoronix.com/review/snapdragon-x-elite-linux-eoy2025 (2025-12-24)
- https://bugs.launchpad.net/ubuntu-concept/+bug/2084951 (2024-10-19 bis 2025-07-21; Kommentare #23, #29, #40, #44, #50, #80, #94–#111)
- https://bugs.launchpad.net/ubuntu-concept/+bug/2084951/comments/110 (hybris, 2025-07-20)
- https://api.launchpad.net/devel/bugs/2084951 und …/messages (abgerufen 2026-09-13)
- https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2149808 (Speaker overdrive, Tobias Heider, 2026-04-21; Fix 7.0.0-15.15 2026-04-22/29, 7.2.0-5.5 2026-08-18)
- https://launchpad.net/~ubuntu-concept/+archive/ubuntu/x1e/+packages (linux-qcom-x1e 7.2.0-18.18, 2026-09-09; abgerufen 2026-09-13)
- https://code.launchpad.net/~ubuntu-concept/ubuntu/+source/linux/+git/resolute (2026-09-13; `+ref/qcom-x1e-7.2` → 404)
- https://launchpad.net/ubuntu/+source/linux-qcom (2026-09-13)
- https://people.canonical.com/~platform/images/ubuntu-concept/ (Concept-Images)
- https://git.launchpad.net/~ubuntu-concept/debian-cd/commit/?id=cd47729460aa11b3a0207e1d09e623d4ffccbdd7 (DTB per SMBIOS-SKU)
- https://github.com/ubuntu/stubble (stubble, `dtb_override`)
- https://public.hgci.org/software/ELLX/ (Prebuilts, microsoft-firmware.tar.xz 2026-05-14, iptsd, fixes)
- https://public.hgci.org/software/ELLX/README.txt
- https://public.hgci.org/software/ELLX/installer/ (ISO 2026-06-11, README 2026-07-01)
- https://public.hgci.org/software/ELLX/installer/README-YOU-ARE-IN-GRAVE-DANGER.txt (2026-07-01)
- https://fedoraproject.org/wiki/Snapdragon_WoA_Laptop_Install (oldid=775997, 2026)
- https://fedoraproject.org/wiki/Changes/Automatic_DTB_selection_for_aarch64_EFI_systems
- https://www.phoronix.com/news/Fedora-44-ARM-OOTB (2025-12-15)
- https://github.com/kuruczgy/x1e-nixos-config (2026)
- https://github.com/orvitpng/nix1e (NixOS-Flake, Device-Trees, 2026-07)
- https://gist.github.com/cicorias/6da75542f9e2b4a7b6f58a61ba3979d6 (Omarchy/ALARM SL7 15", 2026-09-09)
- https://gist.github.com/joske/52be3f1e5d0239706cd5a4252606644b (ALARM Yoga Slim 7x, 2026-07-15)
- https://github.com/TravMurav/dtbloader (2026), https://github.com/TravMurav/slbounce (Secure Launch/EL2)
- https://ubuntu.fan/en/docs/ref/hardware/snapdragon (2026-06-24, Drittanbieter, low)
- https://www.tuxedocomputers.com/en/Discontinuation-of-ARM-notebooks-with-Snapdragon-X-Elite-SoC.tuxedo (2026)
- https://www.linaro.org/blog/linux-on-snapdragon-x-elite/ (2025-07-23)
- https://wiki.ubuntu.com/Kernel/BuildYourOwnKernel

### 10.3 Firmware
- https://www.microsoft.com/en-us/download/details.aspx?id=106120 (MSI 26.053.36539.0, Date Published 2026-06-25)
- https://download.microsoft.com/download/b7ca2c3f-d320-4795-be0f-529a0117abb4/SurfaceLaptop7_ARM_Win11_26100_26.053.36539.0.msi (HEAD 2026-09-13: 523 874 304 Bytes)
- https://support.microsoft.com/en-us/surface/drivers-firmware/download-drivers-and-firmware-for-surface-laptop
- https://archlinux.org/packages/core/any/linux-firmware-qcom/files/ (linux-firmware 20260910-1)
- https://gitlab.com/api/v4/projects/kernel-firmware%2Flinux-firmware/repository/tree?path=qcom/x1e80100&per_page=100 (2026-09-13)
- https://gitlab.com/api/v4/projects/kernel-firmware%2Flinux-firmware/repository/commits?path=qcom/x1e80100&per_page=30 (ADSP/CDSP-Updates bis 2026-08-28)
- https://gitlab.com/api/v4/projects/kernel-firmware%2Flinux-firmware/repository/commits?path=qcom/x1e80100/X1E80100-Romulus-tplg.bin&per_page=5 (2025-09-29, 2026-01-10)
- https://gitlab.com/api/v4/projects/kernel-firmware%2Flinux-firmware/repository/commits?path=ath12k/WCN7850/hw2.0/board-2.bin&per_page=20
- https://git.codelinaro.org/api/v4/projects/clo%2Fath-firmware%2Fath12k-firmware/repository/commits?path=WCN7850/hw2.0/board-2.bin&per_page=20 (letzter Commit fd7ddeb4, 2026-01-30)
- https://git.codelinaro.org/clo/ath-firmware/ath12k-firmware/-/raw/main/WCN7850/hw2.0/board-2.bin
- https://raw.githubusercontent.com/qca/qca-swiss-army-knife/master/tools/scripts/ath12k/ath12k-bdencoder (genau diese URL lädt `wsl-extract-firmware.sh`; abgerufen 2026-09-13)
- https://ratatoskr.run/linux-wireless/2025/03/12213194/t (board-2.bin 1eac:8001, 2025-03/2026-02-11)
- https://ratatoskr.run/linux-firmware/2026/05/13471283/t (ADSP-Update, 2026-05)
- https://ratatoskr.run/linux-firmware/2026/08/17473707/t (CDSP-Update, 2026-08)
- https://gitlab.com/kernel-firmware/linux-firmware/-/merge_requests/328 (WCN785x BT-Firmware, 2024-10-14)
- https://ratatoskr.run/linux-firmware/2026/09/17496229/t (hmtnv20.b201/b202, 2026-09-02)
- https://github.com/alejandroqh/qcom-firmware-updater (2026-02)
- https://patchew.org/linux/20250702-hp-x14-x1p-v1-0-219356e83207@oldschoolsolutions.biz/20250702-hp-x14-x1p-v1-3-219356e83207@oldschoolsolutions.biz/ (Purwa-Zap-Pfad, 2025-07)
- https://raw.githubusercontent.com/torvalds/linux/master/drivers/base/firmware_loader/main.c (2026-09-13)
- https://bugs.launchpad.net/ubuntu/+source/linux-firmware/+bug/1942260 (Ubuntu zstd-Firmware)
- https://manpages.debian.org/unstable/qcom-firmware-extract/qcom-firmware-extract.8.en.html
- https://code.launchpad.net/~shenki/ubuntu/+source/qcom-firmware-extract/+git/qcom-firmware-extract/+ref/surface-laptop-7 (2024-11-27)
- https://ozlabs.org/~joel/0001-Add-Microsoft-Surface-Laptop-7-13.patch

### 10.4 Hardware
- https://learn.microsoft.com/en-us/surface/tech-specs/surface-laptop-snapdragon-tech-specs (2025-09-29)
- https://www.ifixit.com/Guide/Microsoft+Surface+Laptop+7+(13.8-inch)+Chip+ID/173921 (2024-06-22)
- https://www.notebookcheck.net/Microsoft-Surface-Laptop-7-13-8-Copilot-review-Thanks-to-Snapdragon-X-Elite-finally-a-serious-MacBook-Air-competitor.857051.0.html (2024-07-04)
- https://www.notebookcheck.net/Microsoft-Surface-Laptop-7-15-Snapdragon-laptop-review-Finally-easier-to-repair.956423.0.html (2025-02-14)
- https://en.wikipedia.org/wiki/Surface_Laptop_(7th_generation)
- https://raw.githubusercontent.com/torvalds/linux/master/arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus.dtsi (2026-09-13)
- https://raw.githubusercontent.com/torvalds/linux/master/arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dts (2026-09-13)
- https://raw.githubusercontent.com/torvalds/linux/master/arch/arm64/boot/dts/qcom/x1p42100-hp-omnibook-x14.dts (2026-09-13)

### 10.5 Kernel / Upstream
- https://api.github.com/repos/torvalds/linux/commits?path=arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus.dtsi (2026-09-13; auch mit sha=v7.2 / v7.3-rc1)
- https://api.github.com/repos/torvalds/linux/commits?path=arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus13.dts (2026-09-13)
- https://api.github.com/repos/torvalds/linux/contents/drivers/hid?ref=master (2026-09-13)
- https://api.github.com/repos/torvalds/linux/commits?path=drivers/media/i2c/ov02c10.c (2026-09-13)
- https://api.github.com/repos/torvalds/linux/commits?path=drivers/power/supply/qcom_battmgr.c (2026-09-13)
- https://api.github.com/repos/torvalds/linux/commits?path=drivers/usb/dwc3/core.c (2026-09-13)
- https://www.kernel.org/ (2026-09-13: 7.3-rc2, 7.2.5, 6.18.51)
- https://lkml.iu.edu/hypermail/linux/kernel/2408.1/01432.html (Romulus-DTS-Patch 4/4, 2024-08)
- https://ratatoskr.run/lkml/2026/09/17522699 (Touchscreen-Serie fQwQf 0/2, 2026-09-07)
- https://ratatoskr.run/linux-input/2026/09/17522701/t (PATCH 2/2 romulus13 touchscreen, 2026-09-07)
- https://ratatoskr.run/linux-arm-msm/2026/06/17091838/t (GENI-QSPI-Thread, 2026-06-05..07-01)
- https://ratatoskr.run/linux-devicetree/2026/08/17453945/t (spi: qcom-geni: Use GPIO to notify, 2026-08)
- https://ratatoskr.run/linux-arm-msm/2026/07/17303145/t (spi: qcom-qspi: Correct max DMA, 2026-07)
- https://ratatoskr.run/linux-devicetree/2026/04/3505676/t (OV02C10 Romulus DT, 2026-04-09)
- https://ratatoskr.run/linux-media/2026/06/17114244/t (HM1092 IR-Kamera, 2026-06-10)
- https://ratatoskr.run/linux-devicetree/2026/03/3436977/t (spi-hid v1, 2026-03-03)
- https://lkml.iu.edu/2603.3/00203.html (spi-hid v2 00/11, 2026-03)
- https://ratatoskr.run/linux-devicetree/2026/04/3494714/t (spi-hid v3, 2026-04-02)
- https://ratatoskr.run/lkml/2026/06/17106641/t (spi-hid v4, 2026-06-09, unverifiziert)
- https://github.com/linux-surface/spi-hid (Out-of-tree)
- https://ratatoskr.run/linux-arm-kernel/2026/09/17521126/t (cpufreq > 4.19 GHz, 2026-09-06)
- https://lore.kernel.org/linux-kernel/20240612124056.39230-1-quic_sibis@quicinc.com/T/ (x1e80100 CPUFreq V6, 2024-06-12)
- https://www.phoronix.com/news/ARM-SCMI-CPUFreq-Boost-Linux-69 (2024-03)
- https://patchew.org/linux/20250207-qcom-video-iris-v10-0-ab66eeffbd20@quicinc.com/ (Iris v10, 2025-02-07)
- https://cateee.net/lkddb/web-lkddb/VIDEO_QCOM_IRIS.html
- https://api.github.com/repos/jhovold/linux (pushed 2025-09-19)
- https://api.github.com/repos/ProgrammerIn-wonderland/ELLX-Kernel (pushed 2026-05-14; Tag 7.0.0-rc4-12)
- https://github.com/ProgrammerIn-wonderland/ELLX-Kernel/commits/7.0-sl7 (neuester Commit 2026-04-10)
- https://raw.githubusercontent.com/wiki/linux-surface/linux-surface/Supported-Devices-and-Features.md (2026-09-13)
- https://raw.githubusercontent.com/dwhinham/linux-surface-pro-11/main/README.md (~2025-10)
- https://github.com/jglathe/linux_ms_dev_kit/wiki/Enabling-sound-on-the-HP-Omnibook-X14,-Lenovo-Thinkbook-16

### 10.6 Community SL7 (GitHub)
- https://github.com/linux-surface/linux-surface/issues/1590 (2025-03-20 bis 2026-09-12; lokale Kopie der 2026-Kommentare in `docs/quellen/ls1590-comments-2026.json`)
- Kommentare daraus: bryce-hoehn 2025-03-20 (GPU/WLAN), tj90241 2025-04-26/-04-27 (QSPI „dead end"), 2025-05-03/-05-05 (Audio, UCM-Rezept), orvitpng 2026-06 und 2026-09-02, ameenjuz 2026-06-10 (Ton fällt bei 100 % aus), valpackett 2026-06-10 (keine Speaker-Protection) und 2026-08-19 (stubble `dtb_override`), ProgrammerIn-wonderland 2026-06-30 („ruined my speakers") und 2026-08-23 (ELLX ohne stubble, Power-Taste weckt), **perchbirdd 2026-05-14 (offizielles Resolute-arm64-Image funktioniert „mostly", Concept-Image in Boot-Schleife)**, **vladimir-alekseev 2026-05-20 (Neuinstallation mit dem Vanilla-arm64-Desktop-ISO)**, **Notliam99 2026-05-20 („invalid magic number" → 09:27 UTC „omg it was a corupted file", 11:38 UTC „fully setup" mit Ventoy)**, OliW07 („Ventoy fixed most of my problems"), horizontblau 2026-08-17..09-11 (Touchscreen spi10, Touchpad-Wedge, iptsd-SIGILL), dwhinham u. a. 2026-09-02 (spi-hid v4 + Touchscreen, Upstream-Absicht)
- https://github.com/giantdwarf17/linux-surface-laptop-7 → https://github.com/bryce-hoehn/linux-surface-laptop-7 (README 2026-08-06, Push 2026-08-06)
- https://github.com/bryce-hoehn/linux-surface-laptop-7/pull/9 (Zap-Pfad, 2025-05-23)
- https://github.com/bryce-hoehn/linux-surface-laptop-7/issues/21#issuecomment-5202068047 (hybris 2026-08-06; UEFI-MAC-Variable)
- https://api.github.com/repos/giantdwarf17/linux-surface-laptop-7/issues?state=all&per_page=100 (bis 2026-08-06) sowie die Kommentare zu #2 (Audio, geschlossen 2026-03-14), #4 (Kamera, 2026-04-09), #6 (Bluetooth, 2026-06-10), #7 (Power, 2026-05-18)
- https://github.com/giantdwarf17/linux-surface-laptop-7/issues/8 (RTC, 2025-04-08), /issues/11 (USB-C-Display, 2025-06-13), /issues/13 (Touchscreen, 2026-03-14), /issues/23 (iptsd ohne Service/udev, 2026-07-30)
- https://github.com/valeronm/sl7-mac (Push 2026-07-21/22)
- https://api.github.com/repos/alex-lentz/iptsd (Push 2026-07-17)
- https://horizontblau.de/linux/surface-laptop-7-linux.html (Writeup 08/2026, umstritten)
- https://raw.githubusercontent.com/alsa-project/alsa-ucm-conf/master/ucm2/Qualcomm/x1e80100/x1e80100.conf (2026-09-13)
- https://github.com/alsa-project/alsa-ucm-conf/tree/master/ucm2/Qualcomm/x1e80100

### 10.7 Optimierung / Userspace
- https://packages.ubuntu.com/resolute/mesa-vulkan-drivers (26.0.3-1ubuntu1, 2026-09-13)
- https://ubuntuhandbook.org/index.php/2026/09/mesa-26-2-install-ppa-ubuntu/ (2026-09-07)
- https://docs.mesa3d.org/drivers/freedreno.html
- https://www.phoronix.com/news/Mesa-24.3-Freedreno-A7xx (2024)
- https://www.omgubuntu.co.uk/2026/03/gnome-50-released (2026-03-19), https://release.gnome.org/50/
- https://alternativeto.net/news/2025/2/kde-plasma-6-3-improves-fractional-scaling-system-monitoring-panel-cloning-and-much-more/ (2025-02)
- https://asahilinux.org/docs/sw/broken-software/ (2026-09-13)
- https://github.com/FEX-Emu/FEX/releases (FEX-2609, 2026-09-08), https://launchpad.net/~fex-emu/+archive/ubuntu/fex
- https://discourse.ubuntu.com/t/tutorial-running-steam-games-on-arm64-with-fex/70215 (2025-10-20)
- https://www.omgubuntu.co.uk/2026/01/steam-snap-arm64-ubuntu-gaming-performance (2026-01)
- https://www.omgubuntu.co.uk/2026/07/chrome-arm64-linux-available (2026-07/08)
- https://github.com/AsahiLinux/widevine-installer
- https://linrunner.de/tlp/faq/ppd.html

### 10.8 Nicht abrufbar (für spätere Recherche)
- git.kernel.org cgit (HTTP 403), lore.kernel.org (Anubis „Access Denied"), git.launchpad.net cgit (403), gitlab.com-HTML (JS-only) → Ersatz: GitLab-/codelinaro-REST-API, GitHub-API auf torvalds/linux, lkml.iu.edu- und ratatoskr.run-Spiegel, code.launchpad.net-`+ref/`-Seiten.

---

*Endfassung, Stand 13.09.2026. Ergebnisse vom ersten Boot auf dem Gerät (Cmdline-Varianten, Touchscreen-Variante, Audio-Prüfbefehle, iris, Thermal, Akku-Drain) bitte hier nachtragen – betroffen sind die Abschnitte 3.3, 5.3 D, 6.0, 6.5, 6.9, 6.15, 7.5 und 9.*
