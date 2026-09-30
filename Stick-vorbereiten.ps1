<#
  Stick-vorbereiten.ps1
  Kopiert alles, was auf dem Surface gebraucht wird, auf einen USB-Stick.

  Aufruf auf dem PC (PowerShell):
      powershell -ExecutionPolicy Bypass -File .\Stick-vorbereiten.ps1
  Oder mit fest gewaehltem Laufwerk:
      powershell -ExecutionPolicy Bypass -File .\Stick-vorbereiten.ps1 -Laufwerk E:
  Mit ISO (fuer einen Ventoy-Stick, auf dem noch kein Ubuntu liegt):
      powershell -ExecutionPolicy Bypass -File .\Stick-vorbereiten.ps1 -MitIso

  Der Stick wird NICHT formatiert. Es werden nur Dateien hinzugefuegt.
#>
param(
    [string]$Laufwerk = "",
    [switch]$MitIso
)

$ErrorActionPreference = 'Stop'
$Projekt = Split-Path -Parent $MyInvocation.MyCommand.Path
$Quelle  = Join-Path $Projekt 'build\out'
$Iso     = Join-Path $Projekt 'iso\ubuntu-26.04.1-desktop-arm64.iso'

Write-Host ""
Write-Host "=== Surface Laptop 7: Stick vorbereiten ===" -ForegroundColor Cyan

if (-not (Test-Path $Quelle)) { Write-Host "Quellordner fehlt: $Quelle" -ForegroundColor Red; exit 1 }

# ---- Laufwerk waehlen -------------------------------------------------------
if (-not $Laufwerk) {
    $sticks = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter }
    if (-not $sticks) { Write-Host "Kein USB-Stick gefunden. Stick anstecken oder -Laufwerk E: angeben." -ForegroundColor Red; exit 1 }
    Write-Host ""
    Write-Host "Gefundene Wechseldatentraeger:"
    $i = 0
    $liste = @($sticks)
    foreach ($s in $liste) {
        $frei = [math]::Round($s.SizeRemaining / 1GB, 1)
        $ges  = [math]::Round($s.Size / 1GB, 1)
        Write-Host ("  [{0}] {1}:  {2}  ({3} GB frei von {4} GB, {5})" -f $i, $s.DriveLetter, $s.FileSystemLabel, $frei, $ges, $s.FileSystem)
        $i++
    }
    Write-Host ""
    $wahl = Read-Host "Nummer eingeben (Abbruch mit Enter)"
    if ($wahl -eq "") { Write-Host "Abgebrochen."; exit 0 }
    $ziel = $liste[[int]$wahl]
    $Laufwerk = "$($ziel.DriveLetter):"
}
$Laufwerk = $Laufwerk.TrimEnd('\')
if (-not (Test-Path $Laufwerk)) { Write-Host "Laufwerk $Laufwerk nicht gefunden." -ForegroundColor Red; exit 1 }

# ---- Platzbedarf pruefen ----------------------------------------------------
$brauchtMB = [math]::Round(((Get-ChildItem $Quelle -Recurse -File | Measure-Object Length -Sum).Sum / 1MB), 0)
if ($MitIso) {
    if (Test-Path $Iso) { $brauchtMB += [math]::Round((Get-Item $Iso).Length / 1MB, 0) }
    else { Write-Host "ISO nicht gefunden: $Iso" -ForegroundColor Yellow; $MitIso = $false }
}
$vol = Get-Volume -DriveLetter $Laufwerk.TrimEnd(':')
$freiMB = [math]::Round($vol.SizeRemaining / 1MB, 0)
Write-Host ""
Write-Host ("Ziel:      {0}  ({1})" -f $Laufwerk, $vol.FileSystemLabel)
Write-Host ("Benoetigt: {0} MB    Frei: {1} MB" -f $brauchtMB, $freiMB)
if ($freiMB -lt $brauchtMB) { Write-Host "Zu wenig Platz auf dem Stick." -ForegroundColor Red; exit 1 }

# ---- Kopieren ---------------------------------------------------------------
$ZielOrdner = Join-Path $Laufwerk 'SL7-Installation'
Write-Host ""
Write-Host "Kopiere nach $ZielOrdner ..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $ZielOrdner | Out-Null

# robocopy: /MIR spiegelt, /NFL /NDL ruhig, /R:2 wenig Wiederholungen
$rc = Start-Process robocopy -ArgumentList @("`"$Quelle`"", "`"$ZielOrdner`"", "/E", "/R:2", "/W:2", "/NFL", "/NDL", "/NJH", "/NP") -Wait -PassThru -NoNewWindow
if ($rc.ExitCode -ge 8) { Write-Host "Kopieren fehlgeschlagen (robocopy $($rc.ExitCode))" -ForegroundColor Red; exit 1 }

# Dokumente mitnehmen, damit man auf dem Laptop nachlesen kann
$Docs = Join-Path $ZielOrdner 'docs'
New-Item -ItemType Directory -Force -Path $Docs | Out-Null
Get-ChildItem (Join-Path $Projekt 'docs') -Filter *.md -File | Copy-Item -Destination $Docs -Force

if ($MitIso) {
    Write-Host "Kopiere ISO (3,9 GB, das dauert) ..." -ForegroundColor Cyan
    Copy-Item $Iso -Destination $Laufwerk -Force
}

# ---- Kontrolle --------------------------------------------------------------
Write-Host ""
Write-Host "=== Kontrolle ===" -ForegroundColor Cyan
$fehlt = @()
foreach ($p in @('SL7-INSTALLIEREN.sh','sl7-install-on-laptop.sh','sl7-check.sh','sl7-optimize.sh','START-HIER.txt')) {
    if (Test-Path (Join-Path $ZielOrdner $p)) { Write-Host "  ok    $p" -ForegroundColor Green } else { Write-Host "  FEHLT $p" -ForegroundColor Red; $fehlt += $p }
}
$kernel = Get-ChildItem $ZielOrdner -Directory -Filter '7.0.0-rc4-sl7-*' | Sort-Object Name | Select-Object -Last 1
if ($kernel) { Write-Host "  ok    Kernel: $($kernel.Name)" -ForegroundColor Green } else { Write-Host "  FEHLT Kernel-Ordner" -ForegroundColor Red; $fehlt += 'Kernel' }
$fw = Get-ChildItem $ZielOrdner -Filter 'sl7-firmware-msi-*.tar.xz' | Select-Object -First 1
if ($fw) { Write-Host "  ok    Firmware: $($fw.Name)" -ForegroundColor Green } else { Write-Host "  FEHLT Firmware-Paket" -ForegroundColor Red; $fehlt += 'Firmware' }

Write-Host ""
if ($fehlt.Count -eq 0) {
    Write-Host "Stick ist fertig." -ForegroundColor Green
    Write-Host ""
    Write-Host "Auf dem Surface im Terminal:" -ForegroundColor White
    Write-Host "    cd /media/`$USER/*/SL7-Installation   (oder wohin du den Ordner kopierst)"
    Write-Host "    sudo bash SL7-INSTALLIEREN.sh"
    Write-Host ""
    Write-Host "Kurzanleitung steht in START-HIER.txt auf dem Stick."
} else {
    Write-Host "Es fehlen noch: $($fehlt -join ', ')" -ForegroundColor Red
}
