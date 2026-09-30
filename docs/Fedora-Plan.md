# Fedora-Plan – Fedora KDE Live (aarch64) für den Surface Laptop 7 13,8" (X1E80100, Romulus13)

Stand: 22.09.2026, abends. Grundlagen in dieser Reihenfolge (bei Widerspruch gilt die frühere):

1. `build/workflow/local-facts.md` (lokal verifiziert 12./13.09.2026, inkl. Nachrecherche),
2. Zustandsprüfung der WSL-Bauumgebung in dieser Sitzung (22.09., Abschnitt 0.2),
3. Recherche-Korpus vom 22.09.2026 (6 Themen, je 20 Web-Abrufe; `build/workflow/fedora-recherche-ergebnisse.json`).

Konvention: **(unverifiziert)** = nur eine Quelle, nicht selbst geprüft oder von einer anderen Quelle widersprochen. Wo eine Behauptung aus einer Vorsession durch die Recherche relativiert wird, steht das ausdrücklich dabei (Abschnitt 1.6).

Dieses Dokument ist der *Plan* (Entscheidungen, Begründungen, Risiken). Die Bedienungsanleitung des ISO steht in `docs/Fedora-ISO-Anleitung.md`, die ausführbaren Skripte in `build/fedora/`.

---

## 0 Kurzfassung

### 0.1 Entscheidungen auf einen Blick

| Frage | Entscheidung | Kurzbegründung |
|---|---|---|
| Basis-Image | Fedora-KDE-Desktop-Live-44-1.7.aarch64.iso (kiwi, EROFS-Rootfs, Kernel 6.19.10-300.fc44 als `kernel-uki-dtbloader`), Rootfs per `dnf upgrade --exclude=kernel*` auf Stand 22.09. | Einziges offizielles Live-Medium, das den Romulus13-DTB bereits selbst auswählt (.hwids/.dtbauto lokal verifiziert); Anaconda-Live-Installation übernimmt Kernel + Konfiguration ohne Nacharbeit. |
| Kernel-Basis | **Zwei Kernel im ISO.** Kernel B `7.3.0-rc3-sl7b` = Ubuntu 26.10 `linux-source 7.3.0-5.5` + ItsLucas-Patches r15.1 (Standard). Kernel A `7.0.0-rc4-sl7` = ELLX 7.0.0-rc4-12 + konservativer Patch-Satz (Rückfall). Dazu Fedoras Stock-Kernel 6.19.10 als dritter Rückfall. | B ist der aktuellste vollständige SL7-Patch-Stack auf einem neuen Kernel (Speaker-Limit, GENI-Callbacks, QRTR-Revert); A ist der Tree, mit dem die Community den SL7 seit Mai betreibt. Kein Fedora-SRPM-Rebuild (Bauzeit unter qemu-user unbelegt, Patch-Stack müsste auf kernel-ark portiert werden). |
| Paketierung | `make binrpm-pkg` (Cross, `--target aarch64-linux`) → RPM `kernel-<ver>` mit `/lib/modules/<ver>/{vmlinuz,dtb}`; im Rootfs mit `--noscripts` installiert, kernel-install/dracut laufen kontrolliert in Phase 2. | Gleiches Dateilayout wie Fedoras kernel-core; kernel-install (20-grub.install) erzeugt BLS-Einträge ohne Anpassung. |
| DTB-Bereitstellung | Wie Fedora 44: pro Kernel ein `vmlinuz-dtbloader.efi` (stubble-Stub + `.dtbauto` romulus13 + romulus15 + `.hwids`), **ohne** `.cmdline`, `.initrd` und **ohne `.osrel`**. GRUB liefert Cmdline und initrd. DTB-Varianten (I²C-Touchscreen, exp) nur über GRUB-`devicetree`-Einträge mit dem Plain-Kernel. | Bootet ohne `devicetree`-Zeile, funktioniert später auch unter Secure-Boot-Lockdown; kernel-install behandelt das Image als normalen Kernel (BLS Typ 1 + initramfs). **Achtung:** die am 22.09. gebauten Images enthalten fälschlich eine `.osrel`-Sektion (0.2, 2.7) – muss vor Phase 3 korrigiert werden. |
| Trackpad | Fork **alex-lentz/iptsd @3663e96** (Kraft-Klick Frame 0x94 → BTN_LEFT, Entprellung, Sleep-Hook) als Fedora-RPM im aarch64-Chroot mit Fedoras Toolchain gebaut (BTI/PAC/GCS durchgängig, kein SIGILL). | Einziger öffentlicher Fork mit funktionierendem Kraft-Klick; ELLX-Prebuilt hat BTI-Mischung; orvitpngs „sauberer" Fork ist nicht öffentlich. |
| Boot-Loop-Absicherung | GRUB-Menü mit Kernel B/A/Fedora-Stock, jeweils USB-C-sicher (`modprobe.blacklist=qcom_q6v5_pas`) und mit ADSP; Diagnose-Einträge ohne Splash; Alternativen `arm64.nopauth`, ohne `clk/pd_ignore_unused`, `cutmem`, `nomodeset`; Standard-DTB ohne experimentelle Knoten. | Die wahrscheinlichsten Ursachen des Ubuntu-Loops (experimenteller DTB, Cmdline-Widerspruch, ADSP/USB-C, initramfs) werden je durch einen eigenen Menüpunkt umgangen. |
| Secure Boot | Am Gerät **aus** (None). Signieren/MOK erst, wenn das Image läuft. | Unsignierte Kernel → shim „bad shim signature"; GRUB-`devicetree` unter Lockdown gesperrt. |

### 0.2 Ist-Stand der Bauumgebung (in dieser Sitzung geprüft, WSL `/work/sl7/fedora`)

