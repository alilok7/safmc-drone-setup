<#
What:  Installs everything a Windows laptop needs to set up and fly one of our drones:
         1. checks: Git, a folder path without spaces / not in OneDrive
         2. the CDE1302 course firmware + laptop scripts, cloned into external\ at a pinned commit
         3. QGroundControl (ground station app for PX4), plus Start-menu + desktop shortcuts
         4. Miniforge (conda) in %USERPROFILE%\miniforge3
         5. the course Python environment "cde1302-laptop" + gcc (AprilTag detector) + pymavlink
            (for this repo's px4_*.py scripts)
         6. check: the course AprilTag build test must print "ncodes = 22"
         7. only with -WithEspIdf: Python 3.12 (if missing) + ESP-IDF at the course's pinned commit
            (~2 GB, 10-30 min). Needed to build/flash the ESP32 firmware.
Why:   so any laptop goes from nothing to "ready" in one step, the same way every time.
How it fits:
       First step of docs\setup-guide.md. Safe to re-run: every step is skipped if already done.
       Downloads are checked against the SHA-256 that GitHub publishes. QGC and Python may show a
       Windows admin prompt.
Run:   powershell -ExecutionPolicy Bypass -File scripts\setup-laptop.ps1 [-WithEspIdf] [-DryRun]
#>
param([switch]$WithEspIdf, [switch]$DryRun)
. (Join-Path $PSScriptRoot 'common.ps1')

$tmp = Join-Path $env:TEMP 'safmc-setup'
$qgcExe = 'C:\Program Files\QGroundControl\bin\QGroundControl.exe'
$conda = Join-Path $ForgeDir 'Scripts\conda.exe'
$ProgressPreference = 'SilentlyContinue'   # makes Invoke-WebRequest much faster on PowerShell 5.1

# Download a release file from GitHub and check it against GitHub's published SHA-256.
function Get-ReleaseFile($repo, $namePattern) {
    $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'safmc-drone-setup' }
    $asset = $rel.assets | Where-Object { $_.name -match $namePattern } | Select-Object -First 1
    if (-not $asset) { throw "No release file matching '$namePattern' in $repo" }
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $out = Join-Path $tmp $asset.name
    Write-Host "downloading $($asset.name) ($($rel.tag_name))"
    Invoke-WebRequest $asset.browser_download_url -OutFile $out
    if ($asset.digest) {
        $hash = 'sha256:' + (Get-FileHash $out -Algorithm SHA256).Hash.ToLower()
        if ($hash -ne $asset.digest) { Remove-Item $out; throw "Checksum mismatch for $($asset.name). Deleted it; try again." }
        Write-Host 'ok    checksum matches GitHub'
    }
    return $out
}

# Clone a repo at an exact commit (or check an existing clone is at it).
function Get-PinnedRepo($url, $dir, $commit, [switch]$Submodules) {
    if (-not (Test-Path (Join-Path $dir '.git'))) {
        if ($DryRun) { Write-Host "would clone $url into $dir at $($commit.Substring(0,8))"; return }
        git clone $url $dir
        if ($LASTEXITCODE -ne 0) { throw "git clone $url failed (internet?)" }
    }
    $head = (git -C $dir rev-parse HEAD).Trim()
    if ($head -ne $commit) {
        if ($DryRun) { Write-Host "would check out $($commit.Substring(0,8)) in $dir (now $($head.Substring(0,8)))"; return }
        git -C $dir fetch origin
        git -C $dir checkout --quiet $commit
        if ($LASTEXITCODE -ne 0) { throw "couldn't check out $commit in $dir" }
    }
    if ($Submodules -and -not $DryRun) {
        git -C $dir submodule update --init --recursive
        if ($LASTEXITCODE -ne 0) { throw "submodule update failed in $dir" }
    }
    Write-Host "ok    $dir at $($commit.Substring(0,8))"
}

