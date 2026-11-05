<#
What:  Lists the USB serial (COM) ports on this laptop and says which one is the drone's flight
       controller and which is its ESP32, from the USB vendor ID.
Why:   COM numbers differ between laptops and can change after a replug or reset. Every other
       step needs the right port, and guessing wrong just gives "no heartbeat" or "can't connect".
How it fits:
       Use the PX4 port for px4_*.py (--port) and the ESP32 port for flash-drone.ps1 -Port.
       Read-only: it only asks Windows which devices are plugged in.
Run:   powershell -ExecutionPolicy Bypass -File scripts\find-ports.ps1
       Tip: run it, unplug one cable, run it again. The port that vanished is that device.
#>

# USB vendor IDs we've seen on these drones.
$known = @{
    '1B8C' = 'PX4 flight controller (MicoAir743)'
    '303A' = 'ESP32-S3 (Espressif native USB) - the drone''s ESP32 / XIAO'
    '10C4' = 'USB-serial chip (CP210x) - maybe an ESP32 dev board or radio'
    '1A86' = 'USB-serial chip (CH340) - maybe an ESP32 dev board'
    '0403' = 'USB-serial chip (FTDI)'
    '26AC' = 'PX4 flight controller (3DR/Pixhawk)'
}

$ports = Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match '\((COM\d+)\)' }
if (-not $ports) {
    Write-Host 'No COM ports found. Check: is the USB cable a DATA cable (charge-only cables are common)?' -ForegroundColor Yellow
    Write-Host 'Is the board powered? Try another USB port. (docs\troubleshooting.md)'
    exit 1
}
foreach ($p in $ports) {
    $com = ([regex]'\((COM\d+)\)').Match($p.Name).Groups[1].Value
    $vid = if ($p.DeviceID -match 'VID_([0-9A-F]{4})') { $Matches[1] } else { '????' }
    $pid_ = if ($p.DeviceID -match 'PID_([0-9A-F]{4})') { $Matches[1] } else { '????' }
    $what = if ($p.DeviceID -notlike 'USB*') { 'not USB (Bluetooth / built-in) - ignore' }
            elseif ($known.ContainsKey($vid)) { $known[$vid] } else { 'unknown USB device' }
    Write-Host ("{0,-6} VID {1} PID {2}  {3}   [{4}]" -f $com, $vid, $pid_, $what, $p.Name)
}
