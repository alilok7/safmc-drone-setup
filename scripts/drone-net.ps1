<#
What:  Switches the laptop's Wi-Fi adapter between "drone mode" and normal mode.
         -On : static IP 192.168.1.(100 + drone ID), mask 255.255.255.0, NO default gateway, and marks
               the drone network "Private" so Windows Firewall lets the Python scripts receive data.
         -Off: back to an automatic IP (DHCP) for normal Wi-Fi.
Why:   the course firmware sends each drone's telemetry to ONE fixed laptop IP, 192.168.1.(100+ID).
       The drone router has no internet; with no gateway on it, internet traffic keeps going out
       through a second adapter (phone USB tethering / Ethernet) while the laptop talks to the drone.
       Windows sets a static IP on the whole adapter, not per network, so turn it off again (-Off)
       before joining any other Wi-Fi. See docs\network.md.
Run:   powershell -ExecutionPolicy Bypass -File scripts\drone-net.ps1 -On     (after joining the drone router)
       powershell -ExecutionPolicy Bypass -File scripts\drone-net.ps1 -Off
       Drone ID comes from -DroneId or config\my-drone.env. Needs admin (it asks via a UAC prompt).
#>
param(
    [switch]$On,
    [switch]$Off,
    [ValidateRange(0, 30)][Nullable[int]]$DroneId,
    [string]$Adapter = 'Wi-Fi'
)
. (Join-Path $PSScriptRoot 'common.ps1')

if ($On -eq $Off) { Write-Host 'Use exactly one of -On or -Off.' -ForegroundColor Yellow; exit 1 }
if ($On) {
    try { $id = Resolve-DroneId $DroneId } catch { Write-Host $_ -ForegroundColor Red; exit 1 }
}

# Restart this script as admin if needed (changing IP settings requires it).
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argsList = if ($On) { "-On -DroneId $id" } else { '-Off' }
    Start-Process powershell -Verb RunAs -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`" $argsList -Adapter `"$Adapter`""
    Write-Host 'Opened an admin window to make the change (approve the prompt). Read the result there.'
    exit
}

if ($On) {
    # Check we're on the drone router (the same name the ESP32 firmware was built with).
    $ssid = (Read-EnvFile (Join-Path $ConfigDir 'drone-wifi.env')).WIFI_SSID
    $current = ((netsh wlan show interfaces) | Select-String '^\s+SSID\s+:' | Select-Object -First 1) -replace '^\s+SSID\s+:\s*', ''
    if ($ssid -and $current -ne $ssid) {
        Write-Host "Wi-Fi is on '$current', not the drone router '$ssid'. Join it first, then re-run." -ForegroundColor Yellow
        exit 1
    }
    $ip = Get-LaptopIp $id
    # Static IP with gateway "none": 0.0.0.0 traffic stays on the internet adapter.
    netsh interface ipv4 set address name="$Adapter" static $ip 255.255.255.0 none
    Write-Host "Drone mode ON: $Adapter = $ip, mask 255.255.255.0, no gateway (drone $id)." -ForegroundColor Green
    Start-Sleep -Seconds 3
    try {
        Set-NetConnectionProfile -InterfaceAlias $Adapter -NetworkCategory Private -ErrorAction Stop
        Write-Host 'Network marked Private (firewall lets the drone scripts receive data).'
    } catch { Write-Host "Couldn't mark the network Private: $_ (see docs\troubleshooting.md)" -ForegroundColor Yellow }
} else {
    netsh interface ipv4 set address name="$Adapter" source=dhcp
    Write-Host "Drone mode OFF: $Adapter back to automatic IP (DHCP)." -ForegroundColor Green
}

Start-Sleep -Seconds 3   # let Windows apply the change before showing routes
Write-Host "`nDefault routes (0.0.0.0) - in drone mode none should be on ${Adapter}:"
Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Format-Table InterfaceAlias, NextHop, RouteMetric -AutoSize
