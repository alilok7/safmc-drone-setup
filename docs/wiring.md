# Wiring: ESP32 ↔ flight controller

**What this is:** how the drone's ESP32 (Seeed XIAO ESP32-S3 Sense) is cabled to the PX4 flight
controller, and how to turn *your* cable into the two pin numbers the firmware needs. Cables
differ between drones, but the pins are set in software (`config\my-drone.env` →
`flash-drone.ps1`), so **you don't need to re-solder anything.**

## What the link is
A serial (UART) link: 921600 baud, MAVLink. Four wires:

| Flight controller **TELEM1** | ESP32 (XIAO) | Note |
|---|---|---|
| TX1 (sends) | the ESP32's **RX** pad | crossed: one side's TX goes to the other's RX |
| RX1 (listens) | the ESP32's **TX** pad | |
| GND | GND | **must** be connected, or nothing works |
| +5V | 5V | powers the XIAO from the drone battery |

TELEM1 = TX1/RX1 = USART1 = `/dev/ttyS0` in PX4 (board `micoair/h743-v2`). The flight controller's
labels are printed next to the connector. TELEM2 is the optical-flow + range sensor: leave it alone.

## XIAO ESP32-S3 pads → GPIO numbers
The firmware wants **GPIO** numbers, but the board is printed with **D** names:

| Pad | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | D8 | D9 | D10 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **GPIO** | 1 | 2 | 3 | 4 | 5 | 6 | 43 | 44 | 7 | 8 | 9 |

(Seeed's XIAO ESP32S3 pinout. The Sense board's camera uses separate pins; D8-D10 are shared with its
microSD slot, so avoid them if a card is used.)

## Turn your cable into the two settings
1. Find the wire from the flight controller's **TX1**. Which D pad on the XIAO does it go to?
   Look up its GPIO → that's **`ESP_RX_PIN`**.
2. Find the wire from the flight controller's **RX1**. Which D pad? Look up its GPIO → that's
   **`ESP_TX_PIN`**.
3. Write both into `config\my-drone.env` and re-flash (`scripts\flash-drone.ps1 -Port COMy`).

## Known drones
| Drone | FC TX1 → | FC RX1 → | `ESP_RX_PIN` | `ESP_TX_PIN` | Status |
|---|---|---|---|---|---|
| Course default | D3 (GPIO4) | D4 (GPIO5) | 4 | 5 | the course firmware's default |
| 3 | D4 (GPIO5) | D5 (GPIO6) | 5 | 6 | link check PASS 2026-10-30 |

Add your drone's row here (or in its `drones\drone-<ID>.md`) once the link check passes.

## If nobody can tell how it's wired
Use the link check (setup guide phase 7) and try pin pairs, re-flashing each time (~1 min):
1. The course default: `-Tx 5 -Rx 4`.
2. The same two pins swapped: `-Tx 4 -Rx 5`.
3. Drone 3's wiring: `-Tx 6 -Rx 5`, then swapped `-Tx 5 -Rx 6`.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\flash-drone.ps1 -Port COMy -Tx 4 -Rx 5
```
Stop at the first pair that gives `RESULT: PASS`, then write it into `config\my-drone.env`. Drone 3
ran with wrong pins for a while with no damage, but keep each try short. If nothing works, check GND and the
flight controller's settings (troubleshooting.md).
