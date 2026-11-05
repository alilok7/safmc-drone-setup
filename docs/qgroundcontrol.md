# QGroundControl: the parts we use

**What this is:** a first-timer's map of QGroundControl (QGC), the ground-station app for PX4.
`scripts\setup-laptop.ps1` installs it.

**First run:** choose **PX4 Pro** and **Multirotor**. These only set offline defaults.

**Connecting:** it connects by itself over **USB**. Over **Wi-Fi via the ESP32**: Application
Settings → Comm Links → Add → UDP, listen port 14550, target `192.168.1.(200+ID)` port 8888.
Only one program can hold the USB port: close QGC before running a `px4_*.py` script.

## Areas (Q logo, top left)
| Area | What | We use it for |
|---|---|---|
| Fly | Live attitude, battery, mode, arm/disarm, Ready / Not Ready (click it for the reasons) | Checking the drone is ready |
| Vehicle Setup | Drone configuration (pages below) | Setup |
| Analyze Tools | Log Download, MAVLink Inspector, **MAVLink Console** | Logs, `mavlink status` when debugging the ESP32 link |
| Application Settings | App settings, comm links | Adding the Wi-Fi link |
| Plan | GPS map missions | No (indoors, no GPS) |

## Vehicle Setup pages
| Page | What | Who |
|---|---|---|
| Summary | Red/green overview | Check first and last |
| Firmware | Flash PX4 | **Don't touch** |
| Sensors | Accelerometer, gyro, level horizon | Person: move the drone as told (phase 5) |
| Radio | RC stick calibration | Person (phase 9) |
| Flight Modes | Mode switch + kill switch | Person (phase 9) |
| Power | Battery cells, voltage | Set by the setup scripts (phase 4) |
| Actuators | Motor mapping, **motor test** | Person, **props off** (phase 8) |
| Parameters | All ~960 raw settings | Look only. Load files with `px4_param_load.py`, **not** QGC's "Load from file" (it copies another drone's calibration) |