Step '1. Checks'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host 'FAIL  Git is missing. Install it: winget install --id Git.Git -e   then open a new PowerShell.' -ForegroundColor Red
    exit 1
}
Write-Host "ok    git"
if ($RepoRoot -match ' ') {
    Write-Host "FAIL  This folder's path has a space: $RepoRoot. The C compiler and ESP-IDF break on spaces." -ForegroundColor Red
    Write-Host '      Move the repo to e.g. C:\dev\safmc-drone-setup and run again.'
    exit 1
}
if ($RepoRoot -match 'OneDrive|Dropbox') {
    Write-Host "warn  $RepoRoot is inside a cloud-synced folder. Builds are slow and can corrupt there; C:\dev\ is better." -ForegroundColor Yellow
}
Write-Host "ok    path $RepoRoot"

Step '2. Course firmware + laptop scripts'
$course = Find-CourseRepo
if ($course -and $course -notlike "$ExternalDir*") { Write-Host "ok    using the existing course repo at $course" }
else { Get-PinnedRepo $CourseRepoUrl (Join-Path $ExternalDir 'esp-everything-qgc-bridge') $CourseCommit }
$course = Find-CourseRepo

Step '3. QGroundControl'
if (Test-Path $qgcExe) { Write-Host 'ok    already installed' }
elseif ($DryRun) { Write-Host 'would download and install the latest QGroundControl' }
else {
    $installer = Get-ReleaseFile 'mavlink/qgroundcontrol' '^QGroundControl-installer-AMD64\.exe$'
    Write-Host 'installing (approve the Windows admin prompt)...'
    Start-Process $installer -ArgumentList '/S' -Verb RunAs -Wait
    if (Test-Path $qgcExe) { Write-Host 'ok    installed' } else { Write-Host 'FAIL  QGroundControl did not install' -ForegroundColor Red }
}
if ((Test-Path $qgcExe) -and -not $DryRun) {
    # The silent installer makes no shortcuts, so add them.
    $ws = New-Object -ComObject WScript.Shell
    foreach ($lnk in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\QGroundControl.lnk",
                       (Join-Path ([Environment]::GetFolderPath('Desktop')) 'QGroundControl.lnk'))) {
        if (Test-Path $lnk) { continue }
        $s = $ws.CreateShortcut($lnk); $s.TargetPath = $qgcExe; $s.WorkingDirectory = Split-Path $qgcExe; $s.Save()
        Write-Host "ok    shortcut $lnk"
    }
}

Step '4. Miniforge (conda)'
if (Test-Path $conda) { Write-Host "ok    already installed at $ForgeDir" }
elseif ($DryRun) { Write-Host "would install Miniforge to $ForgeDir" }
else {
    if ($ForgeDir -match ' ') { Write-Host "warn  '$ForgeDir' has a space (your Windows user name); the course C compiler may fail" -ForegroundColor Yellow }
    $installer = Get-ReleaseFile 'conda-forge/miniforge' '^Miniforge3-Windows-x86_64\.exe$'
    # JustMe = no admin needed. (Installing to C:\miniforge3 fails silently without admin.)
    $p = Start-Process $installer -ArgumentList '/S', '/InstallationType=JustMe', '/RegisterPython=0', '/AddToPath=0', "/D=$ForgeDir" -Wait -PassThru
    if (Test-Path $conda) { Write-Host 'ok    installed' } else { Write-Host "FAIL  Miniforge installer exit code $($p.ExitCode)" -ForegroundColor Red; exit 1 }
}

