# config

Settings for **this laptop**. Files ending in `.env` are **gitignored**: one holds the Wi-Fi
password, and every laptop has its own drone. Each has a committed `.env.example` next to it
showing the format. Copy the example, drop `.example` from the name, fill it in.

| File | Read by | What |
|---|---|---|
| `drone-wifi.env` | `flash-drone.ps1`, `drone-net.ps1` | Drone router name + password (baked into the ESP32 firmware) |
| `my-drone.env` | `flash-drone.ps1`, `drone-net.ps1` | This drone's ID and ESP32 pins for the flight-controller link |

On a new laptop these files are missing (they never go to GitHub). Fill them in again.
