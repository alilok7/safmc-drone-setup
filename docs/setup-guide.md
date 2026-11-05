# Drone setup guide (Windows)

**What this is:** every step to take one of our drones from "fresh out of the box" to "first
hover", in order. Written so a person can follow it alone, **or** hand this repo to an AI agent
(Claude Code, Codex) that runs the commands and asks the person for everything it can't see.

**The drone:** MicoAir743 flight controller running PX4 1.15.4, with a Seeed XIAO ESP32-S3 Sense
(camera) as companion computer, an optical-flow + range sensor, and a 2S battery. The ESP32 joins a
Wi-Fi router and bridges the flight controller to the laptop. Firmware and laptop scripts come
from the CDE1302 course ([linfengfrank/esp-everything-qgc-bridge](https://github.com/linfengfrank/esp-everything-qgc-bridge)).

```
Laptop (QGroundControl, Python scripts)  192.168.1.(100+ID)
   │  Wi-Fi router 192.168.1.1, 2.4 GHz
ESP32-S3 on the drone  192.168.1.(200+ID)     ← you flash this (phase 6)
   │  serial cable, 921600 baud, MAVLink      ← wiring differs between drones (docs/wiring.md)
PX4 flight controller (TELEM1)                ← you load settings + calibrate (phases 3-5)
   │  TELEM2: optical-flow + range sensor
```

**Rules (person and agent):**
- **Props off** for everything in this guide until phase 9. The agent asks before any step that can
  power the motors.
- The agent **never arms the drone, never spins motors, never flies.** Physical steps
  (calibration, motor test, RC, flying) are done by the person, in QGroundControl or with the
  transmitter.
- The agent shows what a write will change and **gets an OK before writing** to the drone
  (parameters, firmware).
- **Back up before you change anything:** the flight controller's parameters (phase 3) and the
  ESP32's old firmware (phase 6, automatic).
- Only one program can use a USB port at a time: **close QGroundControl** before running a
  `px4_*.py` script, and the other way round.

Paths below are relative to this repo's folder. `$py` means the Python environment that
`setup-laptop.ps1` makes. Set it once per PowerShell window:
```powershell
$py = "$env:USERPROFILE\miniforge3\envs\cde1302-laptop\python.exe"
```

## Progress tracker
Keep a record of each drone in `drones\drone-<ID>.md` (copy [`drones\TEMPLATE.md`](../drones/TEMPLATE.md)):
which phases passed, what was different on this drone, and the param snapshots. A worked example
is [`drones\drone-3.md`](../drones/drone-3.md). Phases are listed in order; each ends with a
**Pass when** check. Don't move on until it passes; if it doesn't, see
[troubleshooting.md](troubleshooting.md).

---

## Phase 0: what to ask the person
The agent asks for these **when it reaches the phase that needs them** (not all at once), and
never guesses one:

| Needed for | Ask | Why |
|---|---|---|
| Phase 1 | Is this a Windows laptop you can install software on (admin prompts)? Is it OK to use ~3 GB of disk? | QGroundControl, Python, ESP-IDF |
| Phase 3 | **Drone ID** (number written on the drone, 0-30). Is any other drone on the team using it? | The ID decides the IPs; two drones with one ID clash. IDs already used: see `drones\` |
| Phase 3 | Plug the drone's **flight controller** into the laptop by USB (props off, battery unplugged) | |
| Phase 4 | Battery label: **cell count (2S/3S)**, and does it say **HV / LiHV**? | Wrong cells = wrong % and failsafes |
| Phase 5 | Do the calibration in QGroundControl (the agent tells you how) | Needs hands |
| Phase 6 | **Router Wi-Fi name and password** (from the router label or whoever set it up) | Built into the ESP32 firmware |
| Phase 6 | **Which ESP32 pads the flight-controller cable goes to** (a photo works) | The pins are set in software (docs/wiring.md) |
| Phase 6 | Plug the **ESP32** into USB (battery unplugged) | |
| Phase 7 | Can you get internet another way while on the drone Wi-Fi (phone USB tethering, Ethernet)? | The drone router has no internet |
| Phase 8 | Battery plugged in, **props off**, then run the motor test in QGroundControl | |
| Phase 9 | Which RC transmitter? Is the receiver bound? | The course setup expects CRSF/ExpressLRS |

---

## Phase 1: laptop tools
```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup-laptop.ps1 -WithEspIdf
```
Installs QGroundControl, Miniforge + the course Python environment, the course firmware (into
`external\`) and ESP-IDF (the ESP32 build tools, ~2 GB, 10-30 min). Safe to re-run. If it installs
Python it asks you to open a new PowerShell window and run it again.

The repo folder must have **no spaces** in its path and shouldn't be in OneDrive.
`C:\dev\safmc-drone-setup` is a good place.

**Pass when:** it ends with `ok    "tag16h5 ncodes = 22"` and `ok    ESP-IDF ready`.

## Phase 2: find the USB ports
Plug in the flight controller by USB (no battery needed). Then:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\find-ports.ps1
```
**Pass when:** one line says `PX4 flight controller` (note that `COMx`). Later, the ESP32
shows as `ESP32-S3`. COM numbers can change after a replug; re-run this whenever a port stops
working.

## Phase 3: flight-controller health check + backup
Ask for the **drone ID** now. Make the drone's record: copy `drones\TEMPLATE.md` to
`drones\drone-<ID>.md` and make a folder `drones\drone-<ID>\` for its parameter files. Write the ID
into `config\my-drone.env` (copy it from `config\my-drone.env.example`).

```powershell
& $py scripts\px4_health_check.py --port COMx
& $py scripts\px4_param_dump.py --port COMx --out drones\drone-<ID>\<date>-before.params
```
The health check is read-only: board, PX4 version, sensors, warnings. The dump saves every
setting so we can always go back.

**Pass when:** the health check prints `Connected` and `PX4 version: 1.15.x`, and the
`-before.params` file exists (~960 lines). Expect warnings like "Compass missing" and "no RC" on a
fresh drone; phase 4 fixes the first one.

## Phase 4: load the course settings + height limit + battery
Ask about the **battery label**. Pick the battery values:

| Label says | `BAT1_N_CELLS` | `BAT1_V_CHARGED` | `BAT1_V_EMPTY` |
|---|---|---|---|
| 2S LiPo (7.4 V nominal, 8.4 V full) | 2 | 4.2 | 3.5 |
| 2S **HV** / LiHV (7.6 V nominal, 8.7 V full) | 2 | 4.35 | 3.5 |
| 3S LiPo | 3 | 4.2 | 3.5 |

**Preview first** (writes nothing). Fill in the battery values:
```powershell
& $py scripts\px4_param_load.py --port COMx --file params\course-reference.params `
    --set GF_MAX_VER_DIST=1.3 --set SENS_FLOW_MAXHGT=1.3 `
    --set BAT1_N_CELLS=2 --set BAT1_V_CHARGED=4.2 --set BAT1_V_EMPTY=3.5
```
The agent shows the person the list of changes and asks for an OK. Then run **the same command
with `--apply`** added. Then **reboot** the flight controller (unplug and replug USB) and run the
same `--apply` command again: some settings only appear after a reboot. Repeat
(reboot + apply) until the preview says `0 to change`. That took 3 passes on drone 3.

What this loads and why: [params/README.md](../params/README.md). The 1.3 m limits keep the
drone under the competition's 1.4 m height cap. Note: the geofence (`GF_MAX_VER_DIST`) may need a
position fix to work indoors. Don't rely on it without testing it.

Then check again:
```powershell
& $py scripts\px4_health_check.py --port COMx
```
**Pass when:** the preview says `0 to change`, the health check no longer shows "Compass
missing", and it lists `OPTICAL_FLOW_RAD: received` and `DISTANCE_SENSOR: received` (the
flow + range sensor). If the sensor isn't seen on USB power, plug in the battery (props off) and
check again.

## Phase 5: sensor calibration (person, in QGroundControl)
Close any `px4_*.py` script. Open QGroundControl; it connects over USB by itself
([qgroundcontrol.md](qgroundcontrol.md)). In **Vehicle Setup → Sensors**:
1. **Accelerometer:** put the drone on each of its 6 sides as QGC shows.
2. **Gyroscope:** keep it still.
3. **Level Horizon:** drone flat on a level surface.

Then close QGC, and the agent saves a snapshot and checks it:
```powershell
& $py scripts\px4_param_dump.py --port COMx --out drones\drone-<ID>\<date>-calibrated.params
& $py scripts\px4_param_diff.py drones\drone-<ID>\<date>-before.params drones\drone-<ID>\<date>-calibrated.params --prefix CAL_ACC --prefix SENS_BOARD
```
**Pass when:** the `CAL_ACC0_*` values and `SENS_BOARD_X_OFF` / `SENS_BOARD_Y_OFF` changed, and
QGC's Sensors page is green.

## Phase 6: flash the ESP32
1. Ask for the **router name and password**. Put them in `config\drone-wifi.env` (copy it from
   `config\drone-wifi.env.example`). Never commit that file.
2. Ask **how the cable from the flight controller's TELEM1 port is wired to the ESP32**: which XIAO
   pad (D0-D10) the flight controller's **TX** goes to, and which its **RX** goes to (a photo is
   fine). Convert the pads to GPIO numbers with [wiring.md](wiring.md) and write them into
   `config\my-drone.env`:
   - `ESP_RX_PIN` = the pad wired to the **FC's TX** (the ESP32 listens there)
   - `ESP_TX_PIN` = the pad wired to the **FC's RX** (the ESP32 sends there)

   If nobody can tell, keep the course default (TX 5, RX 4) and use the link check in phase 7 to
   find out.
3. **Build only** (touches no hardware):
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\flash-drone.ps1
   ```
   It prints the drone ID, IPs, Wi-Fi name and pins. The agent reads them back to the person.
4. Battery **unplugged**, ESP32 on USB, `find-ports.ps1` → the `ESP32-S3` port. With the person's
   OK:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\flash-drone.ps1 -Port COMy
   ```
   It saves the old firmware to `build\drone<ID>\backup-*.bin` first.

**Pass when:** it ends with `flashed drone <ID>`.

## Phase 7: Wi-Fi link to the drone
1. Plug in the battery (props off) so the drone runs on its own, ESP32 included.
2. Laptop: join the drone router's Wi-Fi. For internet at the same time, turn on phone USB
   tethering ([network.md](network.md)).
3. Set the laptop's fixed IP (admin prompt):
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\drone-net.ps1 -On
   ```
4. Check the drone answers, then check the ESP32 ↔ flight-controller link:
   ```powershell
   ping 192.168.1.(200+ID)
   cd external\esp-everything-qgc-bridge
   & $py laptop\check_px4_esp32_link.py --drone-id <ID>
   ```
   (If the course repo is somewhere else on your laptop, `cd` there instead.) The first time,
   Windows asks to let Python through the firewall: allow it.
5. Camera and AprilTags: `& $py laptop\tag_stream.py --esp-ip 192.168.1.(200+ID)` shows the
   camera with tags marked.

**Pass when:** ping replies, and the link check prints `RESULT: PASS` (ESP32 telemetry **and**
the PX4 heartbeat both arrive). If telemetry arrives but no heartbeat, the cable/pins are wrong:
[troubleshooting.md → "Link check: telemetry but no PX4 heartbeat"](troubleshooting.md#link-check-telemetry-but-no-px4-heartbeat).

Optional: QGroundControl over Wi-Fi. In Application Settings → Comm Links → Add, choose UDP,
listen port 14550, target `192.168.1.(200+ID)` port 8888.

When you're done flying: `scripts\drone-net.ps1 -Off` before joining normal Wi-Fi again.

## Phase 8: motor test, props OFF (person, in QGroundControl)
**Check the props are off.** Battery in. QGC → Vehicle Setup → **Actuators** → Motor testing:
enable it and spin each motor briefly, one at a time (put tape on each motor to see which way it turns).

Expected for PX4 "quadrotor X" (seen from above, front = forward):

| Motor | Position | Spin |
|---|---|---|
| 1 | front right | counter-clockwise |
| 2 | back left | counter-clockwise |
| 3 | front left | clockwise |
| 4 | back right | clockwise |

**Pass when:** each motor number spins the motor in that position, in that direction. If not:
[troubleshooting.md → "Motor test: wrong motor or wrong direction"](troubleshooting.md#motor-test-wrong-motor-or-wrong-direction).

## Phase 9: RC transmitter + kill switch (person)
The course settings expect a **CRSF / ExpressLRS** receiver (`RC_INPUT_PROTO=6`).
1. Bind the transmitter to the drone's receiver (the transmitter's manual).
2. QGC → Vehicle Setup → **Radio** → Calibrate: move the sticks as told.
3. QGC → **Flight Modes**: check channel 6 switches Stabilized / Position / Land and channel 7
   is the **kill switch** (`RC_MAP_FLTMODE=6`, `RC_MAP_KILL_SW=7` from the course settings).
4. Kill-switch test, **props off**: arm in QGC/with the transmitter, flip the kill switch, and the
   motors must stop at once. Disarm.

Note: if the RC link is lost in flight, these settings cut the motors (`NAV_RCL_ACT=5`). Fly low,
in a net.

**Pass when:** the sticks move the bars in QGC's Radio page the right way, and the kill switch
stops the motors.

## Phase 10: ready to fly → first hover
QGC → Summary: all green. Fly view top bar: **Ready To Fly** (click it to see what's blocking if
not).

First hover is done by a **person with the RC transmitter, in a netted area, at ~0.5 m, with a
second person watching the kill switch.** Props on only now. After that, the course order
(`external\esp-everything-qgc-bridge\laptop\TEST_GUIDE.md`) is: takeoff/hover/land from the laptop →
waypoints → trajectories. Always with the RC pilot ready to take over.

**Pass when:** it hovers steadily and lands. Write it in `drones\drone-<ID>.md`.

---

## When you're done
- Save the drone's record (`drones\drone-<ID>.md` + its `.params` snapshots). If you're not a
  maintainer of this repo, send them to the team lead, or fork the repo and open a pull request.
- Unplug the battery when not testing: the ESP32 and Wi-Fi drain it even when idle.
- Charging: [battery.md](battery.md).
