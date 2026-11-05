# params

PX4 parameter files (QGroundControl `.params` format).

| File | What |
|---|---|
| `course-reference.params` | The known-good setup from a CDE1302 course group's working Lab 5 drone (same MicoAir743 board, PX4 1.15.4, 964 params), received 2026-10-27. Load it with `scripts\px4_param_load.py`, which **skips** that drone's own sensor calibration and transmitter calibration. **Don't** use QGroundControl's "Load from file": that copies their calibration onto your drone |

What it sets, in plain words (so you know what you're loading):

| Area | Setting | Meaning |
|---|---|---|
| Motors | `PWM_MAIN_FUNC1-4` = Motor 1-4, DShot | PX4 drives the four ESCs |
| RC | `RC_INPUT_PROTO=6` (CRSF / ExpressLRS); sticks ch 1-4; flight mode switch ch 6 (Stabilized / Position / Land); **kill switch ch 7** | Needs a CRSF/ELRS transmitter bound to the drone's receiver |
| RC lost | `NAV_RCL_ACT=5` = **Terminate** | Motors cut if the RC link is lost. Harsh on purpose: fly low, in a net |
| Compass | `SYS_HAS_MAG=0` | Indoors, no compass. Fixes the "Compass missing" pre-arm error |
| Position | `EKF2_OF_CTRL=1`, `EKF2_HGT_REF=2`, `EKF2_RNG_CTRL=2` | Indoor position from the optical-flow + range sensor |
| ESP32 link | `MAV_0_CONFIG=101` (TELEM1), `SER_TEL1_BAUD=921600` | The ESP32 talks MAVLink on TELEM1 |
| Flow sensor | `MAV_1_CONFIG=102` (TELEM2) @ 115200 | The flow/range module talks MAVLink on TELEM2 |
| Speed | `MPC_XY_VEL_MAX=0.4`, `MPC_Z_VEL_MAX_UP/DN=0.5`, `MPC_LAND_SPEED=0.1` | Slow and safe for first flights |
| Battery | 3S LiHV (`BAT1_N_CELLS=3`, `BAT1_V_CHARGED=4.35`) | **Wrong for most of our drones**: the setup guide overrides it from your battery label |

The setup guide also adds a height limit for the competition's 1.4 m cap: `GF_MAX_VER_DIST=1.3`
and `SENS_FLOW_MAXHGT=1.3`.
