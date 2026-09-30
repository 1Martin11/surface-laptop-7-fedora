<#
  SL7-Hardware-Dump.ps1
  Hardware-Inventur des Surface Laptop 7 (ARM, Snapdragon X Elite) unter Windows 11.
  Sammelt alles, was fuer die Linux-Portierung wichtig ist: PnP-Geraete mit Hardware-IDs,
  Treiber, ACPI-Tabellen, EDID, Firmware-Blobs aus dem DriverStore, MAC-Adressen, Partitionen,
  Batterie, Schlafzustaende, UEFI/Secure-Boot-Status.

  Ausfuehren AUF DEM SURFACE (PowerShell, am besten "Als Administrator"):
      powershell -ExecutionPolicy Bypass -File .\SL7-Hardware-Dump.ps1
  Dauer: ca. 2-4 Minuten (msinfo32 + dxdiag brauchen am laengsten).
  Ergebnis: Ordner + ZIP auf dem Desktop -> ZIP in den Projektordner "Projekt Linux ARM\hardware" kopieren.
  Hinweis: Der Dump enthaelt Seriennummern und MAC-Adressen (bleibt lokal).
#>
param([string]$OutDir = "$env:USERPROFILE\Desktop\SL7-Hardware-Dump")

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$acpiDir = Join-Path $OutDir 'acpi';                  New-Item -ItemType Directory -Force -Path $acpiDir | Out-Null
$edidDir = Join-Path $OutDir 'edid';                  New-Item -ItemType Directory -Force -Path $edidDir | Out-Null
$fwDir   = Join-Path $OutDir 'firmware-from-windows'; New-Item -ItemType Directory -Force -Path $fwDir | Out-Null
$infDir  = Join-Path $OutDir 'inf';                   New-Item -ItemType Directory -Force -Path $infDir | Out-Null

function Save([string]$name, $data) {
    try { $data | Out-File -FilePath (Join-Path $OutDir $name) -Encoding utf8 -Width 8192 } catch { Write-Warning "Save $name : $_" }
}
function Step([string]$msg) { Write-Host ("[*] " + $msg) -ForegroundColor Cyan }
function Run([string]$name, [scriptblock]$sb) {
    Step $name
    try { Save $name (& $sb | Out-String) } catch { Save $name ("FEHLER: " + $_) }
}

"Dump erstellt: $(Get-Date -Format s)`r`nAdmin: $isAdmin`r`nComputer: $env:COMPUTERNAME`r`nArch: $env:PROCESSOR_ARCHITECTURE" | Out-File (Join-Path $OutDir '00-INFO.txt') -Encoding utf8
if (-not $isAdmin) { Write-Warning "Nicht als Administrator: Secure-Boot-, TPM-, BitLocker- und BCD-Infos werden fehlen (Rest laeuft)." }

