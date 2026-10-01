# Projekt Linux – Surface Laptop 7 (13,8", Snapdragon X Elite / X1E80100 "Romulus13")

Ziel: 100 % Linux auf dem Surface Laptop 7, eigener Kernel, alles optimiert.
Gebaut wird auf Martins MSI-PC in WSL2 (Ubuntu 26.04, Cross-Compile); das Surface wird nur zum Installieren gebraucht.

**Stand 22.09.2026 – Fedora-Track (aktuell):** Der Ubuntu-Weg (Kernel nachträglich in ein installiertes System) endete am
14.09. im Boot-Loop. Seitdem entsteht ein **eigenes Fedora-KDE-Live-ISO (aarch64)** mit zwei eigenen Kerneln
(B = Ubuntu 7.3 + ItsLucas-Patches, A = ELLX 7.0), iptsd-Fork mit haptischem Klick, Firmware, MAC-Fix und
allen Konfigurationen – bootfähig vom Stick und per Anaconda installierbar. Alles dazu:
[docs/Fedora-ISO-Anleitung.md](docs/Fedora-ISO-Anleitung.md), Skripte in `build/fedora/`, Ergebnisse in
`build/fedora/out/` (ISO unter `out/iso/`), Stick schreiben mit `Fedora-Stick-schreiben.ps1`.

**Stand 13.09.2026 (Ubuntu-Track, archiviert):** Kernel `7.0.0-rc4-sl7` in drei Paket-Revisionen gebaut und im arm64-Chroot getestet,
Firmware-Paket aus dem aktuellen Microsoft-Treiberpaket erzeugt, Ziel-Installer geschrieben und im Probelauf geprüft.

## Download