Step "5. Python environment '$EnvName'"
if ($DryRun) { Write-Host "would create $EnvName from the course laptop\environment.yml, add gcc and pymavlink" }
else {
    # We run the environment's own python.exe instead of "conda run": with Windows Smart App Control
    # ON, Miniforge's base python (which conda.exe needs) can be blocked while the environment's
    # python still runs. Putting the env's folders first on PATH is what "conda activate" does.
    $env:Path = "$EnvDir;$EnvDir\Library\mingw-w64\bin;$EnvDir\Library\bin;$EnvDir\Scripts;$env:Path"
    function Invoke-Conda {
        $out = & $conda @args 2>&1 | Out-String
        if ($out -match 'Unable to create process|Application Control policy') {
            Write-Host @"
FAIL  Windows blocked conda's Python ("Application Control policy"). This is Windows Smart App Control.
      See docs\troubleshooting.md, "Smart App Control blocks conda".
"@ -ForegroundColor Red
            exit 1
        }
        return $out
    }
    if (Test-Path $EnvPython) { Write-Host 'ok    environment exists' }
    else {
        Push-Location $course
        Invoke-Conda env create -y -f laptop/environment.yml | Write-Host
        Pop-Location
        if (-not (Test-Path $EnvPython)) { Write-Host 'FAIL  environment was not created (see output above)' -ForegroundColor Red; exit 1 }
    }
    if (Get-Command gcc -ErrorAction SilentlyContinue) { Write-Host 'ok    gcc present' }
    else { Invoke-Conda install -y -n $EnvName -c conda-forge gcc | Write-Host }
    & $EnvPython -m pip install --quiet pymavlink pyserial
    if ($LASTEXITCODE -eq 0) { Write-Host 'ok    pymavlink + pyserial' } else { Write-Host 'FAIL  pip install pymavlink' -ForegroundColor Red; exit 1 }

    Step '6. Check: course AprilTag detector builds'
    Push-Location $course
    $check = & $EnvPython laptop/apriltag_host.py 2>&1 | Out-String
    Pop-Location
    if ($check -match 'ncodes = 22') { Write-Host 'ok    "tag16h5 ncodes = 22": laptop tools work' -ForegroundColor Green }
    else { Write-Host "FAIL  AprilTag check did not pass:`n$check" -ForegroundColor Red; exit 1 }
}

if ($WithEspIdf) {
    Step '7. ESP-IDF (ESP32 build tools)'
    $py = Get-Command py -ErrorAction SilentlyContinue
    $hasPy312 = $py -and ((& py -3.12 --version 2>$null) -match '3\.12')
    if (-not $hasPy312) {
        if ($DryRun) { Write-Host 'would install Python 3.12 (winget Python.Python.3.12); ESP-IDF needs a normal Python' }
        else {
            winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
            Write-Host 'Python 3.12 installed. Open a NEW PowerShell window and run this script again with -WithEspIdf.' -ForegroundColor Yellow
            exit 0
        }
    } else { Write-Host 'ok    Python 3.12' }
    $idf = Find-Idf
    if ($idf -and $idf -notlike "$ExternalDir*") { Write-Host "ok    using the existing ESP-IDF at $idf" }
    else {
        $idf = Join-Path $ExternalDir 'esp-idf'
        Get-PinnedRepo $IdfRepoUrl $idf $IdfCommit -Submodules
        if (-not $DryRun) {
            # install.ps1 runs with the first "python" on PATH; make that Python 3.12, not conda's.
            $py312 = (& py -3.12 -c 'import sys; print(sys.executable)').Trim()
            $env:Path = "$(Split-Path $py312);$env:Path"
            & (Join-Path $idf 'install.ps1') esp32s3
            if ($LASTEXITCODE -ne 0) { Write-Host 'FAIL  ESP-IDF install (see output above)' -ForegroundColor Red; exit 1 }
        }
    }
    Write-Host 'ok    ESP-IDF ready (flash-drone.ps1 loads it by itself)'
}

Step 'Done'
if ($DryRun) { Write-Host 'Dry run: nothing was changed.'; exit 0 }
Write-Host @"
Python for the drone scripts:  $EnvPython
  e.g.  & '$EnvPython' scripts\px4_health_check.py --port COMx
Next: docs\setup-guide.md, phase 2 (find the ports).
"@
