# Drone 3

**Who set it up:** the OD lead + Claude Code, on an Acer laptop. **Done:** 2026-10-30 (bench).
The first drone set up with this procedure; the guide is written from it.

## Facts
| Item | Value |
|---|---|
| Drone ID | 3 → ESP32 192.168.1.203, laptop 192.168.1.103 |
| Flight controller | MicoAir743v2 (STM32H743), PX4 v1.15.4, airframe 4001 (generic quad) |
| ESP32 | Seeed XIAO ESP32-S3 Sense, 8 MB flash + 8 MB PSRAM, OV3660 camera, MAC 10:20:ba:03:97:68 |
| Wiring (FC TELEM1 → XIAO) | TX1 → D4 (GPIO5), RX1 → D5 (GPIO6) → `ESP_RX_PIN=5`, `ESP_TX_PIN=6` (**not** the course default) |
| Battery | 2S LiPo (label "7.6 V"), charged as LiPo to 4.2 V/cell |
| COM ports on that laptop | FC COM5/COM7, ESP32 COM6 (changed between sessions) |
| RC | RadioMaster TX16S + ELRS. SB down arms, SB up disarms; SF down stops motors instantly (props-off tests) |

## Setup log
| Date | Phase | Result |
|---|---|---|
| 2026-10-23 | 3 Health check | Unconfigured board: no motors mapped, no RC, compass missing, no flow sensor |
| 2026-10-30 | 3 Backup | [`drone-3/2026-10-30-before.params`](drone-3/2026-10-30-before.params) |
| 2026-10-30 | 4 Course settings | 48 params written in 3 passes with reboots; + `GF_MAX_VER_DIST=1.3`, `SENS_FLOW_MAXHGT=1.3`. Compass error gone, flow + range sensor detected |
| 2026-10-30 | 5 Calibration | Accel (6 sides), gyro, level. `SENS_BOARD_X/Y_OFF` = 1.34° / 1.68°. [`drone-3/2026-10-30-calibrated.params`](drone-3/2026-10-30-calibrated.params) |
| 2026-10-30 | 4 Battery | `BAT1_N_CELLS` 3 → 2, `BAT1_V_CHARGED` 4.35 → 4.2. Showed 0 % / critical before, 45 % at 7.6 V after |
| 2026-10-30 | 6 ESP32 flash | Old firmware (a teammate's Arduino Wi-Fi test) backed up, course firmware flashed |
| 2026-10-30 | 7 Link check | First: Wi-Fi OK, camera + AprilTag OK, but `Waiting for telemetry` (PX4 `mavlink status`: TELEM1 tx ~1.6 kB/s, rx 0). Cause: wiring ≠ course default. Fixed in software with RX 5 / TX 6 → **PASS**, telemetry 7.6/s |
| 2026-10-30 | 8 Motor test | ✅ order and direction correct for quad X |
| 2026-11-05 to 2026-11-06 | 9 RC + kill switch | ELRS paired, receiver changed SBUS → CRSF, radio calibrated; SB arm/disarm and SF motor stop confirmed with props off |
| | 10 First hover | to do |

## Different on this drone / problems hit
- **Wiring:** FC TX1 went to D4 and RX1 to D5. The course firmware sends on GPIO5 (D4), so both
  boards were transmitting on one wire. No damage; fixed by setting the pins in software.
- **Battery:** the course file assumes 3S LiHV; this drone has 2S LiPo.
