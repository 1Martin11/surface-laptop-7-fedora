<#
  Fedora-Stick-schreiben.ps1
  Schreibt das SL7-Fedora-Live-ISO (Hybrid-ISO, GPT) 1:1 ("dd-Modus") auf einen USB-Stick.
  Das ist der einzige richtige Weg fuer Fedora-Live-ISOs (kein Ventoy noetig, kein Formatieren per Hand).

  Aufruf (PowerShell als Administrator, sonst wird neu gestartet):
      powershell -ExecutionPolicy Bypass -File .\Fedora-Stick-schreiben.ps1
  Optional:  -Iso "Pfad\zur.iso"   -Disk 2   -Pruefen (liest den Stick nach dem Schreiben zurueck und vergleicht die Pruefsumme)

  ACHTUNG: Der gewaehlte Datentraeger wird komplett geloescht.
#>
param(
    [string]$Iso = "",
    [int]$Disk = -1,
    [switch]$Pruefen
)
$ErrorActionPreference = 'Stop'
$Projekt = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---- Administrator? ----------------------------------------------------------
$istAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $istAdmin) {
    Write-Host "Starte neu mit Administratorrechten..." -ForegroundColor Yellow
    $args2 = "-ExecutionPolicy Bypass -NoExit -File `"$($MyInvocation.MyCommand.Path)`""
    if ($Iso) { $args2 += " -Iso `"$Iso`"" }; if ($Disk -ge 0) { $args2 += " -Disk $Disk" }; if ($Pruefen) { $args2 += " -Pruefen" }
    Start-Process powershell -Verb RunAs -ArgumentList $args2
    exit 0
}

Write-Host ""; Write-Host "=== Surface Laptop 7: Fedora-Live-Stick schreiben ===" -ForegroundColor Cyan

# ---- ISO waehlen ---------------------------------------------------------------
if (-not $Iso) {
    $kand = Get-ChildItem (Join-Path $Projekt 'build\fedora\out\iso') -Filter 'Fedora-KDE-Live-44-SL7-*.iso' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if (-not $kand) { Write-Host "Kein ISO unter build\fedora\out\iso gefunden. -Iso angeben." -ForegroundColor Red; exit 1 }
    $Iso = $kand[0].FullName
}
if (-not (Test-Path $Iso)) { Write-Host "ISO nicht gefunden: $Iso" -ForegroundColor Red; exit 1 }
$isoInfo = Get-Item $Iso
$isoGB = [math]::Round($isoInfo.Length / 1GB, 2)
Write-Host ("ISO: {0}  ({1} GB)" -f $isoInfo.FullName, $isoGB)
$shaDatei = "$Iso.sha256"
if (Test-Path $shaDatei) {
    $soll = ((Get-Content $shaDatei) -split '\s+')[0].ToLower()
    Write-Host "Pruefe ISO-Pruefsumme..." -NoNewline
    $ist = (Get-FileHash -Algorithm SHA256 $Iso).Hash.ToLower()
    if ($ist -ne $soll) { Write-Host " FEHLER: ISO ist beschaedigt (SHA256 passt nicht)." -ForegroundColor Red; exit 1 }
    Write-Host " ok" -ForegroundColor Green
}

# ---- Datentraeger waehlen ------------------------------------------------------
$disks = Get-Disk | Where-Object { $_.BusType -in @('USB','SD','MMC') } | Sort-Object Number
if (-not $disks) { Write-Host "Kein USB-Datentraeger gefunden. Stick anstecken." -ForegroundColor Red; exit 1 }
Write-Host ""; Write-Host "USB-Datentraeger:"
foreach ($d in $disks) {
    $vols = (Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue | Get-Volume -ErrorAction SilentlyContinue | Where-Object DriveLetter | ForEach-Object { "$($_.DriveLetter):" }) -join ' '
    Write-Host ("  Disk {0}: {1}  {2} GB  {3}  {4}" -f $d.Number, $d.FriendlyName, [math]::Round($d.Size/1GB,1), $d.BusType, $vols)
}
if ($Disk -lt 0) {
    $eing = Read-Host "Nummer des Sticks (Disk N) eingeben"
    if ($eing -notmatch '^\d+$') { Write-Host "Abbruch." ; exit 1 }
    $Disk = [int]$eing
}
$ziel = $disks | Where-Object Number -eq $Disk
if (-not $ziel) { Write-Host "Disk $Disk ist kein USB-Datentraeger - Abbruch (Sicherheit)." -ForegroundColor Red; exit 1 }
if ($ziel.Size -lt $isoInfo.Length) { Write-Host "Stick zu klein." -ForegroundColor Red; exit 1 }
Write-Host ""
Write-Host ("ALLE DATEN auf Disk {0} ({1}, {2} GB) werden geloescht!" -f $ziel.Number, $ziel.FriendlyName, [math]::Round($ziel.Size/1GB,1)) -ForegroundColor Yellow
$best = Read-Host "Zum Fortfahren JA eingeben"
if ($best -cne 'JA') { Write-Host "Abbruch."; exit 1 }