| Schritt | Zustand 22.09. abends | Beleg |
|---|---|---|
| Werkzeuge (`wsl-setup-fedora-tools.sh`) | vollständig: ukify 259.5, mksquashfs, xorriso 1.5.6, qemu-system-aarch64, AAVMF/QEMU_EFI, setfiles, grub-script-check, lsinitrd, rpmbuild, dnf | `command -v`, `ls /usr/share/AAVMF` |
| Original-ISO + Rootfs-Kopie | vorhanden (`iso/Fedora-KDE-Desktop-Live-44-1.7.aarch64.iso`, 3.119.904.768 B; `rootfs/` mit SELinux-xattrs) | Listing |
| Kernel A RPM | `kernel-7.0.0_rc4_sl7-7.aarch64.rpm` (14:09) + headers; DTBs standard/exp/i2cts; `build/fedora/out/7.0.0-rc4-sl7-1/` | Listing, SHA256SUMS |
| Kernel B RPM | `kernel-7.3.0_rc3_sl7b-2.aarch64.rpm` (19:18) + headers; DTBs standard/i2cts; `build/fedora/out/7.3.0-rc3-sl7b-1/` | Listing, SHA256SUMS |
| Phase 1 (`dnf upgrade`, iptsd-RPM) | **fertig 19:29** („Complete!"); `iptsd-3-0.sl7.git3663e96.fc44.aarch64` installiert; `readelf -n`: „AArch64 feature: BTI, PAC, GCS"; `iptsd@.service`, `50-iptsd.rules`, `system-sleep/iptsd`, `/etc/iptsd.d/{90-sl7-touchpad,91-calibration-045E-0C77}.conf` vorhanden. Rootfs jetzt: systemd 259.9, grub2-efi-aa64 2.12-64, dracut 108-8, anaconda-core 44.30-2. | `phase1.log`, `rpm --root … -q` |
| Phase 2 | **abgebrochen in Schritt 8** (Live-initrd Kernel A; `phase2.log` endet bei „Including module: fips-crypto-policies", kein `/boot/initramfs-7.*.img`). Schritte 1–7 sind durch: beide Kernel-RPMs installiert (`rpm -qa` zeigt zweimal `kernel`), DTB-Varianten kopiert, dtbloader-Images gebaut, Firmware (`/usr/lib/firmware/updates/qcom/x1e80100/microsoft/…`), sl7-mac, Sleep-Hooks, `90-sl7.conf` (dracut), `90-sl7.conf` (anaconda), `sl7-postinstall.service`, `/etc/sl7-release`, `SL7-Hinweise.txt`. Schritte 9–10 (Aufräumen, SELinux-Relabel) nicht gelaufen. | `phase2.log`, Listings |
| **Fehler in Phase 2 Schritt 3** | Die dtbloader-Images enthalten eine **`.osrel`-Sektion** (ukify 259 bettet ohne `--os-release=""` das `/etc/os-release` des *Ubuntu-Hosts* ein; Quelltext `/usr/bin/ukify` Zeilen 2418–2427). Fedoras eigenes Image hat keine `.osrel`. Mit `.linux` + `.osrel` stuft kernel-install das Image als **UKI** ein → Layout `uki`, 90-uki-copy statt 20-grub, kein initramfs, kein BLS-Typ-1-Eintrag → das installierte System würde mit unseren Kerneln nicht booten. **Korrektur: `--os-release=""` (kernel-ark-Muster) und Kontrolle „0 × .osrel".** | `objdump -h` auf `/boot/vmlinuz-7.*` im Rootfs: `2 .dtbauto, 1 .osrel, 1 .hwids, 1 .uname …`; Fedora-Image: `21 .dtbauto, 0 .osrel` |
| Phase 3 (ISO) / Phase 4 (QEMU) | nicht gelaufen; `/work/sl7/fedora/out` existiert nicht | Listing |
| Stick-Skript `Fedora-Stick-schreiben.ps1` | in der Anleitung genannt, **existiert nicht** in `build/fedora/` | Listing |
| Kernel-B-Tree | HEAD = `a9d68428a romulus13-i2cts DTB-Variante`, ein Commit **nach** Tag `sl7b`; `wsl-build-kernel-73-fedora.sh` verlangt HEAD == `sl7b` (beim nächsten Rebuild `git tag -f sl7b` oder Prüfung lockern). Speaker-Limit in Ubuntu 7.3 vorhanden (10 Treffer `snd_soc_limit_volume`). | `git describe`, grep |
| Kernel-A-Tree | Zweig `sl7-fedora`; konservative Patches liegen **uncommitted** im Arbeitsbaum (dwc3 core.c/h + Binding, romulus.dtsi, x1e80100.c: 5 Dateien, +67/−8), `romulus13-exp.dts` untracked, `romulus13-i2cts` committed. | `git status` |

Nächster Schritt ist also: Phase 2 ab Schritt 3 mit korrigiertem ukify-Aufruf neu laufen lassen (im Hintergrund, mit `nohup`/Log – der Abbruch kam vermutlich durch das 2-Minuten-Timeout eines Vordergrund-Aufrufs), dann Phase 3 und 4 (Abschnitt 6).

---

## 1 Stand der Community und was sich seit August geändert hat

### 1.1 Zeitleiste 06.08.–22.09.2026

| Datum | Ereignis | Bedeutung für uns |
|---|---|---|
| 06.08. | bryce-hoehn/linux-surface-laptop-7: PR #22 („updated description + mac address patch") gemerged. Danach **keine** Aktivität mehr (kein Issue/PR, kein Fork-Push). Maintainer hat sein SL7 verkauft (Issue #12). Offen: #23 iptsd/Two-Finger-Scroll (30.07.), #21 Fabrik-MAC aus UEFI, #13 Touchscreen, #11 USB-C-Display, #1 WLAN. | Repo ist eingefroren; nur noch als Patch-Archiv relevant. |
| 17.08. | horizontblau (#1590): „Bootloader DTB patches do nothing on this machine" (stubble überschreibt den DTB), Touchscreen zunächst per Runtime-Overlay. | Bestätigt: DT-Änderungen gehören in den Kernel bzw. in die `.dtbauto`-Sektionen, nicht in eine GRUB-`devicetree`-Zeile – außer man setzt `stubble.dtb_override=false` oder nutzt den Plain-Kernel. |
| 19.08. | valpackett (#1590): `stubble.dtb_override=false` schaltet das Überschreiben ab. | Unsere Varianten-Einträge nutzen deshalb den Plain-Kernel (`vmlinuz-sl7a/b`) + `devicetree`. |
| 23.08. | horizontblau: „volle SL7-Funktionalität"; ELLX-iptsd stürzt mit SIGILL (Branch-Protection-Mischung), Abhilfe `objcopy --remove-section=.note.gnu.property` oder sauberer Neubau; „selective device hiding" per udev nötig; warmer Reboot lässt Touchpad/Touchscreen hängen („warm reboot leaves them wedged"), nur Power-off hilft; Suspend/Resume ok, Aufwecken per Power-Taste. Doku: horizontblau.de/linux/surface-laptop-7-linux.html (Kopie in `docs/quellen/horizontblau-sl7.txt`). | Grundlage für iptsd-Bau (Abschnitt 5) und für die Regel „nach Fehlversuch kalt ausschalten". |
| 25.08. | horizontblau: Touchscreen „from a statically patched device tree" (HID-over-SPI, GTCH an QUP1 SE2). | Deckt sich mit ItsLucas 0003 (SPI/GTCH) – zwei unabhängige Quellen für SPI, eine (widersprochene) für I²C. |
| 29.08. | horizontblau: `spi-hid` registriert weder `.shutdown` noch `.pm`; Controller verliert beim Poweroff die 5-V-Schiene mitten im Betrieb. | ItsLucas 0004 („spi-hid power-lifecycle") adressiert genau das; in Kernel B enthalten. |
| 02.09. | orvitpng (#1590): verweist nur auf nix1e, erwähnt verlorene Kalibrier-Fixes zum Touchpad-Wake; ein öffentlicher iptsd-Fork von ihm ist **nicht** auffindbar (nix1e enthält keinen iptsd-Code). | alex-lentz-Fork bleibt die einzige Option. |
| 07.09. | LKML/linux-input, fQwQf: „[PATCH 0/2] arm64: dts: qcom: enable touchscreen on Surface Laptop 7 (13.8")" – `hid-over-i2c` an i2c8 @0x34, `hid-descr-addr 0x0000`, IRQ tlmm 38 level-low, Reset tlmm 31. Krzysztof Kozlowski verlangt Entfernen des Tested-by; danach keine Antwort (dormant). | Unsere `-i2cts`-DTB-Varianten; **(unverifiziert, widersprochen)** durch ItsLucas („Replaces unsuccessful I2C touchscreen experiment"). |
| 09.09. | Ubuntu-Concept-PPA: linux-qcom-x1e 7.2.0-18.18 (resolute); 17.09.: 7.3.0-15.15 (stonking). Ubuntu-Discourse #48800 Post #2174 (glathe) verweist auf ein Wiki „Installing with the new-ish Resolute (26.04) Ubuntu extended image" (nicht abgerufen). | Alternative Basis für einen späteren Rebase; für jetzt nicht nötig. |
| 09.09. | cicorias-Gist „Omarchy surface laptop 7 aarch64" (Arch ARM 7.2.3, romulus15): Cmdline `initramfs_async=0 clk_ignore_unused pd_ignore_unused arm64.nopauth systemd.tpm2_wait=0 modprobe.blacklist=qcom_q6v5_pas console=tty0 loglevel=7 plymouth.enable=0`; „gpu hw init failed: -2" = Zap-Shader fehlt („single most likely first-boot failure"). | Diagnose-Cmdline übernommen; Zap-Firmware in jeder initramfs. |
| 12./13.09. | #1590: itpropro fordert Bann von horizontblau („AI slop"), ProgrammerIn-wonderland relativiert – kein technischer Inhalt. 21.09.: OptimisticPeach, Einsteigerfrage. | Der Thread liefert derzeit nichts Neues. |
| 15.–19.09. | **ItsLucas/surface-laptop-7-ubuntu-kernel**: tägliche arm64-Builds von Ubuntu 26.10 „stonking" generic 7.3.0-5.5 mit Patches 0001 ath12k-rfkill (bryce-hoehn), 0002 QSPI/GPI + spi-hid (aus ELLX 0e9944fa4c, Variante 7.3 auf v7.3-rc3 rebased, „upstream GENI resource callbacks"), 0003 GTCH-SPI-Touchscreen („derived from this model's Windows ACPI", Regulator an gpio64 mit 500 ms Anlaufzeit), 0004/0005 (15.09.) spi-hid-Power-Lifecycle, GPIO-Ownership, DRM-Panel-Follower, 0006 Revert von Upstream 544d85de4dc2 (QRTR HELLO; sonst WLAN nach Firmware-Restart/Resume tot). Releases r15.1 (19.09.), r14.1, r8.1, 7.2-r5.1 (18.09.); alle „Signed build candidate; **not hardware-validated**"; 0 Stars, 17 Commits, APT-Archiv mirrors.5cena.cc/sl7. | **Basis von Kernel B.** Kopie unter `gits/ItsLucas_surface-laptop-7-ubuntu-kernel/`. Die Binär-Releases sind laut Autor nicht hardwaregetestet – die Patches selbst stammen aus Arbeit am Gerät (0006 „getestet auf 7.3.0-5.5"), aber Einzelperson **(unverifiziert)**. |
| 16.09. | denislopt/omarchy-surface-laptop7: „Community Test ISO 2026.09.16" (Arch/Omarchy, romulus15, Kernel 7.2.5-1-aarch64-ARCH). Nicht abgerufen **(unverifiziert)**. | Nur Referenz für ISO-Bau, andere Distribution und 15-Zoll. |
| 18.09. | murkurie/ELLX-Kernel Release „Surface Laptop 7 Kernel v7.2.0-sl7-13.8" (Linux 7.2 rebased auf linux-qcom-x1e; Touchpad HIDSPI v3, Webcam, Retimer-PM, Wi-Fi-7-Enumeration, EC; Downloads public.hgci.org/software/ELLX/kernels/). **(unverifiziert)** – anderes Repo als ProgrammerIn-wonderland/ELLX-Kernel (dessen HEAD unverändert 0e9944fa4c vom 14.05.); das public.hgci.org-Listing zeigt auf Top-Level keine Änderung seit Juni. | Kandidat für einen späteren Vergleich (Abschnitt 4.1 F). Nicht Basis. |
| — | Upstream: spi-hid-Serie steht bei v4 (09.06.), kein v5; GENI-QSPI: Qualcomm (Mukesh Savaliya, 01.07.) „we are working on this driver to upstream", keine Serie; Asahi trägt spi-hid als `bits/090-spi-hid`. | Touchpad bleibt auf Out-of-tree-Code angewiesen; Fedora-Stock-Kernel hat kein Trackpad. |
| — | Xelef2000/azurefin: bootc/rpm-ostree-Image auf Fedora-Silverblue-Basis für den SL7 (Kernel, Firmware, Touchscreen-Treiber, Power-Management) – nur Suchtreffer **(unverifiziert)**. | Als Nächstes lesen: könnte die direkteste Fedora-Vorlage sein (Abschnitt 7). |

### 1.2 Kernel-Quellen im Vergleich

| Tree | Basis | SL7-Teile | Stand | Bewertung |
|---|---|---|---|---|
| ProgrammerIn-wonderland/ELLX-Kernel Tag 7.0.0-rc4-12 | Ubuntu-Concept qcom-x1e-7.0 (7.0.0-rc4) | spi-hid (Luz 2022), spi-geni QSPI-Hack, gpi.c, ath12k-rfkill-Hack, OV02C10-Kamera, ps883x | 14.05.2026 | **Kernel A.** Bewährt (Community seit Mai), aber alter rc-Kernel; Speaker-Limit, hamoa-PHY-Fix, dwc3-Resume nur durch unsere Patches. |
| ItsLucas (Ubuntu 26.10 linux-source 7.3.0-5.5 + 0001–0006) | Ubuntu generic 7.3 (v7.3-rc3) | wie ELLX (QSPI/spi-hid rebased) + GTCH-SPI-Touchscreen + Power-Lifecycle + Panel-Follower + QRTR-Revert | 19.09.2026 | **Kernel B.** Neuester Stack; Speaker-Limit bereits im Ubuntu-Tree; Binaries nicht hardwaregetestet. |
| Ubuntu-Concept-PPA linux-qcom-x1e 7.2.0-18.18 / 7.3.0-15.15 | Concept | keine SL7-Out-of-tree-Teile | 09./17.09.2026 | Rebase-Ziel für später; ohne spi-hid/QSPI kein Trackpad. |
| Fedora kernel-core/kernel-uki-dtbloader 7.2.6-200.fc44 (updates), 7.2.7 (testing), 6.19.10 (Live-ISO) | Fedora | keine; romulus13-DTB und HWIDs enthalten | 22.09.2026 | Rückfall-Kernel im ISO (Stock 6.19.10). Kein Trackpad-Klick, kein spi-hid. |
| murkurie/ELLX-Kernel v7.2.0-sl7-13.8 | „Ubuntu Concept kernel for QCOM-X1 + scuggo's SL7 changes" | HIDSPI v3, Webcam, Retimer-PM | 18.09.2026 **(unverifiziert)** | Prüfen, nicht Basis. |
| scuggo/x1e-nixos, orvitpng/nix1e | mainline 7.1.2 / 7.x | DT-Overlays, QSPI-Patches, cpu-parking, ec-reboot, fullduplex spi-hid | Juni/Juli 2026 | Patch-Quellen (thermal, touchpad), Kopien unter `docs/quellen/`. |

### 1.3 Fedora-Seite

- Fedora-Wiki „Snapdragon WoA Laptop Install" (Rev. 775997, 2026): Ziel Fedora Workstation 44; gelistet nur ThinkPad X13s, T14s Gen6, Yoga Slim 7x – **kein Surface Laptop 7**. Cmdline X1E/X1P: `clk_ignore_unused pd_ignore_unused systemd.tpm2_wait=0 modprobe.blacklist=qcom_q6v5_pas` (Blacklist entbehrlich bei Boot von USB-A); `efi=noruntime arm64.nopauth` nur für 8cx Gen 3. Post-Install: `anaconda-denylist.conf` löschen, `scmi-cpufreq` in modules-load.d, `grubby --update-kernel=ALL --args="systemd.tpm2_wait=0"`, dracut `install_items+=` für `/lib/firmware/updates/qcom/x1*/*/*/*.mbn*` und `*.elf*`, `qcom-firmware-extract` (updates-testing; Paketseite 404 **(unverifiziert)**). „pd_ignore_unused should become unnecessary with kernel 7.1" und „With Fedora 45 this should no longer be necessary" (Suchsnippet, Kontext unklar **(unverifiziert)**).
- Fedora-44-Change „Automatic DTB selection for aarch64 EFI systems" (de Goede/Gompa, zuletzt 14.04.2026): Live-ISOs nutzen `kernel-uki-dtbloader` (im Change-Text noch „kernel-dtb-loader" genannt); installierte *Bestands*-Systeme behalten kernel-core mit manuellem `GRUB_DEVICETREE`. Fedora-grub2 fedora-44: „Treat kernel-uki-dtbloader as default kernel" (Bug 2463620) – Neuinstallationen vom Live-Medium bleiben beim dtbloader-Paket. kernel-ark MR #4318: langfristig soll kernel-core selbst das Stub-Image werden (evtl. Fedora 45).
- Kernelstand (packages.fedoraproject.org, 22.09.): F44 updates 7.2.6-200.fc44, updates-testing 7.2.7; F45 (gebranched, Termin nicht verifiziert) 7.2.6-300/7.2.7; Rawhide 7.3.0-0.rc4. Fedora 44 GA 28.04.2026; das KDE-Live-44-1.7 enthält 6.19.10-300.fc44 (lokal), Presseberichte nennen 6.19.14 als GA-Kernel **(abweichend, unverifiziert)**.
- SL7-Berichte: Fedora Discussion 144552 (Feb.–Apr. 2025, F41 Live): „hangs in a boot loop until I restart it and remove the USB" – keine erfolgreiche Installation dokumentiert. Thread 188069 „Live media fail to boot on Snapdragon aarch64 laptops" (2026) **nicht gelesen**. Thread 195494 (02.07.2026, Surface Pro 12", F44 über Ventoy): „invalid magic number" – laut Korpus Ventoys eigener GRUB im grub2-Modus (medium) **(unverifiziert)**; local-facts zeigen für Ubuntu, dass Ventoy im Normalmodus den ISO-eigenen GRUB lädt. Für Fedora bleibt Ventoy ungetestet → Stick roh schreiben (6.7).
- Community-Kanäle: kein Fedora-SIG; Matrix `#arm:fedoraproject.org`, `#_oftc_#aarch64-laptops:matrix.org`. Copr radical1/snapdragon-x-elite ist veraltet (Kernel 6.15-rc2 vom Feb. 2025) – nicht verwenden.

### 1.4 Firmware in Fedora

- `qcom-firmware-20260309-1.fc44` liefert `qcom/x1e80100/{adsp,adsp_dtb,cdsp,cdsp_dtb,gen70500_zap}.mbn.xz` und Vendor-Ordner LENOVO/ASUSTeK/dell/hp – **kein microsoft/**. Update 20260519: ADSP/CDSP-Updates für x1e80100 (medium).
- `atheros-firmware` (F44 20260309, Rawhide 20260916): `ath12k/WCN7850/hw2.0/{amss,board-2,m3}.bin.xz`; der SL7-Eintrag (Subsystem-ID 1107) fehlt in board-2.bin (local-facts) → unsere gepatchte Datei unter `/usr/lib/firmware/updates/…` (der Loader sucht `updates/` zuerst; Fedora-Blobs sind xz, unkomprimierte Ersatzdateien reichen – CONFIG_FW_LOADER_COMPRESS_XZ/ZSTD in beiden Kerneln gesetzt, Suchreihenfolge `updates/` vor `firmware/` ist Kernel-Standard).
- Unser Paket `sl7-firmware-msi-26100_26.053.36539.0.tar.xz` (MS-MSI 26.053, 25.06.2026) ist bereits im Rootfs entpackt (Phase 2 Schritt 4).

### 1.5 Was sich für den Plan seit dem Dossier (13.09.) geändert hat

1. Neue Kernel-Basis verfügbar (ItsLucas 7.3) → Zwei-Kernel-Strategie statt nur ELLX.
2. Der Touchscreen hat jetzt zwei sich widersprechende „verifizierte" Beschreibungen (SPI/GTCH vs. I²C) → beide als Auswahl, SPI ist die besser belegte.
3. Fedora 44 wählt den Romulus13-DTB selbst (lokal verifiziert) → Fedora-Stock-Kernel ist ein echter Rückfall- und Referenzeintrag.
4. iptsd-SIGILL-Ursache ist bekannt (BTI-Mischung) → eigener Bau statt ELLX-Deb.
5. Boot-Loop des Ubuntu-Versuchs ohne Logs → das ISO bekommt Diagnose-Einträge und Alternativen (Abschnitt 3).

### 1.6 Korrekturen zu Formulierungen der Vorsession

- `build/fedora/SL7-Hinweise.txt` und `/etc/sl7-release` sagen zu Kernel B „auf echtem Romulus13 getestet". Belegt ist nur: die Patches stammen aus Arbeit am Gerät (0003 aus dem Windows-ACPI, 0006 „getestet auf 7.3.0-5.5"); die **Releases** sind ausdrücklich „not hardware-validated". Text vor Phase 3 auf „Patches vom Gerät abgeleitet, Builds nicht hardwaregetestet" ändern.
- Korpus (Boot-Loop-Thema): „der SL7 hat nur USB-C!" ist falsch – der Surface Laptop 7 hat 2× USB-C (USB4) und 1× USB-A. Die Fedora-Wiki-Empfehlung „von USB-A booten, dann ist die ADSP-Blacklist entbehrlich" ist für uns direkt nutzbar (am Gerät bestätigen).
- Korpus (Trackpad-Thema) fand die Datei `91-calibration-045E-0C77.conf` „nirgends belegt" – sie liegt lokal vor (`build/out/ellx-iptsd/`, aus dem ELLX-Paket; 15-Zoll-Startwert) und ist im Rootfs installiert. Für das 13,8"-Gerät neu kalibrieren (5.4).

---

## 2 Wie Fedora auf dem X1E bootet – und was das für unser ISO bedeutet

### 2.1 Boot-Kette des Stock-ISO (lokal am ISO verifiziert)

1. UEFI lädt `EFI/BOOT/BOOTAA64.EFI` = shim 16.1 (prüft Signatur gegen Fedora-CA bzw. MokList).
2. shim startet `EFI/BOOT/grubaa64.efi` (grub2 2.12-56.fc44 auf dem ISO; im Rootfs inzwischen 2.12-64 – für den Live-Boot zählt das ISO-GRUB, das ist unverändert und bootet Fedoras Stub-Image nachweislich).
3. `EFI/BOOT/grub.cfg` (111 B): `search --file --set=root /boot/0x3d6eb6b1`, `configfile /boot/grub2/grub.cfg`. Das ISO ist kiwi-gebaut: **kein** `images/`, kein `efiboot.img`; Kernel und initrd liegen unter `/boot/aarch64/loader/{linux,initrd}`; `/LiveOS/squashfs.img` ist in Wahrheit **EROFS** (lzma) mit dem Rootfs direkt darin (kein `rootfs.img`).
4. `linux /boot/aarch64/loader/linux quiet rhgb root=live:CDLABEL=Fedora-KDE-Live-44 rd.live.image` – die Datei ist `vmlinuz-dtbloader.efi`: systemd-stub 259 + 21/22 `.dtbauto` + `.hwids` + `.uname` + `.linux` (zboot-PE), **ohne** `.cmdline`, `.initrd`, `.osrel`. `.hwids` enthält „Microsoft Corporation Surface", `.dtbauto` u. a. `microsoft,romulus13` und `romulus15`.
5. Fedoras GRUB lädt jede EFI-PE generisch (`LoadImage` mit Memory-Device-Path, LoadOptions = Cmdline, initrd per LoadFile2, weil PE-`MajorImageVersion >= 1`). Deshalb bootet sowohl ein reines zboot-`vmlinuz.efi` als auch ein Stub-Image per `linux`.
6. Der Stub (WoA-Firmware liefert **keinen** Device-Tree, also keine `compatible`-Übereinstimmung) berechnet aus SMBIOS die CHIDs, findet den Eintrag für Romulus13 in `.hwids`, lädt die passende `.dtbauto`-Sektion als DT-Konfigurationstabelle und startet den zboot-Kernel; die von GRUB übergebene initrd wird per LoadFile2 weitergereicht.
7. dracut-Live (dracut-live 108, Module dmsquash-live/livenet/pollcdrom) findet das Medium per Label, akzeptiert `squashfs` **und** `erofs` als Container, legt einen DM-Snapshot/OverlayFS an und startet KDE.

### 2.2 DTB-Mechanik für unsere Kernel

- **Standardweg (beide Kernel):** `vmlinuz-dtbloader.efi` = `ukify build --linux=<vmlinuz.efi> --stub=stubble.efi --hwids=<stubble-hwids> --sbat=@sbat --devicetree-auto=romulus13.dtb --devicetree-auto=romulus15.dtb --os-release="" --uname=<ver>`. Genau zwei `.dtbauto`-Sektionen (Kontrolle im Skript). Vorteile: identisch mit Fedoras Verfahren, keine `devicetree`-Zeile, bootet aus BLS-Einträgen ohne Sonderbehandlung, funktioniert später auch unter Secure-Boot-Lockdown. Der Ubuntu-stubble-Stub (Paket stubble 9-1) ist zu systemd-stub/ukify kompatibel (Canonical-README); die SBAT-Zeilen stammen aus demselben Paket.
- **Varianten (I²C-Touchscreen, exp):** Plain-`vmlinuz` + GRUB `devicetree ($root)/boot/dtb/sl7{a,b}/….dtb` vor `linux`. Nur ohne Secure Boot (fdt.mod ist per `grub_register_command_lockdown` registriert). Ein Stub-Image würde den GRUB-DTB überschreiben (valpackett 19.08.), daher der Plain-Kernel.
- **Installiertes System:** kernel-install (systemd 259.9, Layout `other`, Plugins 10-devicetree, 20-grub, 50-depmod, 50-dracut, 51-dracut-rescue, 95-set-boot-entry, 99-grub-mkconfig) kopiert `vmlinuz-dtbloader.efi` nach `/boot/vmlinuz-<ver>`, `dtb/` nach `/boot/dtb-<ver>`, schreibt `/boot/loader/entries/<machine-id>-<ver>.conf` (`linux`, `initrd`, `options`, ohne `devicetree`, weil `GRUB_DEVICETREE` nicht gesetzt ist) und baut die host-only-initramfs. Für DTB-Varianten im installierten System später: `grubby --devtree` oder BLS-Schlüssel `devicetree` (Fedora-blscfg unterstützt ihn; Pfad wird nicht per `grub2-mkrelpath` umgeschrieben → separates `/boot` beibehalten, Standardpartitionierung hat 2 GiB `/boot`).

### 2.3 Secure Boot

- shim akzeptiert nur Fedora-signierte oder per MOK enrollte Binaries. Unsere Kernel/Stub-Images sind unsigniert (`ukify` meldet „Wrote unsigned") → mit Secure Boot „bad shim signature". Am Gerät: **Secure Boot = None** (nicht „Microsoft only"), USB-Boot an, BitLocker aussetzen (local-facts).
- Später möglich: eigenes Zertifikat, `sbsign` auf `vmlinuz-dtbloader.efi`, `mokutil --import cert.der` + MokManager (`mmaa64.efi` ist auf dem ISO). Dann gilt Lockdown: GRUB-`devicetree` gesperrt, `.dtbauto` funktioniert weiter; ohne `.cmdline`-Sektion bleibt die GRUB-Cmdline unter Secure Boot gültig (systemd-stub(7)).

### 2.4 Kernelstand Fedora vs. unsere Kernel (was dem Stock-Kernel fehlt)

| Funktion | Fedora 6.19.10 / 7.2.6 | Kernel A 7.0.0-rc4-sl7 | Kernel B 7.3.0-rc3-sl7b |
|---|---|---|---|
| Romulus13-DTB, HWIDs | ja (Stub-Image) | ja (eigenes Stub-Image, 2 DTBs) | ja |
| Trackpad (spi-hid, GENI-QSPI-Protokoll 9, gpi) | nein | ja (ELLX) | ja (ItsLucas 0002 auf v7.3-rc3) |
| Touchscreen | nein | Varianten: exp (SPI spi10), i2cts (I²C i2c8) | Standard: SPI/GTCH (0003); Variante i2cts |
| WLAN-rfkill-Hack (ath12k) | nein | ja | ja (0001) |
| Speaker-Volume-Limit (LP #2149808) | nein | ja (Patch) | ja (im Ubuntu-7.3-Tree, verifiziert) |
| hamoa USB-QMP-PHY-Supply-Fix (upstream 4458dcd, 03.08.2026) | nicht in 7.2 (local-facts) | ja (romulus-Hunk) | **prüfen** (`grep -n vdda-phy arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus.dtsi`) **(unverifiziert)** |
| dwc3 reinit-phy-on-resume (Community) | nein | ja | nein (7.3 hat flache dwc3-Knoten, Community-Patches passen nicht; Upstream-Äquivalent `needs_full_reinit` **(unverifiziert)**) |
| spi-hid Power-Lifecycle / Panel-Follower | nein | nein | ja (0004/0005) |
| QRTR-HELLO-Revert (WLAN nach Resume) | n/a | n/a (7.0 hat den Upstream-Commit nicht) | ja (0006) |
| CPU-Thermal-Trips 85 °C, iris-Video | nein | nur exp-DTB | nein |
| Kamera OV02C10 | nein | ja (ELLX) | nein |
| Config-Unterschiede (aus `config-*` gegriffen) | – | USB_DWC3_QCOM=y, PHY_QCOM_EUSB2_REPEATER=y, QCOM_TSENS=y, ARM_SCMI_CPUFREQ=y | dieselben als **=m** (generic-Config) → müssen in der initramfs sein; `--no-hostonly` + dracuts arm64-Treiberblock (drivers/usb/dwc3, drivers/phy, …) deckt das ab – in Phase 2 per `lsinitrd` zählen |
| Gemeinsam | – | SQUASHFS=y (+ZSTD/XZ), EROFS_FS=m, OVERLAY_FS=m, ISO9660=m, LOOP=y, EFI_ZBOOT=y, SPI_HID=m, ATH12K=m, DRM_MSM=m, QCOM_Q6V5_PAS=m, SND_SOC_WSA884X=m, ARM_SBSA_WATCHDOG=m, EFI_VARS_PSTORE=m, PSTORE=y, MODULE_SIG=y ohne FORCE, ARM64_PTR_AUTH=y, SURFACE_FAN nicht gesetzt | |

### 2.5 Konsequenzen für das ISO

1. **Stub-Images ohne `.osrel` bauen** (Fehler in Phase 2, Abschnitt 0.2). Kontrolle: `objdump -h … | grep -cE '\.(osrel|cmdline|initrd)'` = 0, `.dtbauto` = 2, `.hwids` = 1; zusätzlich im Chroot `kernel-install inspect <ver> /lib/modules/<ver>/vmlinuz-dtbloader.efi` → „Kernel Image Type: pe", nicht „uki".
2. **Live-Rootfs als squashfs (zstd) statt EROFS** neu packen – dmsquash-live 108 akzeptiert beides; SQUASHFS=y in beiden Kerneln, EROFS nur als Modul (wäre auch ok, aber squashfs-tools sind erprobt). `-xattrs` zwingend (SELinux-Labels).
3. **Live-initrds mit Fedoras kiwi-Argumenten** (`dracut --no-hostonly --no-hostonly-cmdline --install /.profile --add "dmsquash-live livenet pollcdrom" --omit multipath`) pro Kernel; dazu unsere `/etc/dracut.conf.d/90-sl7.conf` (spi-hid, i2c-hid-of, GENI, ADSP-Stack; DSP-/GPU-Firmware und board-2.bin als `install_items`).
4. **Cmdline** aller SL7-Einträge: `clk_ignore_unused pd_ignore_unused systemd.tpm2_wait=0` (Fedora-Wiki); Standardeintrag zusätzlich `modprobe.blacklist=qcom_q6v5_pas` (USB-C-sicher). `arm64.nopauth` nur als Alternative (Ubuntu-x1e-Variante; Fedora hält es für X1E nicht nötig; beide Kernel haben ARM64_PTR_AUTH=y).
5. **Anaconda-Übernahme:** `/etc/anaconda/conf.d/90-sl7.conf` erweitert `preserved_arguments` um `systemd.tpm2_wait` (Stock-Liste hat bereits `clk_ignore_unused pd_ignore_unused arm64.nopauth`); `modprobe.blacklist=…` wandert als `/etc/modprobe.d/anaconda-denylist.conf` ins Zielsystem → `sl7-postinstall.service` entfernt sie beim ersten Start und setzt die Parameter per `grubby`. Ob `preserved_arguments` einen Schlüssel mit `=`-Wert (`systemd.tpm2_wait=0`) exakt so übernimmt, muss der QEMU-Installationstest zeigen **(unverifiziert)** – der Postinstall-Dienst setzt den Wert ohnehin.
6. **dnf-Schutz im Zielsystem:** `/etc/dnf/dnf.conf` hat keine Ausschlüsse und `/etc/sysconfig/kernel` steht auf `UPDATEDEFAULT=yes` (Anacondas rsync lässt `/etc/sysconfig/` laut Upstream-Quelle aus, medium). Ein späteres `dnf upgrade` würde Fedoras `kernel-core`/`kernel-uki-dtbloader` 7.2.x nachziehen und – über 95-set-boot-entry – zum Standard machen (kein Trackpad). Deshalb ins Rootfs: `exclude=kernel kernel-core kernel-modules* kernel-uki-dtbloader kernel-uki-virt` in `/etc/dnf/dnf.conf` (Kommentar mit Aufhebungsanleitung) – oder `dnf versionlock`. Unsere Pakete heißen `kernel` (Version 7.0.0_rc4_sl7 bzw. 7.3.0_rc3_sl7b); der Name kollidiert mit Fedoras Metapaket `kernel`, `installonlypkgs` verhindert aber ein Ersetzen.
7. **GRUB-Tastatur:** Launchpad #2084951 #29/#31 (Nov. 2024): auf dem SL7 funktioniert die Tastatur im GRUB nur mit `terminal_output gfxterm`; local-facts: direkt geflashte Sticks zeigten GRUB-Freezes/tote Tastatur, Ventoy half. Fedoras Stock-`grub.cfg` (und unsere `grub-sl7.cfg`) benutzen `terminal_output console`. Da das gesamte Sicherheitsnetz (Alternativ-Einträge) von einer funktionierenden Tastatur abhängt: in `grub-sl7.cfg` `if loadfont ($root)/boot/aarch64/loader/grub2/fonts/unicode.pf2; then set gfxmode=auto; insmod gfxterm; terminal_output gfxterm; fi` vor `terminal_input console` einbauen (Font liegt auf dem ISO). Für den QEMU-Test (serielle Konsole) `terminal_output gfxterm console` oder den Erfolg über den Timeout-Standardstart messen. **(unverifiziert für Fedora-GRUB auf dem SL7; Beleg gilt für Ubuntu-GRUB 2024.)**
8. **`/boot/0x3d6eb6b1`, `/boot/mbrid`, Volume-ID `Fedora-KDE-Live-44`** unverändert lassen (Suchanker und `root=live:CDLABEL=`); ISO mit `xorriso -boot_image any replay` aus dem Original ableiten (El-Torito/GPT-Layout bleibt). „Medium prüfen" funktioniert nur, wenn nach dem Bau `implantisomd5` läuft (isomd5sum ist auf dem Host nicht installiert) – Eintrag sonst als „nur Original" kennzeichnen.

---

## 3 Boot-Loop-Analyse

### 3.1 Was wir über den Ubuntu-Versuch wissen

- Ablauf (aus dem Recherche-Auftrag und local-facts rekonstruiert): offizielles Ubuntu-26.04-arm64-ISO installiert (stubble-Generic-Kernel 7.0.0-29 bootete), danach `sl7-install-on-laptop.sh`: `dpkg -i linux-image-7.0.0-rc4-sl7…` (Rev. 2 oder 3 – nicht protokolliert), stubble-Image als `/boot/vmlinuz-<ver>` (Plain als `.plain` gesichert), `/boot/sl7-romulus13.dtb` + GRUB-Fallback-Eintrag (`42_sl7_fallback`, Plain + `devicetree`), Firmware-Tar, `/etc/default/grub.d/90-sl7.cfg` (`clk_ignore_unused pd_ignore_unused`), `dracut --force --kver`, `update-grub`, iptsd, sl7-mac, Sleep-Hooks.
- Symptom: Boot-Schleife **nach dem Ubuntu-Logo** (also nach GRUB, Kernel gestartet, Plymouth sichtbar, dann Reset). Keine Logs.
- In dieser Sitzung an den Artefakten geprüft: Die stubble-Images Rev. 2 und Rev. 3 enthalten 32 `.dtbauto` (finddtbs filtert `-el2` – keine EL2-DTBs enthalten, EL2-Hypothese entfällt) und `microsoft,romulus13/15`. Der **Standard-DTB** `x1e80100-microsoft-romulus13.dtb` enthält in Rev. 2 bereits den experimentellen I²C-Touchscreen (i2c8 @0x34) und in Rev. 3 zusätzlich den SPI-Touchscreen auf spi10 (2× `hid-over-spi`), `iris` (qcvss8380.mbn) und 20 Thermal-Cooling-Einträge. Das heißt: **der Kernel, der in die Schleife lief, bootete mit einem DTB voller ungetesteter Knoten.**

### 3.2 Ursachen, geordnet nach Wahrscheinlichkeit

| Rang | Ursache | Belege | Passt zum Symptom? | Absicherung im neuen ISO |
|---|---|---|---|---|
| 1 | **Experimentelle DT-Knoten im Standard-DTB** (I²C-Touchscreen i2c8 mit Reset an gpio31; spi10-QSPI-Touchscreen mit `gpi_dma1`, 5-V-Regulator an gpio64; iris; Thermal-Trips). Ein Probe-Fehler/Hang in gpi/geni/i2c oder ein Regulator-Konflikt (gpio64 wird auch von ItsLucas 0003 mit 500 ms Anlauf „always-on" belegt) kann den Boot nach dem Splash abbrechen. | Rev.-3-DTB-Inhalt (lokal); gpi_dma-Probe-Fehler und „CH START completion timeout" im April 2026 (#1590); Kozlowski „Drop" zum I²C-Patch; ItsLucas: I²C-Experiment erfolglos. | Ja: Splash erscheint (simpledrm/efifb), dann Probe der QUP/GPI-Treiber aus der initramfs. Ob daraus ein *Reset* statt eines Hangs wird, hängt vom Watchdog ab (Rang 7). | Standard-DTB beider Kernel **ohne** Experimente (Kernel A: nur dwc3/Speaker/PHY-Patches; exp- und i2cts-Varianten nur als eigene Menüpunkte). |
| 2 | **`clk_ignore_unused pd_ignore_unused`** – widersprüchliche Belege: Launchpad #40 (27.11.2024): Entfernen beider Optionen ließ das SL7 booten; Fedora-Wiki 2026 und alle 2026er Cmdlines setzen beide. | LP #2084951 #40; Fedora-Wiki; cicorias-Gist. | Möglich (Clock-/Power-Domain-Abschaltung während des Boots). | Menüpunkt „ohne clk/pd_ignore_unused"; Standard mit beiden. |
| 3 | **initramfs-/Kernel-Mismatch auf Ubuntu:** `dracut` host-only für einen fremden Kernel (qcom-x1e-Flavour-Config vs. laufender generic-Kernel) – fehlende Module → Root nicht gefunden. | Ubuntu 26.04 nutzt dracut (local-facts); Modulnamen/Builtins unterscheiden sich zwischen Flavours. | Teilweise: ergäbe eher dracut-Emergency (Hang mit Splash) als Reset; mit `rd.timeout` und Watchdog aber auch als Schleife denkbar. | Live-initrd `--no-hostonly` mit vollem Treibersatz; nach Installation baut kernel-install die host-only-initramfs **auf dem Gerät** mit dem laufenden Kernel; `sl7-postinstall` baut sie erneut; `90-sl7.conf` erzwingt spi-hid/GENI/ADSP-Treiber + Firmware. |
| 4 | **ADSP-Start (qcom_q6v5_pas) resettet den USB-C-Mux/TCPM** – Boot-Medium verschwindet mitten im Boot. Für ein *installiertes* System auf NVMe irrelevant, für den **Live-Stick am USB-C-Port die Hauptursache** („hangs in a boot loop until I remove the USB", Fedora Discussion 144552). | Fedora-Wiki (Known Issue); Discussion 144552. | Für den Ubuntu-NVMe-Fall nein; für Live-Boot ja. | Standardeintrag mit `modprobe.blacklist=qcom_q6v5_pas`; zusätzlich Stick am **USB-A-Port** booten. |
| 5 | **GPU/Display:** Zap-Shader `qcdxkmsuc8380.mbn` nicht in der initramfs („gpu hw init failed: -2") oder dispcc-Parking-Bug (EFI-Framebuffer stirbt beim Binden von dispcc; Fix April 2026, in 7.0-rc4 vermutlich nicht enthalten **(unverifiziert)**). | cicorias-Gist; linux-clk-Patch 04/2026. | Ergibt **schwarzen Bildschirm**, keinen Reset – aber ohne Konsole nicht von einem Hang zu unterscheiden. | Firmware in jeder initramfs (`install_items`); `nomodeset`-Eintrag; Diagnose-Einträge ohne Splash mit `console=tty0`. |
| 6 | **64-GB-Modell / EFI-Speicherkarte:** Ubuntus ISO setzt für „Snapdragon" `cutmem 0x8800000000 0x8fffffffff`; das installierte System nicht (local-facts). Nur relevant, wenn Martins Gerät 64 GB hat. | questing-ISO-grub.cfg (local-facts). | Nur bei 64 GB. | Menüpunkt „64-GB-Modell (cutmem)". |
| 7 | **Watchdog als Mechanismus:** X1E in EL1 hat einen SBSA-Generic-Watchdog (`arm,sbsa-gwdt`, Linaro-Patch 02/2025); ein von der Firmware scharf geschalteter Watchdog macht aus jedem Hang einen zeitgesteuerten Reset („reset mid-boot at a wall-clock-dependent point", U-Boot-Hinweis 07/2026). ARM_SBSA_WATCHDOG ist in beiden Kerneln **=m**. **(unverifiziert)** | patchew 02/2025; ratatoskr 07/2026. | Erklärt, warum ein Probe-Hang (Rang 1/3/5) als Schleife erscheint. Prüfbar: ist die Zeit bis zum Reset konstant? | `initcall_debug`-Eintrag; ggf. `sbsa-gwdt` in `add_drivers` (Kernel pingt dann früh, `handle_boot_enabled`), erst nach Bestätigung am Gerät. |
| 8 | **`arm64.nopauth`** (Ubuntu-ISO setzt es, installiertes Ubuntu nicht; Fedora nur für 8cx Gen 3). | local-facts; Fedora-Wiki. | Unwahrscheinlich (Stock-Ubuntu bootet ohne). | Menüpunkt „mit arm64.nopauth". |
| 9 | **Stub/DTB-Auswahl falsch** (falsche `.dtbauto`, EL2-DTB). | lokal geprüft: keine EL2-DTB im Image, romulus13-HWIDs vorhanden. | Nein (ausgeschlossen). | Nur 2 DTBs im Image; Plain-Kernel + `devicetree` als Gegenprobe. |
| 10 | Speaker-Limit, sl7-mac, iptsd, Sleep-Hooks | userspace, laufen nach dem Boot | Nein. | – |

Fazit: Der wahrscheinlichste Auslöser ist die Kombination aus **ungetesteten DT-Knoten im Standard-DTB** (Rang 1) und einem **Reset-Mechanismus** (Rang 7), der einen Probe-Hang als Schleife erscheinen lässt. Zweitkandidat ist die Cmdline (Rang 2). Für den Live-Stick kommt der ADSP/USB-C-Effekt (Rang 4) als eigene, gut belegte Ursache hinzu.

### 3.3 Absicherungen, die das ISO deshalb bekommt

1. **Konservativer Patch-Satz im Standard:** Kernel A = ELLX-Tag + dwc3-Resume + Speaker-Limit + hamoa-PHY-Supplies, Standard-DTB = unveränderter ELLX-romulus13 (+PHY-Hunk). Kernel B = Ubuntu 7.3 + ItsLucas 0001–0006 (Trackpad und SPI-Touchscreen sind dort Teil des Standard-DTB – das ist bewusst, weil zwei Quellen dahinterstehen; die I²C-Variante ist nur Menüpunkt).
2. **GRUB-Menü mit Alternativen** (`build/fedora/grub-sl7.cfg`, Timeout 20 s): Kernel B USB-C-sicher (Standard) → Kernel B mit ADSP → Kernel A USB-C-sicher → Kernel A mit ADSP → Untermenü Touchscreen-Varianten (Plain-Kernel + `devicetree`) → Untermenü Diagnose: Kernel B/A ohne Splash (`plymouth.enable=0 loglevel=7 systemd.show_status=1 console=tty0 rd.timeout=180`), „extrem" (`initcall_debug rd.shell rd.debug`), `arm64.nopauth`, ohne `clk/pd_ignore_unused`, `cutmem` (64 GB), `nomodeset`, **Fedora-Original** (Stock-Kernel unverändert), Fedora-Original mit X1E-Parametern, Medium prüfen, QEMU-Eintrag.
3. **Ergänzungen an `grub-sl7.cfg` vor Phase 3:** (a) `gfxterm` mit Font-Fallback (2.5 Punkt 7); (b) im „extrem"-Eintrag zusätzlich `boot_delay=100` (verlangsamt jede printk-Zeile, damit die letzten Meldungen vor einem Reset lesbar bleiben) und `panic=0` (kein automatischer Reboot bei Panic – dann bleibt die Panic-Meldung stehen; Fedora setzt standardmäßig keinen `panic=`-Wert); (c) ein Eintrag „Kernel B – Diagnose ohne ADSP-Blacklist" fehlt bislang nicht, aber ein Eintrag **„Kernel A – exp-DTB mit ADSP"** könnte für den Touchscreen-Test nach der Installation nützlich sein (optional).
4. **Logs ohne persistenten Speicher:** Beide Kernel haben `EFI_VARS_PSTORE=m` und `PSTORE=y`. Wenn die SL7-Firmware Variablen-Schreibzugriffe zur Laufzeit erlaubt (Fedora-Wiki setzt für X1E kein `efi=noruntime`, also plausibel **(unverifiziert)**), landet eine **Panic** in EFI-Variablen und ist nach dem nächsten Boot unter `/sys/fs/pstore/` lesbar – auch vom Fedora-Original-Eintrag aus. `efi_pstore` in `add_drivers` der `90-sl7.conf` aufnehmen. Ein harter Watchdog-Reset hinterlässt dagegen nichts; dafür bleibt das Handy-Video des Diagnose-Eintrags (ohne Splash, `console=tty0`) das verlässlichste Protokoll. `ramoops` braucht einen `reserved-memory`-Knoten im DT, den wir nicht haben – nicht vorgesehen.
5. **Bedienregeln am Gerät:** nach jedem Fehlversuch **kalt ausschalten** (warmer Reboot lässt Touchpad/Touchscreen hängen – horizontblau 23.08.); Live-Stick zuerst am **USB-A-Port**; Reihenfolge bei Schleife: Kernel B (Standard) → Kernel B Diagnose → Kernel A → ohne clk/pd → arm64.nopauth → cutmem (nur 64 GB) → Fedora-Original mit X1E-Parametern → Fedora-Original pur. Bootet das Fedora-Original, aber keiner unserer Kernel, liegt es an unseren Trees/DTBs; bootet nicht einmal das Original, liegt es an Medium/Firmware/UEFI-Einstellungen.
6. **Das Live-System schreibt nichts auf die SSD** (kein persistentes Overlay) – die Fehlersuche gefährdet Windows nicht; BitLocker trotzdem vorher aussetzen.

---

## 4 Entscheidung Kernel-Basis und Paketierung

### 4.1 Optionen

| | Option | Für | Gegen |
|---|---|---|---|
| A | ELLX 7.0.0-rc4-12 + konservative Patches (`sl7-fedora`-Zweig) | Von der Community seit Mai auf dem SL7 betrieben (Trackpad, WLAN, Kamera); unsere Cross-Build-Pipeline ist eingespielt (12 min Kernel); Patches sind klein und nachvollziehbar. | rc-Kernel vom März; fehlende Upstream-Fixes (dispcc, GENI-Callbacks, hamoa-PHY nur per Patch); ELLX-Maintainer hat sein Gerät wegen Lautsprecherschaden getauscht; Repo seit 14.05. still. |
| B | Ubuntu 26.10 linux-source 7.3.0-5.5 + ItsLucas 0001–0006 (Tag `sl7b`) | Neuester vollständiger SL7-Stack, auf v7.3-rc3 rebased; Speaker-Limit, GENI-Resource-Callbacks, QRTR-Fix im Tree; generic-Config aus `linux-buildinfo` (offiziell); DT-Touchscreen aus Windows-ACPI abgeleitet. | Einzelperson, Binaries „not hardware-validated" **(unverifiziert)**; rc3-Kernel; dwc3-Community-Patches passen nicht (Upstream-Äquivalent unklar); hamoa-PHY-Fix-Status unklar. |
| C | Fedora kernel-ark-SRPM (7.2.6/7.2.7) + SL7-Patches in `mock --forcearch aarch64` | 1:1-Fedora-Pakete inkl. `kernel-uki-dtbloader`, saubere dnf-Integration, Fedora-Config (BTI, Lockdown, Signaturen). | Rein qemu-user-emulierter Bau (Bauzeit unbelegt, erfahrungsgemäß viele Stunden); Fedora-Spec ist nicht für x86-Cross-Build vorgesehen; spi-hid/QSPI/gpi/rfkill müssten auf 7.2.x + Fedora-Config portiert werden; Anubis blockiert dist-git-Abrufe. |
| D | Fedora-Stock-Kernel + eigene DTB/Firmware | Kein Kernelbau. | Kein spi-hid, kein QSPI → kein Trackpad; kein Speaker-Limit (Hardware-Risiko). |
| E | Concept-PPA linux-qcom-x1e 7.2.0-18.18 / 7.3.0-15.15 + Rebase der ELLX-Teile | Canonical-gepflegter X1E-Tree. | Rebase-Arbeit identisch mit B, aber ohne ItsLucas' Lifecycle-Patches. |
| F | murkurie/ELLX-Kernel v7.2.0-sl7-13.8 (18.09.) **(unverifiziert)** | „HIDSPI v3, Webcam, Retimer-PM, Wi-Fi 7" auf Linux 7.2. | Herkunft/Provenance unbekannt, nicht abgerufen; kein Patch-Stack einsehbar. |

### 4.2 Entscheidung

**B als Standard, A als Rückfall, Fedora-Stock als dritter Rückfall – alle drei im selben ISO.** Begründung: Kein Kandidat ist auf dem Gerät verifiziert (Martins Gerät hat noch nie einen unserer Kernel gebootet). Zwei unabhängige Trees, die dieselben Kernfunktionen mit unterschiedlichem Code erreichen (ELLX-spi-hid vs. ItsLucas-Rebase, i2c8- vs. spi10-Touchscreen), erhöhen die Chance, dass *einer* durchbootet, und erlauben am Gerät eine echte A/B-Diagnose ohne Neubau. Der Fedora-Stock-Kernel trennt zusätzlich „unser Kernel" von „Medium/Firmware/UEFI" als Fehlerursache. Option C wird nachgezogen, sobald ein Tree am Gerät läuft und der Patch-Stack geschrumpft ist (Upstream-spi-hid/QSPI); Option F wird geprüft, sobald Budget für den Abruf da ist.

Konkrete Pflegeregeln:
- Kernel A: Tree `/work/sl7/kernel/ellx-7.0-sl7`, Zweig `sl7-fedora`, Patch-Satz aus `wsl-tree-safe-exp.sh` (die drei Patches liegen uncommitted im Arbeitsbaum – vor weiteren Änderungen committen oder das Skript erneut laufen lassen, das den Zustand reproduziert).
- Kernel B: Tree `/work/sl7/kernel/ubuntu-7.3`, Tag `sl7b` (+ Commit `romulus13-i2cts`); vor einem Rebuild `git tag -f sl7b HEAD` oder die Tag-Prüfung im Skript auf `git merge-base --is-ancestor sl7b HEAD` ändern.
- Speaker-Limit: in beiden Kerneln vorhanden (A per Patch, B im Ubuntu-Tree) – nach dem ersten Boot `amixer -c0 contents | grep -A3 -i 'PA Volume'` → `platform_max` = 6.

### 4.3 Paketierung: `binrpm-pkg` (Cross) – und warum kein volles UKI

- `make -j1 binrpm-pkg RPMOPTS="--define '_topdir …' --target aarch64-linux"` (Cross-Compile; `--without=devel` automatisch, also kein kernel-devel) liefert `kernel-<ver>.aarch64.rpm` mit `/lib/modules/<ver>/{vmlinuz,System.map,config,dtb/…,kernel/…}`, `%ghost /boot/{vmlinuz,System.map,config}-<ver>`, `%ghost /boot/dtb-<ver>`; `%post` ruft `kernel-install add <ver> /lib/modules/<ver>/vmlinuz` und kopiert nach `/boot`. Das entspricht dem Layout von Fedoras kernel-core (kernel-ark: `%posttrans kernel-install add …`), daher funktionieren 20-grub.install, 50-dracut.install und Anacondas `create_bls_entries` unverändert. Verifiziert: RPM-Inhalte und Skripte (`inspect3.txt`), Installation im Chroot (Phase 2 Schritt 1).
- Im Rootfs installieren wir mit `rpm -ivh --nodeps --noscripts` und führen `depmod`, Kopien nach `/boot`, Stub-Image und dracut selbst aus – so bleibt kontrollierbar, dass **das Stub-Image** (nicht der Plain-Kernel) unter `/boot/vmlinuz-<ver>` und `/lib/modules/<ver>/vmlinuz-dtbloader.efi` liegt, genau wie bei Fedoras `kernel-uki-dtbloader` (Anaconda ruft `kernel-install add <ver> /lib/modules/<ver>/vmlinuz-dtbloader.efi`, wenn die Datei existiert, sonst `vmlinuz`).
- **Kein volles UKI** (mit `.cmdline`/`.initrd`/`.osrel`): kernel-install würde Layout `uki` wählen (90-uki-copy nach `/boot/efi/EFI/Linux/`, kein initramfs, keine BLS-Typ-1-Einträge), GRUB müsste `uki`/`efi`-Einträge nutzen, die Cmdline wäre unter Secure Boot eingefroren, und die Live-initrd-Logik (dmsquash-live) wäre nicht mehr per GRUB steuerbar. Fedoras Change hat genau deshalb das „unvollständige UKI" gewählt; wir übernehmen es.
- **Muss-Korrektur in `wsl-fedora-rootfs-phase2.sh` Schritt 3:** `ukify build … --os-release="" --uname="$K" …` und Kontrolle `objdump -h | grep -c '\.osrel'` = 0 (siehe 0.2). Danach `kernel-install inspect` im Chroot.
- Plain-Kernel (`/lib/modules/<ver>/vmlinuz`, zboot-PE) bleibt für die `devicetree`-Einträge und für den QEMU-Direktboot (`-kernel`) erhalten; Fedoras GRUB lädt ihn generisch (plausibel, QEMU-Test 1/2 prüft es).

### 4.4 Update-Strategie im installierten System

- `/etc/dnf/dnf.conf`: `exclude=kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-uki-dtbloader kernel-uki-virt` (mit Kommentar, wie man es für ein bewusstes Fedora-Kernel-Update aufhebt). Alternativ `python3-dnf-plugin-versionlock`.
- Eigene Kernel-Updates: neues RPM + Stub-Image + `kernel-install add <ver> /lib/modules/<ver>/vmlinuz-dtbloader.efi` (Skript `sl7-kernel-update.sh` als späterer Baustein).
- `installonly_limit=3` (Fedora-Standard) betrifft nur Pakete gleichen Namens; Fedoras 6.19.10 (`kernel-uki-dtbloader`) bleibt als Rückfall erhalten.

---

## 5 Entscheidung Trackpad (haptisch, Kraft-Klick)

### 5.1 Welcher Fork

**alex-lentz/iptsd @3663e96 (16.07.2026)**, Basis v3.1.0. Was er ändert (README + Commit-Log lokal im Rootfs `/root/sl7/iptsd`): IPTS-Report-Frame 0x94, Bit 1 in Byte 2 = physischer Druck → über den vorhandenen `on_button`-Pfad als BTN_LEFT; Commit 16169f6 „daemon: Add button debounce and fix palm-suppression click leak" (`[Touchpad] ButtonDebounceMs`, verifiziert in `src/core/linux/config-loader.hpp` Zeile 163); systemd-sleep-Hook, der nach Resume udev-add für hidraw neu feuert; `Restart=on-failure` in der Unit.
Warum dieser Fork: Upstream linux-surface/iptsd hat seit v3.1.0 (29.12.2023) keine Releases und keinen SL7-/Haptik-Support; ELLX liefert genau diesen Fork als `iptsd_3.1.0-1_arm64.deb` (bryce-hoehn-README), horizontblau (23.08.) und ricky-davis (16.07.) bestätigen die Funktion; orvitpngs angekündigter „nicht vibe-codierter" Fork (12.05.) ist bis heute nicht öffentlich. Einschränkung des Autors: „vibe coded", „I do not stand behind the quality of this code" – deshalb nur der Klick-Pfad übernommen, Konfiguration konservativ, und die Quelle liegt im Rootfs (`/root/sl7/iptsd`) für Nachbauten.
Nicht Teil der Lösung: die haptische Rückmeldung selbst (Aktor) – keine Quelle beschreibt eine Linux-Ansteuerung; ob der Controller sie intern erzeugt, ist offen **(unverifiziert)**.

### 5.2 Wie gebaut (erledigt in Phase 1)

- Im aarch64-Fedora-Chroot mit Fedoras Toolchain per `iptsd-sl7.spec` (`%meson -Dsample_config=true -Dservice_manager=systemd -Ddebug_tools=calibrate,dump,perf`), BuildRequires `meson ninja-build gcc-c++ cmake cli11-devel eigen3-devel fmt-devel inih-devel spdlog-devel guidelines-support-library-devel` (Fedora-Name für Microsoft.GSL; Bau lief durch, Paketname damit bestätigt). Ergebnis `iptsd-3-0.sl7.git3663e96.fc44.aarch64.rpm` (Kopie unter `build/fedora/out/iptsd/` anlegen – der Phase-1-Kopierschritt hat sie nach `$B/out/iptsd/` geschrieben; im Windows-Listing fehlt der Ordner, also nachkopieren aus `/work/sl7/fedora/rootfs/root/rpmbuild/RPMS/aarch64/`).
- Warum so: Das ELLX-Deb stürzte bei horizontblau mit SIGILL ab (Objekte mit und ohne BTI gemischt). Fedoras Compiler-Flags setzen `-mbranch-protection=standard` durchgängig; `readelf -n /usr/bin/iptsd` zeigt jetzt „AArch64 feature: BTI, PAC, GCS" für das gesamte Binary. Upstreams hartes `-march=armv8.2-a+crypto+fp16+rcpc+dotprod` (bei `optimization=3`) ist für den X1E (ARMv8.7) unproblematisch.
- Build-Werkzeuge wurden nach dem Bau wieder entfernt (Phase 1 Schritt 5), das Rootfs ist sauber.

### 5.3 Units, Regeln, Geräte-Ausblendung

- Aus dem RPM (verifiziert): `/usr/lib/systemd/system/iptsd@.service` (`BindsTo=%i.device`, `ExecStart=/usr/bin/iptsd /%I`, `Restart=on-failure`), `/usr/lib/udev/rules.d/50-iptsd.rules` (jedes neue hidraw-Gerät durch `iptsd-check-device` prüfen → `SYSTEMD_WANTS+=iptsd@<escaped>.service`), `/usr/lib/systemd/system-sleep/iptsd`, Werkzeuge `iptsd-calibrate`, `iptsd-check-device`, `iptsd-dump`, `iptsd-find-hidraw`, `iptsd-foreach`, `iptsd-perf`, `iptsd-systemd`. Das ELLX-Deb brachte Unit und Regel **nicht** mit (Community-Issue #23) – bei uns kommen sie aus dem Quellbau.
- **Noch einzubauen (Phase 2, neu):** Geräte-Ausblendung nach horizontblau: der Controller exponiert neben dem Raw-Knoten weitere HID-Knoten; libinput soll nur das iptsd-uinput-Touchpad sehen, der Mouse-Knoten (Klick) muss sichtbar bleiben. Regel-Vorschlag `/etc/udev/rules.d/60-sl7-touchpad-hide.rules`:
  `ACTION=="add|change", SUBSYSTEM=="input", ENV{ID_PATH}=="platform-88c000.spi-cs-0", ENV{ID_INPUT_TOUCHPAD}=="1", ENV{LIBINPUT_IGNORE_DEVICE}="1"` (spi19 = QUP2 SE3 @0x88c000; **(unverifiziert)** – Pfad und Knoten am Gerät mit `libinput list-devices` und `udevadm info -q property` bestätigen; bei Kernel B mit ItsLucas-DT kann der Bus/Chip-Select abweichen).
- Voraussetzung im Kernel: spi-hid als Modul in initramfs und Rootfs (A: ELLX-spi-hid an spi19; B: ItsLucas 0002/0004), `spi-geni-qcom` mit QSPI-Protokoll 9, `gpi_dma`. Ohne diese DT-/Treiberteile gibt es kein hidraw-Gerät und iptsd startet gar nicht (Fedora-Stock-Kernel).

### 5.4 Kalibrierung

- Installiert: `/etc/iptsd.d/91-calibration-045E-0C77.conf` (ELLX-Startwert: SizeMin 0.200, SizeMax 6.200, AspectMin 1.000, AspectMax 5.600; Samples 1273) und `/etc/iptsd.d/90-sl7-touchpad.conf` (`ButtonDebounceMs = 25`, `DisableOnPalm = true`).
- Am Gerät (13,8"-Trackpad kann vom 15"-Startwert abweichen): `sudo iptsd-foreach -t touchpad -- echo {}` → hidraw-Knoten; `sudo systemctl stop 'iptsd@*'`; `sudo iptsd-calibrate /dev/hidrawN`, Finger über die gesamte Fläche, Ctrl+C; Werte in `91-calibration-…conf` eintragen; `sudo systemctl start 'iptsd@*'`. Ergebnis zurück ins Rootfs übernehmen (nächster ISO-Bau).
- Bekannte Grenzen: „tap to click is insanely sensitive", „IPTSD just doesn't like my fingers" (ProgrammerIn-wonderland, Apr./Mai 2026) – Feinabstimmung erst am Gerät; Suspend kann das Trackpad hängen lassen (bryce-hoehn) → `sl7-trackpad-rebind`-Hook + Fork-Sleep-Hook; nach Soft-Reboot ggf. tot → Power-off.

---

## 6 Bauplan für das ISO – Schritt für Schritt

Alle Skripte: `build/fedora/`, Arbeitsverzeichnis in WSL: `/work/sl7/fedora` (Rootfs `rootfs/`, Stage `stage/`, Ausgabe `out/`). Lange Läufe **im Hintergrund** starten (`nohup bash … > log 2>&1 &`) und per `tail -f` verfolgen – ein Vordergrund-Aufruf aus der Build-Sitzung wird nach 2 Minuten beendet (so ist Phase 2 am 22.09. gestorben).

### 6.1 Erledigt (nicht wiederholen)

1. Werkzeuge (`wsl-setup-fedora-tools.sh`), ISO-Analyse, Rootfs-Kopie mit xattrs (`wsl-fedora-rootfs-copy.sh`).
2. Kernel A: `wsl-tree-safe-exp.sh` → `wsl-build-kernel-fedora.sh` (RPM Rev. 7) + `wsl-dtb-i2cts-a.sh`.
3. Kernel B: `wsl-fetch-itslucas.sh` → `wsl-prepare-kernel-73.sh` → `wsl-fix-kernel-73.sh` → `wsl-build-kernel-73-fedora.sh` (RPM Rev. 2) + `wsl-dtb-i2cts-b.sh`.
4. Phase 1 (`wsl-fedora-rootfs-phase1.sh`): `dnf upgrade --exclude=kernel*`, iptsd-RPM gebaut/installiert, Build-Werkzeuge entfernt, Kalibrier-/Konfigdateien.
5. Phase 2 Schritte 1–7 (Kernel-RPMs, DTB-Varianten, Firmware, sl7-mac, Sleep-Hooks, Konfiguration) – **Schritt 3 muss wiederholt werden**.

### 6.2 Phase 2 korrigiert wiederholen

1. `wsl-fedora-rootfs-phase2.sh` anpassen:
   - Schritt 1 idempotent machen (`rpm -q kernel-…` prüfen statt erneut `rpm -ivh`; bei erneutem Lauf nur `depmod` und Kopien).
   - Schritt 3: `ukify build … --os-release="" --uname="$K" …`; Kontrolle erweitern: `.osrel/.cmdline/.initrd` = 0, `.dtbauto` = 2, `.hwids` = 1, `.uname` = 1; danach `run kernel-install inspect "$K" /lib/modules/$K/vmlinuz-dtbloader.efi | grep 'Image Type'` → `pe`.
   - Schritt 7: `/etc/dnf/dnf.conf` mit `exclude=…` (4.4); `efi_pstore` in `add_drivers` von `90-sl7.conf`; udev-Regel `60-sl7-touchpad-hide.rules` (5.3) – als Datei ablegen, aber mit Kommentar „am Gerät verifizieren"; `SL7-Hinweise.txt`/`sl7-release` Formulierung „nicht hardwaregetestet" (1.6).
   - Schritt 8: nach jedem `dracut` zusätzlich zählen: `dwc3-qcom`, `phy-qcom-qmp-combo`, `phy-qcom-eusb2-repeater`, `pcie-qcom`, `nvme`, `usb-storage`, `uas`, `spi-geni-qcom`, `gpi`, `spi-hid`, `qcom_q6v5_pas`, `qcadsp8380`, `board-2.bin`, `dmsquash-live-root`, `overlay`; bei Kernel B müssen die =m-Treiber (USB_DWC3_QCOM, EUSB2-Repeater, TSENS, SCMI-cpufreq) enthalten sein.
2. Lauf: `nohup bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora/wsl-fedora-rootfs-phase2.sh" > /work/sl7/fedora/phase2-run.log 2>&1 &` (erwartet 30–60 min; dracut unter qemu-user ist der Löwenanteil; SELinux-Relabel mit `setfiles -r` vom Host einige Minuten).
3. Abschlusskontrolle: `ls -la rootfs/boot/` (initramfs-7.0…, initramfs-7.3… vorhanden), `rpm --root rootfs -qa | sort | uniq -d` zeigt nur `kernel` (zweimal, gewollt), keine Chroot-Mounts mehr, `getfattr` Stichproben.

### 6.3 Phase 3 – ISO bauen (`wsl-fedora-build-iso.sh`)

1. `grub-sl7.cfg` ergänzen: gfxterm-Block (2.5/7), `boot_delay=100 panic=0` im „extrem"-Eintrag; `grub-script-check` läuft im Skript.
2. Lauf im Hintergrund: mksquashfs (zstd 15, 1 MiB, `-xattrs`, ~10–20 min), Boot-Dateien (`linux-sl7a/b` = Stub-Images, `vmlinuz-sl7a/b` = Plain, `initrd-sl7a/b`, `/boot/dtb/sl7a|sl7b/*.dtb`), `xorriso -indev Original -outdev Neu -boot_image any replay -volid Fedora-KDE-Live-44 -update squashfs.img -update grub.cfg -map …`. Das Skript prüft, dass alle in `grub.cfg` referenzierten Pfade im Stage liegen.
3. Kontrollen: `xorriso -report_el_torito plain` (ein UEFI-Eintrag, GPT-Partition 2 wie im Original), `-find`-Liste, SHA256 nach `build/fedora/out/iso/`. Optional `implantisomd5` (dann `apt install isomd5sum`), sonst Menütext „Medium prüfen" auf „nur Fedora-Original" belassen.
4. Größe: Original 3,12 GB; unser Rootfs ist durch zwei Kernel (≈2 × 160 MB Module) und Firmware (20 MB) größer, squashfs-zstd komprimiert schwächer als EROFS-lzma → mit 3,5–4 GB rechnen (Stick ≥ 8 GB).

### 6.4 Phase 4 – Tests in QEMU vor dem Gerät (`wsl-fedora-qemu-test.sh`)

| Test | Was er beweist | Erfolgskriterium |
|---|---|---|
| 1: ISO per UEFI (AAVMF) → GRUB → Standardeintrag nach Timeout (Kernel B Stub-Image) | Fedoras GRUB lädt unser Stub-Image; Stub fällt ohne HWID-Treffer auf den Firmware-DT zurück; Live-initrd findet das Medium (Label), mountet squashfs, startet systemd | „Reached target Graphical" / sddm auf `ttyAMA0`; im Log `Linux version 7.3.0-rc3-sl7b`, `Machine model: linux,dummy-virt` |
| 2: Kernel A direkt (`-kernel vmlinuz -initrd initramfs -append LIVE …`) mit dem ISO als CD | Plain-zboot-Kernel + Live-initrd unabhängig von GRUB | wie 1 mit `7.0.0-rc4-sl7` |
| 3 (neu): Kernel B direkt wie Test 2 | Symmetrie | wie 2 |
| 4 (neu, optional, aufwendig): Anaconda-Installation in QEMU auf eine virtuelle NVMe (`-device nvme`, 40 GB), Anzeige über WSLg (`-display gtk`) oder VNC; danach Platte mounten | Anaconda erzeugt BLS-Einträge für 7.3.0-rc3-sl7b, 7.0.0-rc4-sl7 und 6.19.10 (Typ 1, `linux /vmlinuz-<ver>`, `initrd /initramfs-<ver>.img`, `options` mit `clk_ignore_unused pd_ignore_unused systemd.tpm2_wait=0`), `/boot/initramfs-7.*.img` vorhanden, `/etc/kernel/cmdline`, `anaconda-denylist.conf` (wird von sl7-postinstall entfernt), `/etc/dnf/dnf.conf`-Exclude vorhanden, Standard-Eintrag = Kernel B | Sichtprüfung der Dateien; Boot der virtuellen Platte bis Login |
| 5 (neu, billig): `kernel-install inspect` im Chroot für beide Stub-Images | Klassifizierung `pe` (nicht `uki`) | Ausgabe |

Der QEMU-Test prüft Kernel/initrd/squashfs/GRUB, **nicht** X1E-Treiber, DTB-Auswahl per HWID oder Trackpad. Was nur das Gerät zeigen kann, steht in 6.7.

### 6.5 Was in das Live-Image kommt (Soll-Liste, Kontrolle vor Phase 3)

- `/boot/aarch64/loader/`: `linux`, `initrd` (Fedora-Original, unverändert), `linux-sl7a`, `linux-sl7b` (Stub-Images ohne `.osrel`), `vmlinuz-sl7a`, `vmlinuz-sl7b` (Plain), `initrd-sl7a`, `initrd-sl7b`; `/boot/dtb/sl7a/{romulus13,romulus13-exp,romulus13-i2cts,romulus15}.dtb`, `/boot/dtb/sl7b/{romulus13,romulus13-i2cts,romulus15}.dtb`; `/boot/grub2/grub.cfg` (SL7-Menü); `/SL7-Hinweise.txt`.
- Rootfs (`/LiveOS/squashfs.img`): Fedora 44 KDE, Stand 22.09.; Kernel A, B, Stock 6.19.10 mit Modulen, DTBs, Stub-Images; iptsd-RPM + Konfiguration; Firmware unter `/usr/lib/firmware/updates/`; sl7-mac 1.0.2 (`sl7-wifi-mac.service` aktiv); Sleep-Hooks; `90-sl7.conf` (dracut), `90-sl7.conf` (anaconda), `sl7-scmi-cpufreq.conf`, `sl7-postinstall.service` (aktiviert, läuft nur ohne `rd.live.image`), `/etc/sl7-release`, `SL7-Hinweise.txt` in `/etc/skel/Desktop`, dnf-Exclude, udev-Ausblendregel, SELinux-Labels relabelt.
- Nicht enthalten (bewusst): Kamera-Stack für Kernel B, Fingerabdruck, NPU, Lautsprecher-Modulsperre (nur Opt-in-Rezept in `SL7-Hinweise.txt`; die Sperre legt die ganze Soundkarte still – local-facts).

### 6.6 Wie Anaconda alles in die Installation übernimmt

1. Live-Session (Kernel B), Anaconda-WebUI „Auf Festplatte installieren"; Standardpartitionierung Btrfs mit separatem `/boot` (2 GiB) und ESP (500–600 MiB) beibehalten.
2. `InstallFromImageTask`: rsync des Live-Rootfs (Excludes u. a. `/boot/loader/`, `/boot/efi/`, `/boot/grub2/`, `/etc/machine-id`, laut Upstream-main auch `/etc/sysconfig/` – gegen anaconda-core 44.30 nicht lokal geprüft, medium). Damit kommen `/lib/modules/*`, `/boot/vmlinuz-*`, `/boot/dtb-*`, Firmware, iptsd, Konfiguration, dnf.conf und Dienste mit.
3. `get_kernel_version_list`: Glob `/boot/vmlinuz-*` ohne `-rescue-` → 6.19.10-300.fc44.aarch64, 7.0.0-rc4-sl7, 7.3.0-rc3-sl7b.
4. `create_bls_entries`: löscht `/boot/loader/entries/*.conf`; pro Version `kernel-install add <ver> /lib/modules/<ver>/vmlinuz-dtbloader.efi` (Datei existiert für alle drei) → 20-grub.install kopiert nach `/boot/vmlinuz-<ver>`, schreibt BLS-Eintrag, 50-dracut baut host-only-initramfs (unsere `90-sl7.conf` erzwingt spi-hid/GENI/ADSP + Firmware), 95-set-boot-entry setzt den Standard; danach `grub2-mkconfig -o /etc/grub2.cfg` (`update_bls_cmdline` schreibt `/etc/kernel/cmdline = root=… ro $GRUB_CMDLINE_LINUX …` mit den `preserved_arguments` aus der Live-Cmdline).
5. `recreate_initrds`: `dracut -f /boot/initramfs-<ver>.img <ver>` erneut.
6. Erster Start: `sl7-postinstall.service` (nur ohne `rd.live.image`, einmalig): Denylist `qcom_q6v5_pas` entfernen, `grubby --update-kernel=ALL --remove-args="modprobe.blacklist=qcom_q6v5_pas" --args="clk_ignore_unused pd_ignore_unused systemd.tpm2_wait=0"`, initramfs neu; Log `/var/lib/sl7/postinstall.log`. Danach ist ADSP (Audio, Akku-Status über battmgr, USB-C-Altmode) aktiv.
7. Was **nicht** automatisch passiert: Secure Boot bleibt aus; Kalibrierung ist der 15"-Startwert; DTB-Varianten gibt es im installierten System nicht als Menüpunkte (bei Bedarf: `grubby --add-kernel /boot/vmlinuz-<ver>.plain … --devtree /boot/dtb-<ver>/qcom/…-i2cts.dtb` oder BLS-Eintrag von Hand – dafür den Plain-Kernel zusätzlich nach `/boot/vmlinuz-<ver>.plain` legen, Phase 2 Schritt 3 ergänzen).

### 6.7 Stick und erster Boot am Gerät

1. `Fedora-Stick-schreiben.ps1` anlegen (roh/dd-artig unter Windows: Datenträger per Nummer wählen, doppelt bestätigen, `Get-Disk`/`Clear-Disk`, Blockkopie mit .NET-Streams oder `dd`-Port; danach Rücklesen der ersten MB und SHA256-Vergleich des ISO vor dem Schreiben mit `build/fedora/out/iso/*.sha256`). Ventoy ist für Fedora-arm64-Stub-Images nicht belegt (Thread 195494) – erst später testen.
2. UEFI: Secure Boot **None**, USB-Boot an; Windows: BitLocker aussetzen (`manage-bde -protectors -disable C: -RebootCount 2`), Recovery-Key gesichert.
3. Stick am **USB-A-Port**, Boot-Menü, Standardeintrag laufen lassen (20 s). Handy-Kamera bereithalten. Bei Schleife: kalt ausschalten, nächsten Eintrag nach 3.3 Punkt 5.
4. Nach erfolgreichem Live-Boot, bevor irgendetwas Ton ausgibt: `amixer -c0 contents | grep -A3 -i 'PA Volume'` (platform_max 6), `cat /proc/asound/cards`, `dmesg | grep -iE 'wsa884x|EPROBE|spi.?hid|hid-over|gpi|ath12k|msm|zap|adsp'`, `libinput list-devices`, `systemctl status 'iptsd@*'`, `sl7-mac all`, `cat /sys/firmware/devicetree/base/model`, `cat /sys/fs/pstore/* 2>/dev/null`, `ls /sys/bus/soundwire/devices`, `alsaucm -c X1E80100-Romulus list _verbs`.
5. Lautstärke ≤ 70 %, nie „Pro Audio", erster Ton bei ~20 %.

---

## 7 Risiken und offene Punkte

1. **Nichts ist auf Martins Gerät gebootet.** Weder Kernel A noch B noch das Fedora-Stock-Image. Alles ab Abschnitt 3 sind Hypothesen mit Absicherungen, keine Befunde.
2. **`.osrel`-Fehler** in den vorhandenen Stub-Images (0.2) – vor Phase 3 beheben, sonst installiert Anaconda ein nicht bootfähiges System mit unseren Kerneln.
3. **GRUB-Tastatur** auf dem SL7 (2.5/7): ohne funktionierende Tastatur greift keine Alternative; gfxterm-Fix ist für Fedora-GRUB **(unverifiziert)**. Notlösung: externe USB-Tastatur am zweiten Port.
4. **Kernel B nicht hardwaregetestet** (ItsLucas-Releases „not hardware-validated"); **hamoa-USB-PHY-Supply-Fix** in 7.3 nicht geprüft **(unverifiziert)**; dwc3-Resume-Verhalten in 7.3 unklar.
5. **Touchscreen:** SPI/GTCH (zwei Quellen) vs. I²C (eine, widersprochen) – Ergebnis nur am Gerät; die I²C-Variante ist experimentell. Variant-DTBs sind ~50 KB kleiner als die Standard-DTBs (vermutlich fehlt `__symbols__`, da nicht mit den Overlay-Flags gebaut) – für Overlays später relevant, für den Boot nicht **(unverifiziert)**.
6. **Trackpad:** udev-Ausblendregel und Kalibrierung sind Startwerte; Klick-Empfindlichkeit und Palm-Rejection müssen am Gerät justiert werden; haptisches Feedback unter Linux unbelegt.
7. **Lautsprecher:** Kernel-Limit ist in beiden Kerneln; die UCM-DMI-Zuordnung (`x1e80100.conf` → T14s-Profil) ist für Romulus13 nur indirekt belegt; ohne UCM laufen die Regler ungezähmt → Prüfbefehle 6.7 Punkt 4 **vor** dem ersten Ton.
8. **Fedora-Original als Referenz:** Thread 188069 („Live media fail to boot on Snapdragon aarch64 laptops", 2026) ist ungelesen – möglicherweise scheitert schon das Stock-Medium auf manchen Geräten; dann ist der Fedora-Original-Eintrag kein sauberer Referenzpunkt.
9. **Anaconda-Details** nur teilweise lokal geprüft: rsync-Excludes (main-Branch), `preserved_arguments` mit `=`-Werten, Standard-Eintrag nach Installation – Test 4 in 6.4 klärt es, sonst am Gerät `grubby --info=ALL` prüfen.
10. **dnf-Updates** im Zielsystem können ohne Exclude Fedoras Kernel zum Standard machen (4.4).
11. **Watchdog-Hypothese** (SBSA-GWDT) unbelegt; falls Resets zeitkonstant sind, `sbsa-gwdt` früh laden testen.
12. **Secure Boot/MOK**, **Kamera unter Kernel B**, **Fingerabdruck**, **NPU**, **Hibernate** (kein `disk` in `/sys/power/state`), **Lüfter** (SURFACE_FAN nicht gesetzt; EC-autonome Regelung angenommen **(unverifiziert)**): nicht adressiert.
13. **Quellen mit Budget-Lücken:** Xelef2000/azurefin, denislopt-ISO, murkurie-ELLX 7.2, Ubuntu-Discourse-Wiki (glathe #2174), horizontblau-Seite (liegt lokal als Text vor, im Plan nur über #1590-Zitate berücksichtigt), OptimisticPeach/orvitpng-Kommentare Sept. 2026 – beim nächsten Web-Budget zuerst azurefin und Thread 188069.
14. **Bau-Infrastruktur:** `Fedora-Stick-schreiben.ps1` fehlt; Kernel-B-Skript verlangt HEAD == Tag `sl7b`; Kernel-A-Patches uncommitted; `implantisomd5` fehlt auf dem Host; Phase-2-Skript nicht idempotent.

---

## 8 Quellen mit Datum

### Lokal (maßgeblich)
- `build/workflow/local-facts.md` – Build-Host, Kernel-Trees, Firmware, Lautsprecher, Boot-Mechanismus, Nachrecherche (12./13.09.2026).
- WSL-Zustandsprüfung 22.09.2026 (diese Sitzung): `/work/sl7/fedora/{phase1.log,phase2.log,iptsd-rpm.log}`, `rpm --root rootfs -q …`, `objdump -h` auf `rootfs/boot/vmlinuz-7.*` und `build/out/7.0.0-rc4-sl7-{2,3}/vmlinuz-7.0.0-rc4-sl7.stubble`, `dtc -I dtb -O dts` auf allen Romulus13-DTBs, `/usr/bin/ukify` (259.5) Zeilen 2412–2430, `readelf -n rootfs/usr/bin/iptsd`, `config-7.0.0-rc4-sl7` vs. `config-7.3.0-rc3-sl7b`, `git status/log` beider Kernel-Trees.
- `build/fedora/*.sh`, `grub-sl7.cfg`, `iptsd-sl7.spec`, `SL7-Hinweise.txt`, `out/inspect{-boot,-anaconda,-anaconda2,3}.txt` (22.09.2026).
- `docs/Fedora-ISO-Anleitung.md` (22.09.), `docs/SL7-Linux-Dossier.md`, `docs/Offene-Punkte.md`, `docs/Build-Rezept.md` (13.09.), `docs/quellen/` (horizontblau-Kopie, ls1590-comments-2026.json, nix1e, x1e-nixos, itslucas, touchscreen-i2c-thread).
- Fedora-KDE-Desktop-Live-44-1.7.aarch64.iso (Build 22.04.2026): xorriso-Reports, `dump.erofs`, `lsinitrd`, Rootfs-Inhalte (kernel-install-Plugins, 10_linux, blscfg/fdt/linux.mod-Strings, anaconda-Python, dracut-Module) – Korpus „iso-remaster", 22.09.2026.

### Fedora
- https://fedoraproject.org/wiki/Snapdragon_WoA_Laptop_Install (Rev. 775997, 2026; abgerufen 22.09.2026)
- https://fedoraproject.org/wiki/Changes/Automatic_DTB_selection_for_aarch64_EFI_systems (zuletzt 14.04.2026)
- https://gitlab.com/cki-project/kernel-ark/-/raw/os-build/redhat/kernel.spec.template und MR #4318 (18.01.2026)
- https://api.github.com/repos/rhboot/grub2/commits?sha=fedora-44 („Treat kernel-uki-dtbloader as default kernel", Bug 2463620; linux.c-Commits 04.–06.12.2025, gemerged 30.01.2026); https://raw.githubusercontent.com/rhboot/grub2/fedora-44/grub-core/loader/efi/linux.c; …/fedora-45/grub-core/commands/blscfg.c
- https://packages.fedoraproject.org/pkgs/kernel/kernel-core/ (22.09.2026); …/linux-firmware/qcom-firmware/fedora-44.html (10.03.2026); …/atheros-firmware/fedora-rawhide.html (16.09.2026); https://dl.fedoraproject.org/pub/fedora/linux/{releases,updates}/44/… (22.09.2026)
- https://gitlab.com/redhat/centos-stream/rpms/grub2/-/raw/c10s/20-grub.install; https://raw.githubusercontent.com/dracut-ng/dracut-ng/main/install.d/50-dracut.install (22.09.2026)
- https://raw.githubusercontent.com/systemd/systemd/main/man/{systemd-stub,ukify,kernel-install}.xml, NEWS, src/boot/hwids/aa64 (22.09.2026)
- https://cdn.jsdelivr.net/gh/canonical/stubble@main/README.md und hwids/json/x1e80100-microsoft-romulus13.json (hinzugefügt 19.08.2025; Repo-Stand 18.09.2026)
- https://github.com/rhinstaller/anaconda/blob/main/pyanaconda/modules/payloads/payload/live_image/installation.py (main, 22.09.2026)
- https://discussion.fedoraproject.org/t/microsoft-surface-laptop-7-fedora-41-ws-install-arm64/144552 (13.02.–16.04.2025); …/t/live-media-fail-to-boot-on-snapdragon-aarch64-laptops/188069 (2026, ungelesen); …/t/aarch64-fedora-44-and-microsoft-surface/195494 (02.07.2026); …/t/snapdragon-x-elite-fedora-42-system-bring-up-and-looking-for-collaborators-or-sigs/153631 (bis 09/2025)
- https://www.phoronix.com/news/Fedora-44-Approves-DTB-WOA, …/Fedora-44-ARM-OOTB (2026); https://ostechnix.com/fedora-linux-44-released/ (04/2026)
- https://raw.githubusercontent.com/rpm-software-management/mock/main/docs/Feature-forcearch.md (22.09.2026)

### Kernel, Paketierung, Boot
- https://raw.githubusercontent.com/torvalds/linux/master/scripts/package/kernel.spec, scripts/Makefile.package, arch/arm64/Makefile, drivers/firmware/efi/Kconfig, libstub/zboot-header.S, arch/arm64/boot/dts/qcom/{Makefile,x1e80100-microsoft-romulus13.dts,x1e80100-microsoft-romulus.dtsi} (7.3-rc4, 22.09.2026)
- https://git.savannah.gnu.org/cgit/grub.git/plain/grub-core/loader/efi/linux.c (22.09.2026); https://www.gnu.org/software/grub/manual/grub/html_node/blscfg.html (2.14)
- https://github.com/coreos/fedora-coreos-tracker/issues/1441 (zboot/„invalid magic number")
- https://osinside.github.io/kiwi/building_images/build_live_iso.html; https://weldr.io/lorax/{livemedia-creator,mkksiso}.html (22.09.2026)
- https://launchpad.net/~ubuntu-concept/+archive/ubuntu/x1e/+packages (7.3.0-15.15 17.09.2026, 7.2.0-18.18 09.09.2026)

### Community Surface Laptop 7
- https://github.com/linux-surface/linux-surface/issues/1590 (Kommentare April–21.09.2026 via API; lokale Kopie `docs/quellen/ls1590-comments-2026.json`)
- https://github.com/ItsLucas/surface-laptop-7-ubuntu-kernel (README, PROVENANCE.md, Releases r15.1 19.09.2026; lokale Kopie `gits/ItsLucas_…`)
- https://ratatoskr.run/lkml/2026/09/17522699 und …/linux-devicetree/2026/09/17522701/t (fQwQf, 07.09.2026); …/linux-arm-msm/2026/06/17091838/t (GENI-QSPI, 05.06.–01.07.2026); …/linux-devicetree/2026/06/17106641/t (spi-hid v4, 09.06.2026); …/linux-clk/2026/04/8272350/t (dispcc, 04/2026); …/u-boot/2026/07/17213911/t (Watchdog, 07/2026); https://patchew.org/linux/20250212-x1e80100-add-watchdog-v2-1-a73897f0dad5@linaro.org/ (02/2025); https://lkml.iu.edu/2512.3/00284.html (APSS-WDT EL2, 12/2025)
- https://api.github.com/repos/bryce-hoehn/linux-surface-laptop-7/{issues,pulls,branches,forks} (22.09.2026); https://github.com/bryce-hoehn/linux-surface-laptop-7 (Push 06.08.2026)
- https://api.github.com/repos/ProgrammerIn-wonderland/ELLX-Kernel/commits (HEAD 14.05.2026); https://public.hgci.org/software/ELLX/ (Listing 11.06.2026); https://github.com/murkurie/ELLX-Kernel/releases/tag/v7.2.0-sl7-13.8 (18.09.2026, unverifiziert)
- https://bugs.launchpad.net/ubuntu-concept/+bug/2084951 (Kommentare #10–#40, Okt.–Nov. 2024; inaktiv seit 21.07.2025)
- https://discourse.ubuntu.com/t/ubuntu-concept-snapdragon-x-elite/48800/2174 (09.09.2026); …/t/boot-fails-from-usb-drive-on-snapdragon-x-elite-laptop/58906 (11.04.2025)
- https://gist.github.com/cicorias/6da75542f9e2b4a7b6f58a61ba3979d6 (09.09.2026)
- https://horizontblau.de/linux/surface-laptop-7-linux.html (Stand 08/2026; lokale Kopie)
- https://github.com/orvitpng/nix1e (letzter Commit 17.06.2026); https://github.com/Xelef2000/azurefin (unverifiziert); https://github.com/denislopt/omarchy-surface-laptop7/releases/tag/v2026.09.16-rc1 (unverifiziert)

### Trackpad / iptsd
- https://github.com/alex-lentz/iptsd (README; Commit 3663e96 16.07.2026; lokaler Klon `/work/sl7/fedora/rootfs/root/sl7/iptsd`)
- https://github.com/linux-surface/linux-surface/discussions/2100 (03.05.–17.07.2026)
- https://github.com/linux-surface/iptsd/releases (v3.1.0 29.12.2023); …/master/{meson.build,src/meson.build,.github/scripts/pkg-fedora.sh} (22.09.2026)
- https://github.com/bryce-hoehn/linux-surface-laptop-7 (iptsd-Abschnitt, 06.08.2026)
- https://rsadowski.de/posts/2024-05-14-branch-target-identification/; https://github.com/systemd/systemd/issues/17368 (BTI-Hintergrund)
