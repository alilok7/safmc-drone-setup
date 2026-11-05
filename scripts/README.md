# scripts

Windows scripts used by [`docs/setup-guide.md`](../docs/setup-guide.md). Run the `.ps1` ones with
`powershell -ExecutionPolicy Bypass -File scripts\<name>.ps1`, and the `.py` ones with the course
Python environment (`$py = "$env:USERPROFILE\miniforge3\envs\cde1302-laptop\python.exe"`).

| Script | Changes anything? | What |
|---|---|---|
| `setup-laptop.ps1` | installs software | QGroundControl, Miniforge + Python env, course firmware, ESP-IDF (`-WithEspIdf`) |
| `find-ports.ps1` | no | Which COM port is the flight controller / the ESP32 |
| `px4_health_check.py` | no | Plain-English report of the flight controller: version, sensors, warnings, key settings |
| `px4_param_dump.py` | no | Save every PX4 setting to a `.params` file |
| `px4_param_diff.py` | no | Compare two `.params` files |
| `px4_param_load.py` | only with `--apply` | Load a `.params` file (skipping another drone's calibration); preview by default |
| `flash-drone.ps1` | only with `-Port` | Build the ESP32 firmware for this drone (ID, pins, Wi-Fi); back up + flash with `-Port` |
| `drone-net.ps1` | laptop network | Laptop Wi-Fi to the drone's fixed IP with no gateway (`-On`), or back (`-Off`) |
| `common.ps1` | no | Shared helpers the `.ps1` scripts load (paths, pinned versions, IP scheme) |
