<#
What:  Builds the CDE1302 course ESP32 firmware for ONE drone (its ID, its wiring, your Wi-Fi router)
       and, only if you pass -Port, backs up the ESP32's current firmware and flashes the new one.
Why:   the course's own flash_drone.sh is a bash script, keeps the course lab's router name/password,
       and assumes everyone wired the ESP32 the same way. We need any drone ID, our router, and
       the pins that match each drone's actual cable.
How it fits:
       Course firmware: external\esp-everything-qgc-bridge (setup-laptop.ps1 clones it; never edited)
       ESP-IDF:         external\esp-idf (setup-laptop.ps1 -WithEspIdf)
       Wi-Fi:           config\drone-wifi.env    (gitignored; router name + password)
       This drone:      config\my-drone.env      (gitignored; DRONE_ID, ESP_TX_PIN, ESP_RX_PIN)
       Output:          build\drone<ID>\  (sdkconfig, firmware, backups of the old firmware)
       Arguments override config\my-drone.env, so you can try other pins without editing anything.
Run:   powershell -ExecutionPolicy Bypass -File scripts\flash-drone.ps1                 # build only
       powershell -ExecutionPolicy Bypass -File scripts\flash-drone.ps1 -Port COM6      # back up + flash
       ... -DroneId 7 -Tx 6 -Rx 5    (override the ID or pins for this run)
       Before -Port: ESP32 on USB, drone battery unplugged, props off.