# ---- Stick leeren --------------------------------------------------------------
Write-Host "Loesche Partitionen..." -NoNewline
Get-Partition -DiskNumber $Disk -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-PartitionAccessPath -DiskNumber $Disk -PartitionNumber $_.PartitionNumber -AccessPath "$($_.DriveLetter):" -ErrorAction SilentlyContinue } catch {} }
Clear-Disk -Number $Disk -RemoveData -RemoveOEM -Confirm:$false -ErrorAction SilentlyContinue
Set-Disk -Number $Disk -IsReadOnly $false -ErrorAction SilentlyContinue
Set-Disk -Number $Disk -IsOffline $true -ErrorAction SilentlyContinue
Write-Host " ok" -ForegroundColor Green

# ---- Rohes Schreiben -----------------------------------------------------------
$pfad = "\\.\PhysicalDrive$Disk"
$puffer = New-Object byte[] (4MB)
$sha = [System.Security.Cryptography.SHA256]::Create()
$quelle = [System.IO.File]::OpenRead($Iso)
$zielFs = New-Object System.IO.FileStream($pfad, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, 4MB, [System.IO.FileOptions]::WriteThrough)
$gesamt = $quelle.Length; $geschrieben = 0L; $start = Get-Date
Write-Host "Schreibe $isoGB GB auf $pfad ..."
try {
    while (($n = $quelle.Read($puffer, 0, $puffer.Length)) -gt 0) {
        # Sektorvielfaches (512) - das ISO ist immer ein Vielfaches von 2048, nur der letzte Block koennte kuerzer sein
        if ($n % 512 -ne 0) { $rest = 512 - ($n % 512); [Array]::Clear($puffer, $n, $rest); $n += $rest }
        $zielFs.Write($puffer, 0, $n); $geschrieben += $n
        $null = $sha.TransformBlock($puffer, 0, $n, $null, 0)
        $proz = [math]::Round($geschrieben * 100 / $gesamt); $mbs = [math]::Round($geschrieben / 1MB / ((Get-Date) - $start).TotalSeconds, 1)
        Write-Progress -Activity "Schreibe ISO" -Status ("{0} %  ({1} MB/s)" -f $proz, $mbs) -PercentComplete $proz
    }
    $zielFs.Flush($true)
} finally { $zielFs.Dispose(); $quelle.Dispose() }
$null = $sha.TransformFinalBlock($puffer, 0, 0)
$dauer = [math]::Round(((Get-Date) - $start).TotalSeconds)
Write-Progress -Activity "Schreibe ISO" -Completed
Write-Host ("Geschrieben: {0} Bytes in {1} s" -f $geschrieben, $dauer) -ForegroundColor Green

# ---- Optional zuruecklesen -----------------------------------------------------
if ($Pruefen) {
    Write-Host "Lese Stick zurueck und vergleiche SHA256 ..."
    $sha2 = [System.Security.Cryptography.SHA256]::Create()
    $lese = New-Object System.IO.FileStream($pfad, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None, 4MB)
    $rest = $geschrieben; $gel = 0L
    try {
        while ($rest -gt 0) {
            $n = $lese.Read($puffer, 0, [int][math]::Min($puffer.Length, $rest)); if ($n -le 0) { break }
            $null = $sha2.TransformBlock($puffer, 0, $n, $null, 0); $rest -= $n; $gel += $n
            Write-Progress -Activity "Pruefe Stick" -PercentComplete ([math]::Round($gel * 100 / $geschrieben))
        }
    } finally { $lese.Dispose() }
    $null = $sha2.TransformFinalBlock($puffer, 0, 0); Write-Progress -Activity "Pruefe Stick" -Completed
    $h1 = [BitConverter]::ToString($sha.Hash) -replace '-',''; $h2 = [BitConverter]::ToString($sha2.Hash) -replace '-',''
    if ($h1 -eq $h2) { Write-Host "Pruefung ok - Stick entspricht dem ISO." -ForegroundColor Green } else { Write-Host "FEHLER: Stick weicht vom ISO ab (defekter Stick?)." -ForegroundColor Red }
}
Set-Disk -Number $Disk -IsOffline $false -ErrorAction SilentlyContinue
Update-HostStorageCache
Write-Host ""
Write-Host "Fertig. Stick sicher entfernen, am Surface Laptop 7 einstecken (USB-A bevorzugt), Secure Boot im UEFI auf 'None'," -ForegroundColor Cyan
Write-Host "beim Start Lautstaerke-Leiser gedrueckt halten (Boot vom USB) und im Menue 'SL7: ... Kernel B' waehlen." -ForegroundColor Cyan
Write-Host "Windows meldet evtl. 'Datentraeger formatieren?' - das ist normal (Linux-Dateisystem), auf Abbrechen klicken." -ForegroundColor DarkGray
