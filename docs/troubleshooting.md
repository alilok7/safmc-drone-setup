# Troubleshooting

**What this is:** the problems we've actually hit (or expect) setting up these drones, what each
one looks like, and how to fix it. Find the symptom, then work down its list: the most likely
cause comes first. Agents: tell the person what you're checking and why, one step at a time, and
ask them to look at the hardware when the answer can't be read from the laptop.

## Laptop / install

### `setup-laptop.ps1` stops at "Application Control policy" (Smart App Control blocks conda)
Windows Smart App Control blocked Miniforge's Python. Check *Windows Security → App & browser
control → Smart App Control*. If it's **On**: turning it **Off** fixes it (common on development
laptops, but it can't be turned back on without resetting Windows, so that's the owner's call).
The environment's own `python.exe` often still runs, so once the environment exists the scripts
use it directly.

### C compiler / AprilTag check fails, or ESP-IDF errors about paths
- The repo path or your Windows user folder has a **space**, or the repo is in **OneDrive**. Move the
  repo to `C:\dev\safmc-drone-setup`.
- `ncodes` check fails with "gcc not found": re-run `setup-laptop.ps1` (it installs gcc into the env).

### ESP32 firmware won't build
- `ESP-IDF not found`: run `scripts\setup-laptop.ps1 -WithEspIdf`.
- Errors in `install.ps1` about Python: ESP-IDF needs a normal Python (3.12), not conda's. The
  script installs it; open a **new** PowerShell window afterwards and re-run.
- Weird build errors after changing settings: delete `build\drone<ID>\` and build again.

## USB / serial ports

### `px4_*.py`: "No HEARTBEAT from PX4 within 10 s"
1. **QGroundControl is open** and holding the port. Close it.
2. Wrong COM port. Run `scripts\find-ports.ps1`; use the `PX4 flight controller` one.
3. The USB cable is charge-only (no data). Try another cable; `find-ports.ps1` should show a port.
4. The board just booted: wait 5 s and retry.

### `find-ports.ps1` shows nothing
Charge-only cable, a bad USB port, or the board isn't powered. Try another cable and another USB port.

### `flash-drone.ps1`: "esptool can't talk to COMx" / flash fails partway
1. Wrong port (the ESP32 is the `ESP32-S3` line; the COM number can change after a reset).
2. Put the ESP32 in download mode: **hold the BOOT button on the XIAO while plugging in USB**,
   release, then retry. Its COM number may change.
3. Another program (a serial monitor, `idf.py monitor`) has the port open. Close it.

## Flight-controller settings

### `px4_param_load.py`: "not on this drone yet: MAV_1_..., SER_TEL2_BAUD ..."
Normal on the first pass. Those settings only exist after a reboot. Reboot (replug USB), run the
`--apply` command again, repeat until `0 to change`.

### Health check: "Compass Sensor 0 missing" / can't arm
The course settings weren't loaded (they set `SYS_HAS_MAG=0`). Do phase 4.

### Health check: `OPTICAL_FLOW_RAD` / `DISTANCE_SENSOR` "not received"
1. The sensor may only power up on the **battery**: plug it in (props off), check again.
2. Settings not loaded yet, or not rebooted after loading (`MAV_1_CONFIG=102` = TELEM2 @ 115200).
3. The sensor's cable on TELEM2 is loose. Ask the person to check it.

### Battery shows 0 % / "critical" while the battery is fine
`BAT1_N_CELLS` is wrong (the course file says 3; most of our batteries are 2S). Set it from the
label (phase 4 table). The reading should then be sensible, e.g. 7.6 V ≈ 45 % for 2S.

## Wi-Fi and the ESP32

### The ESP32 doesn't join the router (ping gets no reply)
1. Wrong name or password in `config\drone-wifi.env` (case matters). Fix, then **re-flash**: the
   firmware only learns it when flashed.
2. The router's **2.4 GHz** network must be on (the ESP32 has no 5 GHz).
3. The router must be **192.168.1.1** and hand out 192.168.1.x.
4. Watch the ESP32's log to see what it's doing. ESP32 on USB, in PowerShell:
   `. external\esp-idf\export.ps1; idf.py -C external\esp-everything-qgc-bridge -B build\drone<ID> -p COMy monitor`
   (Ctrl+] quits). Look for Wi-Fi connect errors and the IP it got.

### Laptop can't reach the drone, or the link check sees no telemetry at all
1. Laptop IP wrong. It must be **192.168.1.(100+ID)** for *this* drone: `scripts\drone-net.ps1 -On`
   (with the right ID), check with `ipconfig`.
2. The **firewall** blocks Python: the drone network must be "Private", and Python allowed
   (Windows asks on first run; or *Windows Security → Firewall → Allow an app*).
3. The ESP32 was flashed with a **different drone ID** (its IP is 192.168.1.(200+ID it was built
   with)). Re-flash with the right ID.
4. Two drones share one ID: IP clash. Give each drone its own ID.
5. The laptop is on another Wi-Fi network. Join the drone router.

### Link check: telemetry but no PX4 heartbeat
The ESP32 is fine on Wi-Fi but isn't hearing the flight controller: **the serial link**. (On drone
3, the ESP32 log said `Waiting for telemetry...`.)
1. **Pins don't match the cable.** Ask the person which XIAO pad each FC wire goes to
   ([wiring.md](wiring.md)), set `ESP_TX_PIN`/`ESP_RX_PIN`, re-flash. If nobody can tell, try the
   pin pairs in wiring.md.
2. Check what PX4 sees. In QGC → Analyze Tools → **MAVLink Console**, type `mavlink status`.
   Find the instance on `/dev/ttyS0` (TELEM1):
   - tx > 0 but **rx = 0**: PX4 sends but hears nothing → the ESP32's TX isn't reaching FC RX1.
     Pins or that wire.
   - instance missing: the settings aren't loaded (`MAV_0_CONFIG=101`, `SER_TEL1_BAUD=921600`).
     Load them, reboot.
3. **GND** not connected between the boards.
4. The cable is on TELEM2 instead of TELEM1.

### Camera stream / tags don't show
`tag_stream.py` needs `--esp-ip 192.168.1.(200+ID)`, the firewall open for Python, and the
camera detected (the ESP32 log says OV3660 or similar at boot). Re-seat the camera ribbon if not.

## Motors and RC

### Motor test: wrong motor or wrong direction
**Props off.** In QGC → Actuators:
- A different motor spins than the one you picked: change the motor's output in the Actuator
  Outputs section (which output drives Motor 1-4) until each number matches its position.
- Right motor, wrong direction: with DShot ESCs, QGC's Actuators page can reverse the direction
  ("Set Spin Direction") on some setups. Otherwise swap any two of that motor's three wires. Ask
  someone from hardware if unsure.

### No RC / sticks don't move in QGC
1. The receiver isn't bound to the transmitter (its LED usually shows that). Bind it.
2. Wrong protocol: the course settings expect CRSF (`RC_INPUT_PROTO=6`). A different receiver
   type needs a different setting.
3. The receiver isn't wired to the flight controller's RC port. Ask hardware.

### "Not ready to fly"
Click the "Not Ready" text in QGC's Fly view: it lists the reasons. The common ones are
calibration not done (phase 5), no RC (phase 9), and battery low. Fix those first.

## Going back
- Old ESP32 firmware: `python -m esptool --port COMy write-flash 0 build\drone<ID>\backup-<date>.bin`
  (after `. external\esp-idf\export.ps1`).
- Old flight-controller settings: `px4_param_load.py --file drones\drone-<ID>\<date>-before.params`
  (preview, then `--apply`).