# ---------------- System / SMBIOS ----------------
Run 'system-computerinfo.txt'  { Get-ComputerInfo | Format-List * }
Run 'smbios.txt' {
    '=== Win32_ComputerSystem';        Get-CimInstance Win32_ComputerSystem | Format-List *
    '=== Win32_ComputerSystemProduct'; Get-CimInstance Win32_ComputerSystemProduct | Format-List *
    '=== Win32_BaseBoard';             Get-CimInstance Win32_BaseBoard | Format-List *
    '=== Win32_BIOS';                  Get-CimInstance Win32_BIOS | Format-List *
    '=== Registry BIOS';               Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS' | Format-List *
}
Run 'cpu.txt'    { Get-CimInstance Win32_Processor | Format-List *; '=== CentralProcessor\0'; Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' | Format-List * }
Run 'memory.txt' { Get-CimInstance Win32_PhysicalMemory | Format-List *; Get-CimInstance Win32_PhysicalMemoryArray | Format-List * }
Run 'os.txt'     { Get-CimInstance Win32_OperatingSystem | Format-List *; cmd /c ver }

# ---------------- PnP-Geraete mit Hardware-IDs ----------------
Step 'PnP-Geraete (CSV)'
Get-PnpDevice | Sort-Object Class, FriendlyName | Select-Object Class, FriendlyName, Status, Present, InstanceId, Service |
    Export-Csv -Path (Join-Path $OutDir 'pnp-devices.csv') -NoTypeInformation -Encoding UTF8

Step 'PnP-Geraete Detail (alle wichtigen Properties, dauert etwas)'
$keys = 'DEVPKEY_Device_HardwareIds','DEVPKEY_Device_CompatibleIds','DEVPKEY_Device_Service','DEVPKEY_Device_Driver',
        'DEVPKEY_Device_DriverVersion','DEVPKEY_Device_DriverProvider','DEVPKEY_Device_DriverInfPath','DEVPKEY_Device_DriverDate',
        'DEVPKEY_Device_LocationInfo','DEVPKEY_Device_LocationPaths','DEVPKEY_Device_Parent','DEVPKEY_Device_BusReportedDeviceDesc',
        'DEVPKEY_Device_Manufacturer','DEVPKEY_Device_EnumeratorName','DEVPKEY_Device_PDOName','DEVPKEY_Device_Address','DEVPKEY_Device_BusNumber','DEVPKEY_Device_ContainerId'
$sb = New-Object System.Text.StringBuilder
foreach ($d in (Get-PnpDevice -PresentOnly | Sort-Object Class, FriendlyName)) {
    [void]$sb.AppendLine("=== [$($d.Class)] $($d.FriendlyName) | $($d.Status)")
    [void]$sb.AppendLine("    InstanceId: $($d.InstanceId)")
    $props = Get-PnpDeviceProperty -InstanceId $d.InstanceId -ErrorAction SilentlyContinue
    foreach ($p in $props) {
        if ($keys -contains $p.KeyName) {
            $val = ($p.Data | ForEach-Object { "$_" }) -join ' ; '
            [void]$sb.AppendLine("    $($p.KeyName.Replace('DEVPKEY_Device_','')): $val")
        }
    }
}
Save 'pnp-devices-detail.txt' $sb.ToString()

# Wichtige Geraeteklassen: ALLE Properties (fuer Touch, Kamera, Audio, WLAN, BT, Display, EC)
Step 'Schluesselgeraete: alle Properties'
$focusClasses = 'HIDClass','Camera','Image','MEDIA','AudioEndpoint','Net','Bluetooth','Display','Monitor','Battery','System','Firmware','Sensor','Biometric','SCSIAdapter','USB','Extension','SoftwareComponent','Keyboard','Mouse','Ports'
$sb = New-Object System.Text.StringBuilder
foreach ($d in (Get-PnpDevice -PresentOnly | Where-Object { $focusClasses -contains $_.Class } | Sort-Object Class, FriendlyName)) {
    [void]$sb.AppendLine("=== [$($d.Class)] $($d.FriendlyName) | $($d.Status) | $($d.InstanceId)")
    Get-PnpDeviceProperty -InstanceId $d.InstanceId -ErrorAction SilentlyContinue | ForEach-Object {
        $val = ($_.Data | ForEach-Object { "$_" }) -join ' ; '
        if ($val.Length -gt 400) { $val = $val.Substring(0,400) + ' ...' }
        [void]$sb.AppendLine("    $($_.KeyName) = $val")
    }
}
Save 'pnp-key-devices-allprops.txt' $sb.ToString()

Run 'pnputil-devices.txt' { pnputil /enum-devices /connected /ids /drivers /stack /resources 2>&1 }
Run 'pnputil-drivers.txt' { pnputil /enum-drivers 2>&1 }
Run 'drivers-signed.txt'  { Get-CimInstance Win32_PnPSignedDriver | Sort-Object DeviceClass, DeviceName | Select-Object DeviceClass, DeviceName, DeviceID, DriverVersion, DriverDate, DriverProviderName, InfName, HardWareID | Format-Table -AutoSize -Wrap }
Run 'driverquery.txt'     { driverquery /v /fo list 2>&1 }

# ---------------- ACPI-Tabellen aus der Registry (DSDT/SSDT/FADT/...) ----------------
Step 'ACPI-Tabellen'
function Dump-AcpiKey([string]$path, [string]$rel) {
    try {
        $item = Get-Item -Path $path -ErrorAction Stop
        foreach ($vn in $item.GetValueNames()) {
            $v = $item.GetValue($vn)
            if ($v -is [byte[]]) {
                $suffix = 'default'
                if ($vn) { $suffix = $vn }
                $fn = ($rel + '_' + $suffix) -replace '[\\/:*?"<>| ]','_'
                [IO.File]::WriteAllBytes((Join-Path $acpiDir ($fn + '.bin')), $v)
            }
        }
        foreach ($sk in $item.GetSubKeyNames()) { Dump-AcpiKey ($path + '\' + $sk) ($rel + '_' + $sk) }
    } catch { Write-Warning "ACPI $path : $_" }
}
foreach ($t in (Get-ChildItem 'HKLM:\HARDWARE\ACPI' -ErrorAction SilentlyContinue)) {
    Dump-AcpiKey ('HKLM:\HARDWARE\ACPI\' + $t.PSChildName) $t.PSChildName
}
Save 'acpi-tables-list.txt' (Get-ChildItem $acpiDir | Select-Object Name, Length | Format-Table -AutoSize | Out-String)

# ---------------- Display / EDID / GPU ----------------
Step 'Display/EDID/GPU'
Run 'display.txt' {
    '=== Win32_VideoController'; Get-CimInstance Win32_VideoController | Format-List *
    '=== WmiMonitorID'
    Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue | ForEach-Object {
        $m = -join [char[]]($_.ManufacturerName | Where-Object { $_ })
        $p = -join [char[]]($_.UserFriendlyName | Where-Object { $_ })
        $s = -join [char[]]($_.SerialNumberID | Where-Object { $_ })
        "Instance=$($_.InstanceName) Manufacturer=$m Product=$p Serial=$s Year=$($_.YearOfManufacture)"
    }
    '=== WmiMonitorBasicDisplayParams'; Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams -ErrorAction SilentlyContinue | Format-List *
    '=== Win32_DesktopMonitor';  Get-CimInstance Win32_DesktopMonitor | Format-List *
    '=== Display-Modi';          Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorListedSupportedSourceModes -ErrorAction SilentlyContinue | Format-List *
}
try {
    foreach ($dev in (Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY' -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq 'Device Parameters' })) {
        $edid = $dev.GetValue('EDID')
        if ($edid) {
            $name = ($dev.PSPath -replace '.*Enum\\DISPLAY\\','' -replace '\\Device Parameters','' -replace '[\\/:*?"<>| ]','_')
            [IO.File]::WriteAllBytes((Join-Path $edidDir ($name + '.edid.bin')), [byte[]]$edid)
        }
    }
} catch { Write-Warning "EDID: $_" }

# ---------------- Storage / Partitionen ----------------
Run 'storage.txt' {
    '=== Get-PhysicalDisk'; Get-PhysicalDisk | Format-List *
    '=== Get-Disk';         Get-Disk | Format-List *
    '=== Get-Partition';    Get-Partition | Format-Table -AutoSize
    '=== Get-Volume';       Get-Volume | Format-Table -AutoSize
    '=== Win32_DiskDrive';  Get-CimInstance Win32_DiskDrive | Format-List *
    '=== BitLocker';        if ($isAdmin) { manage-bde -status 2>&1 } else { '(kein Admin)' }
}

# ---------------- Netzwerk / WLAN / Bluetooth (MAC-Adressen fuer sl7-mac-Patch!) ----------------
Run 'network.txt' {
    '=== Get-NetAdapter (MAC!)'; Get-NetAdapter -IncludeHidden | Format-List Name, InterfaceDescription, MacAddress, Status, LinkSpeed, DriverVersion, DriverProvider, DriverFileName, PnPDeviceID
    '=== netsh wlan show drivers'; netsh wlan show drivers 2>&1
    '=== netsh wlan show interfaces'; netsh wlan show interfaces 2>&1
    '=== netsh wlan show wirelesscapabilities'; netsh wlan show wirelesscapabilities 2>&1
}
Run 'bluetooth.txt' {
    '=== Bluetooth-Geraete'; Get-PnpDevice -Class Bluetooth | Format-Table -AutoSize FriendlyName, Status, InstanceId
    '=== Radio-Adresse (Registry BTHPORT, braucht Admin)'
    try { Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Keys' -ErrorAction Stop | Select-Object PSChildName } catch { "nicht lesbar: $_" }
    try { Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Radio Support' -ErrorAction Stop | Format-List * } catch { }
}

# ---------------- Audio / Kamera / Eingabe / Sensoren / USB ----------------
Run 'audio.txt'   { '=== Win32_SoundDevice'; Get-CimInstance Win32_SoundDevice | Format-List *; '=== MEDIA'; Get-PnpDevice -Class MEDIA | Format-Table -AutoSize; '=== AudioEndpoint'; Get-PnpDevice -Class AudioEndpoint | Format-Table -AutoSize }
Run 'camera.txt'  { Get-PnpDevice | Where-Object { ($_.Class -eq 'Camera') -or ($_.Class -eq 'Image') -or ($_.FriendlyName -match 'camera|OV02|IR ') } | Format-List FriendlyName, Class, Status, InstanceId }
Run 'input.txt'   { '=== HID'; Get-PnpDevice -Class HIDClass | Format-Table -AutoSize FriendlyName, Status, InstanceId; '=== Keyboard'; Get-PnpDevice -Class Keyboard | Format-Table -AutoSize; '=== Mouse'; Get-PnpDevice -Class Mouse | Format-Table -AutoSize; '=== Win32_PointingDevice'; Get-CimInstance Win32_PointingDevice | Format-List * }
Run 'sensors.txt' { Get-PnpDevice -Class Sensor | Format-List FriendlyName, Status, InstanceId; '=== Biometric'; Get-PnpDevice -Class Biometric | Format-List FriendlyName, Status, InstanceId }
Run 'usb.txt'     { '=== USB-Controller'; Get-CimInstance Win32_USBController | Format-List *; '=== USB-Geraete'; Get-PnpDevice -Class USB | Format-Table -AutoSize FriendlyName, Status, InstanceId; '=== Win32_USBHub'; Get-CimInstance Win32_USBHub | Format-List Name, DeviceID, Status }
Run 'system-devices.txt' { Get-PnpDevice -Class System | Sort-Object FriendlyName | Format-Table -AutoSize FriendlyName, Status, InstanceId }
Run 'firmware-devices.txt' { Get-PnpDevice -Class Firmware | Format-List FriendlyName, Status, InstanceId; '=== SoftwareComponent'; Get-PnpDevice -Class SoftwareComponent | Format-Table -AutoSize FriendlyName, Status, InstanceId }

# ---------------- Batterie / Power ----------------
Run 'battery.txt' {
    '=== Win32_Battery'; Get-CimInstance Win32_Battery | Format-List *
    '=== BatteryStaticData'; Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Format-List *
    '=== BatteryFullChargedCapacity'; Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Format-List *
    '=== powercfg /a (Schlafzustaende)'; powercfg /a 2>&1
    '=== powercfg /list'; powercfg /list 2>&1
}
Step 'powercfg Batteriebericht'
powercfg /batteryreport /output (Join-Path $OutDir 'battery-report.html') 2>&1 | Out-Null

# ---------------- UEFI / Secure Boot / TPM / Boot ----------------
Run 'uefi-boot.txt' {
    '=== Secure Boot'; try { Confirm-SecureBootUEFI -ErrorAction Stop } catch { "nicht lesbar (Admin?): $_" }
    '=== Firmware-Typ'; $env:firmware_type
    '=== TPM'; try { Get-Tpm -ErrorAction Stop | Format-List * } catch { "nicht lesbar: $_" }
    '=== bcdedit /enum firmware'; if ($isAdmin) { bcdedit /enum firmware 2>&1 } else { '(kein Admin)' }
    '=== bcdedit /enum'; if ($isAdmin) { bcdedit /enum 2>&1 } else { '(kein Admin)' }
    '=== Device Guard'; Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue | Format-List *
    '=== Surface-Registry'; Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Surface' -Recurse -ErrorAction SilentlyContinue | Format-List
}
Run 'windows-update-firmware.txt' {
    Get-CimInstance Win32_QuickFixEngineering | Sort-Object InstalledOn | Format-Table -AutoSize
    '=== Surface/Qualcomm-Treiber im DriverStore'
    Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DriverProviderName -match 'Microsoft|Qualcomm|Surface' } | Sort-Object DeviceClass, DeviceName | Format-Table -AutoSize DeviceClass, DeviceName, DriverVersion, DriverDate, InfName
}

# ---------------- Firmware-Blobs + INF-Dateien aus dem DriverStore ----------------
Step 'Firmware-Blobs aus DriverStore kopieren (Qualcomm/Surface, fuer /lib/firmware)'
$repo = "$env:SystemRoot\System32\DriverStore\FileRepository"
$fwExt = @('.mbn','.jsn','.elf','.tlv','.bin','.fw','.dat','.img','.mdt','.json','.b00','.b01','.b02','.b03','.b04','.b05','.b06','.b07','.b08','.b09','.b10','.b11','.b12','.b13','.b14','.b15','.b16','.b17','.b18','.b19','.b20')
$log = New-Object System.Text.StringBuilder
$dirs = Get-ChildItem $repo -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(qc|qcom|wcn|ath|adsp|cdsp|qcm|qcs|surface|mssurface|snap|arm|pep)' }
foreach ($dir in $dirs) {
    $files = Get-ChildItem $dir.FullName -Recurse -File -ErrorAction SilentlyContinue | Where-Object { ($fwExt -contains $_.Extension.ToLower()) -and ($_.Length -lt 200MB) }
    if ($files) {
        $dst = Join-Path $fwDir $dir.Name
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        foreach ($f in $files) {
            Copy-Item $f.FullName -Destination (Join-Path $dst $f.Name) -Force -ErrorAction SilentlyContinue
            [void]$log.AppendLine("$($dir.Name)\$($f.Name)  $($f.Length)")
        }
    }
}
Save 'firmware-from-windows-list.txt' $log.ToString()
Step 'Alle INF-Dateien (Hardware-ID-Zuordnung)'
Get-ChildItem $repo -Recurse -Filter *.inf -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item $_.FullName -Destination (Join-Path $infDir ($_.Directory.Name + '__' + $_.Name)) -Force -ErrorAction SilentlyContinue
}

# ---------------- Lange Reports ----------------
Step 'msinfo32 (ca. 30-60 s)'
try { Start-Process msinfo32 -ArgumentList "/report `"$(Join-Path $OutDir 'msinfo32.txt')`"" -Wait -WindowStyle Hidden } catch { Write-Warning "msinfo32: $_" }
Step 'dxdiag (ca. 30 s)'
try { Start-Process dxdiag -ArgumentList "/whql:off /t `"$(Join-Path $OutDir 'dxdiag.txt')`"" -Wait -WindowStyle Hidden } catch { Write-Warning "dxdiag: $_" }
Run 'systeminfo.txt' { systeminfo 2>&1 }

# ---------------- ZIP ----------------
Step 'ZIP erstellen'
$zip = "$OutDir.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$OutDir\*" -DestinationPath $zip -CompressionLevel Optimal
Write-Host ""
Write-Host "FERTIG: $zip" -ForegroundColor Green
Write-Host "-> ZIP in den Projektordner 'Projekt Linux ARM\hardware' auf dem PC kopieren." -ForegroundColor Green
