<#
What:  Shared helpers for the other scripts in this folder (they "dot-source" this file):
         - where things live (course firmware, ESP-IDF, Python environment, this drone's settings)
         - reading simple KEY=VALUE files (config\*.env)
         - the drone IP scheme
Why:   so every script finds the same files the same way, and a fix lands in one place.
How it fits:
       Run nothing here directly. Each script starts with  . (Join-Path $PSScriptRoot 'common.ps1')
#>

$RepoRoot = Split-Path $PSScriptRoot
$ConfigDir = Join-Path $RepoRoot 'config'
$ExternalDir = Join-Path $RepoRoot 'external'      # gitignored: big third-party clones live here

# The CDE1302 course firmware + laptop scripts, pinned to the commit we tested drone 3 with.
$CourseRepoUrl = 'https://github.com/linfengfrank/esp-everything-qgc-bridge.git'
$CourseCommit = 'c4caf911d626c95af28cfb619afcdbd06da15082'
# ESP-IDF (the ESP32 build tools), pinned by the course in tools\idf-pin.env.
$IdfRepoUrl = 'https://github.com/espressif/esp-idf.git'
$IdfCommit = '08e0d30a74ad0bfd5a34933142b80f45619ee410'

# Python environment made by setup-laptop.ps1 (the course's environment.yml + gcc + pymavlink).
$EnvName = 'cde1302-laptop'
$ForgeDir = Join-Path $env:USERPROFILE 'miniforge3'
$EnvDir = Join-Path $ForgeDir "envs\$EnvName"
$EnvPython = Join-Path $EnvDir 'python.exe'

# Course firmware IP scheme (flash_drone.sh in the course repo): drone N's ESP32 is 192.168.1.(200+N),
# and it sends telemetry to the laptop at 192.168.1.(100+N). The router must be 192.168.1.1.
function Get-DroneIp([int]$Id) { "192.168.1.$(200 + $Id)" }
function Get-LaptopIp([int]$Id) { "192.168.1.$(100 + $Id)" }

# Course default ESP32 pins for the PX4 serial link (main\Kconfig.projbuild: PX4_TX_PIN 5, PX4_RX_PIN 4).
$DefaultEspTx = 5
$DefaultEspRx = 4

function Find-FirstPath([string[]]$Candidates, [string]$MustContain) {
    foreach ($c in $Candidates) {
        if ($c -and (Test-Path (Join-Path $c $MustContain))) { return (Resolve-Path $c).Path }
    }
    return $null
}

# Course repo: ours in external\, or (on the team lead's laptop) the hub's reference clone next door.
function Find-CourseRepo {
    Find-FirstPath @((Join-Path $ExternalDir 'esp-everything-qgc-bridge'),
                     (Join-Path $RepoRoot '..\reference\esp-everything-qgc-bridge')) 'main\Kconfig.projbuild'
}

# ESP-IDF: $env:IDF_PATH if set, ours in external\, or the hub's reference clone next door.
function Find-Idf {
    Find-FirstPath @($env:IDF_PATH, (Join-Path $ExternalDir 'esp-idf'),
                     (Join-Path $RepoRoot '..\reference\esp-idf')) 'export.ps1'
}

# Read KEY=VALUE lines (ignores blank lines and # comments). Returns a hashtable.
function Read-EnvFile([string]$Path) {
    $h = @{}
    if (Test-Path $Path) {
        foreach ($line in Get-Content $Path) {
            if ($line -match '^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$') { $h[$Matches[1]] = $Matches[2] }
        }
    }
    return $h
}

# This drone's settings (config\my-drone.env, gitignored). Missing file -> empty hashtable.
function Get-MyDrone { Read-EnvFile (Join-Path $ConfigDir 'my-drone.env') }

# Make a config\<name>.env from its committed .example the first time. Returns the path.
function Initialize-EnvFile([string]$Name) {
    $file = Join-Path $ConfigDir "$Name.env"
    if (-not (Test-Path $file)) {
        Copy-Item (Join-Path $ConfigDir "$Name.env.example") $file
        Write-Host "Created $file from the example. Fill it in." -ForegroundColor Yellow
    }
    return $file
}

# Pick the drone ID: the -DroneId argument if given, else DRONE_ID from config\my-drone.env.
function Resolve-DroneId($Given) {
    if ($null -ne $Given -and "$Given" -ne '') { return [int]$Given }
    $d = Get-MyDrone
    if ($d.DRONE_ID -match '^\d+$') { return [int]$d.DRONE_ID }
    throw 'No drone ID. Pass -DroneId <N>, or set DRONE_ID in config\my-drone.env (see config\README.md).'
}

function Step($t) { Write-Host "`n== $t" -ForegroundColor Cyan }
