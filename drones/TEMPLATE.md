# Drone <ID>

**Who set it up:** <name>, on <laptop>. **Started:** <date>.

## Facts
| Item | Value |
|---|---|
| Drone ID | <ID> → ESP32 192.168.1.(200+ID), laptop 192.168.1.(100+ID) |
| Flight controller | <board, PX4 version from the health check> |
| ESP32 | <board; MAC from the flash log> |
| Wiring (FC TELEM1 → XIAO) | TX1 → <pad> (GPIO <n>), RX1 → <pad> (GPIO <n>) → `ESP_RX_PIN=<n>`, `ESP_TX_PIN=<n>` |
| Battery | <label: cells, LiPo/LiHV, mAh> |
| COM ports on this laptop | FC <COMx>, ESP32 <COMy> (can change) |
| RC | <transmitter, receiver> |

## Setup log
| Date | Phase | Result |
|---|---|---|
| | 1 Laptop tools | |
| | 3 Health check + backup | `drone-<ID>/<date>-before.params` |
| | 4 Course settings + height + battery | |
| | 5 Calibration | `drone-<ID>/<date>-calibrated.params` |
| | 6 ESP32 flash | |
| | 7 Wi-Fi link check | |
| | 8 Motor test (props off) | |
| | 9 RC + kill switch | |
| | 10 First hover | |

## Different on this drone / problems hit
- <anything that didn't match the guide, and what fixed it>
