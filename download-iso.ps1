# Downloads the Surface Laptop 7 Fedora ISO from the GitHub release, joins the parts and verifies the SHA256.
# Usage (PowerShell):  irm https://raw.githubusercontent.com/1Martin11/surface-laptop-7-fedora/main/download-iso.ps1 | iex
$ErrorActionPreference = 'Stop'
$base = 'https://github.com/1Martin11/surface-laptop-7-fedora/releases/download/v2026.09.30'
$iso  = 'Fedora-KDE-Live-44-SL7-20260930.iso'
$sha  = '3a16e0d6108be68485f1de2043c64de70abadbefd9a5c734b1df7eb9dc5725f2'
$parts = 0..2 | ForEach-Object { "$iso.part-$_" }
foreach ($p in $parts) { if (-not (Test-Path $p)) { Write-Host "Downloading $p ..."; Invoke-WebRequest -Uri "$base/$p" -OutFile $p } }
Write-Host "Joining ..."; $out = [IO.File]::Create($iso)
foreach ($p in $parts) { $in = [IO.File]::OpenRead($p); $in.CopyTo($out); $in.Close() }
$out.Close(); Remove-Item $parts
$h = (Get-FileHash $iso -Algorithm SHA256).Hash.ToLower()
if ($h -eq $sha) { Write-Host "OK: $iso verified (SHA256 matches)." } else { Write-Host "ERROR: checksum mismatch ($h)"; exit 1 }