#>
param(
    [ValidateRange(0, 30)][Nullable[int]]$DroneId,   # course Kconfig range 0-30
    [ValidateRange(0, 48)][Nullable[int]]$Tx,        # ESP32 GPIO that SENDS to the flight controller's RX
    [ValidateRange(0, 48)][Nullable[int]]$Rx,        # ESP32 GPIO that LISTENS to the flight controller's TX
    [string]$Port,
    [string]$WifiFile                               # optional: a different Wi-Fi .env file
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$id = Resolve-DroneId $DroneId
$mine = Get-MyDrone
if ($null -eq $Tx) { $Tx = if ($mine.ESP_TX_PIN -match '^\d+$') { [int]$mine.ESP_TX_PIN } else { $DefaultEspTx } }
if ($null -eq $Rx) { $Rx = if ($mine.ESP_RX_PIN -match '^\d+$') { [int]$mine.ESP_RX_PIN } else { $DefaultEspRx } }
if ($Tx -eq $Rx) { throw "TX and RX can't be the same pin (both are GPIO$Tx)." }

$course = Find-CourseRepo
if (-not $course) { throw 'Course firmware not found. Run scripts\setup-laptop.ps1 first.' }
$build = Join-Path $RepoRoot "build\drone$id"
$sdk = Join-Path $build 'sdkconfig'

# ---- 1. Wi-Fi settings
if (-not $WifiFile) { $WifiFile = Initialize-EnvFile 'drone-wifi' }
$wifi = Read-EnvFile $WifiFile
foreach ($k in 'WIFI_SSID', 'WIFI_PASSWORD', 'WIFI_GATEWAY', 'WIFI_NETMASK') {
    if (-not $wifi[$k]) { throw "$k missing in $WifiFile" }
}
if ($wifi.WIFI_SSID -like 'CHANGE-ME*' -or $wifi.WIFI_PASSWORD -like 'CHANGE-ME*') {
    throw "Wi-Fi in $WifiFile is still the placeholder. Put the drone router's name and password in it."
}
if ($wifi.WIFI_GATEWAY -ne '192.168.1.1') {
    Write-Host "WARNING: gateway is $($wifi.WIFI_GATEWAY). The course firmware's IPs assume the router is 192.168.1.1." -ForegroundColor Yellow
}

# ---- 2. Per-drone sdkconfig: a copy of the course one (the course file is never changed)
$values = [ordered]@{
    CONFIG_PX4_TX_PIN             = "$Tx"
    CONFIG_PX4_RX_PIN             = "$Rx"
    CONFIG_DRONE_ID               = "$id"
    CONFIG_HOST_IPV4_ADDR         = "`"$(Get-LaptopIp $id)`""
    CONFIG_DRONE_STATIC_IPV4_ADDR = "`"$(Get-DroneIp $id)`""
    CONFIG_WIFI_GATEWAY_IPV4_ADDR = "`"$($wifi.WIFI_GATEWAY)`""
    CONFIG_WIFI_NETMASK_IPV4_ADDR = "`"$($wifi.WIFI_NETMASK)`""
    CONFIG_WIFI_SSID              = "`"$($wifi.WIFI_SSID)`""
    CONFIG_WIFI_PASSWORD          = "`"$($wifi.WIFI_PASSWORD)`""
}
New-Item -ItemType Directory -Force $build | Out-Null
$lines = [System.Collections.Generic.List[string]](Get-Content (Join-Path $course 'sdkconfig'))
foreach ($k in $values.Keys) {
    $i = $lines.FindIndex({ param($l) $l.StartsWith("$k=") -or $l -eq "# $k is not set" })
    if ($i -ge 0) { $lines[$i] = "$k=$($values[$k])" } else { $lines.Add("$k=$($values[$k])") }
}
[System.IO.File]::WriteAllLines($sdk, $lines)   # UTF-8 without BOM; the Kconfig tools dislike a BOM
Write-Host "drone $id -> ESP32 $(Get-DroneIp $id), laptop $(Get-LaptopIp $id), Wi-Fi '$($wifi.WIFI_SSID)',"
Write-Host "            PX4 link: ESP32 TX GPIO$Tx -> FC RX, ESP32 RX GPIO$Rx <- FC TX"

# ---- 3. ESP-IDF environment
$idf = Find-Idf
if (-not $idf) { throw 'ESP-IDF not found. Run: scripts\setup-laptop.ps1 -WithEspIdf' }
. (Join-Path $idf 'export.ps1') | Out-Null

# ---- 4. Build, then check the generated header (the build can silently reset bad values)
idf.py -C $course -B $build -D "SDKCONFIG=$sdk" build
if ($LASTEXITCODE -ne 0) { throw 'build failed (see docs\troubleshooting.md, "ESP32 firmware won''t build")' }
$hdr = Get-Content (Join-Path $build 'config\sdkconfig.h')
foreach ($k in $values.Keys) {
    if (-not ($hdr -contains "#define $k $($values[$k])")) { throw "built firmware has the wrong $k - not flashing" }
}
Write-Host "verified: firmware is drone $id with the Wi-Fi and pins above" -ForegroundColor Green

if (-not $Port) {
    Write-Host 'Build only (no -Port given). Nothing was written to any hardware.'
    exit 0
}

# ---- 5. Back up the ESP32's current firmware (whole flash chip), then flash
$info = python -m esptool --port $Port flash-id 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "esptool can't talk to $Port. Wrong port, or hold BOOT while plugging in USB.`n$info" }
$mb = if ($info -match 'Detected flash size:\s*(\d+)MB') { [int]$Matches[1] } else { 0 }
if ($mb -lt 1) { throw "Couldn't read the flash size from esptool:`n$info" }
$flashBytes = '0x{0:X}' -f ($mb * 1MB)
$backup = Join-Path $build "backup-$(Get-Date -Format yyyy-MM-dd-HHmm).bin"
Write-Host "Backing up the current $mb MB firmware to $backup ..."
python -m esptool --port $Port read-flash 0 $flashBytes $backup
if ($LASTEXITCODE -ne 0) { throw 'backup failed - not flashing' }

idf.py -C $course -B $build -D "SDKCONFIG=$sdk" -p $Port flash
if ($LASTEXITCODE -ne 0) { throw 'flash failed (see docs\troubleshooting.md)' }
Write-Host "flashed drone $id. Old firmware saved at $backup (restore: python -m esptool --port $Port write-flash 0 <file>)" -ForegroundColor Green