ISO als eine Datei (4,8 GB): [MEGA](https://mega.nz/file/YE8RibKT#KTTHuW7HEy8sEkO9AQoULRtfNSs7PrhJeWbU0vAri24), SHA256 `3a16e0d6108be68485f1de2043c64de70abadbefd9a5c734b1df7eb9dc5725f2`. Alternativ in drei Teilen im GitHub-Release.

## Womit anfangen

| Zuerst lesen | Wofür |
|---|---|
| [docs/SL7-Linux-Dossier.md](docs/SL7-Linux-Dossier.md) | Die Master-Referenz: Hardware, Kernel-Entscheidung, Firmware, Distro, Komponenten-Status, Optimierung, Quellen |
| [docs/Build-Rezept.md](docs/Build-Rezept.md) | Nur die Befehle in Reihenfolge: bauen, Stick vorbereiten, installieren, nach dem Boot kontrollieren |
| [docs/Offene-Punkte.md](docs/Offene-Punkte.md) | Risiken, Experimentelles, was auf dem Gerät zuerst geprüft werden muss |

## Ordner

| Ordner | Inhalt |
|---|---|
| `docs/` | die drei Dokumente oben, `dts/` (Romulus-Device-Tree-Quellen), `quellen/` (Rohdaten der Recherche), `archiv/` (abgelöster Entwurf) |
| `build/fedora/` | **Fedora-Track:** `wsl-fedora-*.sh` (ISO-Analyse, Rootfs-Kopie, Chroot, Phase 1–4), Kernel-Skripte (`wsl-build-kernel-fedora.sh`, `wsl-*-kernel-73*.sh`, `wsl-dtb-i2cts-*.sh`), `iptsd-sl7.spec`, `grub-sl7.cfg`, `SL7-Hinweise.txt`; `out/` mit Kernel-RPMs, DTBs, iptsd-RPM, Inspektions-Protokollen und `iso/` |
| `Fedora-Stick-schreiben.ps1` | schreibt das Fedora-ISO roh (dd-Modus) auf einen USB-Stick, optional mit Rücklesen |
| `build/wsl-*.sh` | WSL-Skripte (Ubuntu-Track): Toolchain, Klonen, Patchen, Build, stubble-Image, Firmware, Chroot-Tests, Verifikation |
| `build/inspect/` | Diagnose- und Prüfskripte (einmalige Analysen, Syntax- und Shellcheck-Läufe, Installer-Probelauf) |
| `build/patches-upstream/` | `sl7-tree-full.diff` (kanonischer Patch-Stand) plus Einzelpatches zur Herkunftsdokumentation |
| `build/out/7.0.0-rc4-sl7-N/` | fertige Kernel-Pakete, stubble-Image, DTBs, Config – höchstes N ist die neueste Revision |
| `build/out/` | alles, was auf den Stick kommt: `SL7-INSTALLIEREN.sh` (Dach-Skript), `sl7-install-on-laptop.sh`, `sl7-check.sh`, `sl7-optimize.sh`, `START-HIER.txt`, Firmware-Paket, iptsd, MAC-Fix, Resume-Hooks |
| `Stick-vorbereiten.ps1` | befüllt den USB-Stick automatisch (Windows, PowerShell) |
| `iso/` | `ubuntu-26.04.1-desktop-arm64.iso`, Prüfsumme verifiziert |
| `hardware/SL7-Hardware-Dump.ps1` | auf dem Surface unter Windows ausführen, liefert eine komplette Hardware-Inventur als ZIP |
| `gits/` | geklonte Community-Repos |

## Kurzablauf Fedora-Track (aktuell)

1. Auf dem PC: `Fedora-Stick-schreiben.ps1` ausführen (als Administrator; schreibt `build/fedora/out/iso/Fedora-KDE-Live-44-SL7-*.iso` roh auf den Stick, `-Pruefen` liest zurück) **oder** das ISO einfach auf den Ventoy-Stick kopieren (ab Ausgabe 20260930 Ventoy-tauglich, liegt schon auf `D:\`; im Ventoy-Menü „Boot in normal mode").
2. Am Surface: Secure Boot im UEFI auf „None“, Stick am **USB-A**-Port, beim Einschalten Lautstärke-Leiser halten.
3. Im GRUB-Menü den ersten Eintrag lassen (Kernel B, USB-C-sicher) – bei Problemen die Diagnose-Einträge, Kernel A oder „Fedora-Original“.
4. Im Live-System prüfen (Reihenfolge wichtig, erst dann Ton): `amixer -c0 contents | grep -A3 'PA Volume'` (platform_max 6),
   `systemctl status 'iptsd@*'`, `sl7-mac all`, `libinput list-devices`, `cat /sys/firmware/devicetree/base/model`.
5. Installieren mit „Auf Festplatte installieren“ (Anaconda); nach dem ersten Start `/var/lib/sl7/postinstall.log` und `sudo grubby --info=ALL` ansehen.

## Kurzablauf Ubuntu-Track (archiviert, endete im Boot-Loop)

1. Auf dem PC: `Stick-vorbereiten.ps1` ausführen. Kopiert alles Nötige als Ordner `SL7-Installation` auf den USB-Stick.
2. Auf dem Surface (Ubuntu ist schon installiert), Terminal öffnen und starten:

   ```
   sudo bash SL7-INSTALLIEREN.sh
   ```

   Das Skript macht Selbsttest, Probelauf, fragt nach und installiert dann alles.
3. Neu starten, im Bootmenü den Kernel mit der Endung `-sl7` wählen.
4. Bericht abrufen: `sudo bash sl7-check.sh` — sagt Punkt für Punkt, was läuft.
5. Optional danach: `sudo bash sl7-optimize.sh` für Speicher, Stromsparen und Grafik.

Ohne Netz auf dem Surface ist das kein Problem: Es wird nichts heruntergeladen.

## Warnung: Lautsprecher

Linux hat für den Snapdragon X Elite **keinen aktiven Lautsprecherschutz**. In der Community sind dadurch
Lautsprecher dauerhaft zerstört worden. Unser Kernel enthält ab Revision 2 Ubuntus Volume-Limit-Patch.
Trotzdem gilt: Lautstärke höchstens 70 %, niemals das PipeWire-Profil "Pro Audio" wählen.
Eine Modul-Blacklist ist **kein** sanfter Teilschutz, sie legt die ganze Soundkarte still.
Einzelheiten in [docs/Offene-Punkte.md](docs/Offene-Punkte.md), Abschnitt 1.1.
