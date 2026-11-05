# SAFMC drone setup (Windows)

Set up one of our **SAFMC 2027 swarm drones** (PX4 flight controller + ESP32-S3 camera board),
step by step, from a fresh drone to its first hover. Any drone ID, any laptop. It also covers the
problems we hit along the way.

## Easiest: let an AI agent guide you
Open Claude Code or Codex on your Windows laptop and say:

> Set up my drone using https://github.com/alilok7/safmc-drone-setup

The agent clones this repo, reads [`AGENTS.md`](AGENTS.md), and walks you through it: it runs
the commands, **asks you** for what it can't know (drone number, Wi-Fi password, how your cable is
wired, your battery label), and tells you when it's your turn to do something physical. It never
arms the drone or spins the motors.

## By hand
1. Clone to a path **without spaces**, not in OneDrive:
   `git clone https://github.com/alilok7/safmc-drone-setup C:\dev\safmc-drone-setup`
2. Follow [`docs/setup-guide.md`](docs/setup-guide.md), phase by phase.

## What you need
- A Windows 10/11 laptop (admin rights for installs), ~3 GB free disk, internet.
- The drone, its battery, a USB-C **data** cable, **props off**.
- The drone router's Wi-Fi name and password (ask your team).
- For the last phases: the RC transmitter, and a netted area to fly in.

## What's here
| Path | What |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Instructions for an AI agent running this setup |
| [`docs/setup-guide.md`](docs/setup-guide.md) | **The guide**: phases 0-10, each with a pass check |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | Symptom → cause → fix |
| [`docs/wiring.md`](docs/wiring.md) | ESP32 ↔ flight-controller cable, pad → GPIO table, known drones |
| [`docs/network.md`](docs/network.md) | Laptop fixed IP on the drone Wi-Fi, internet at the same time |
| [`docs/qgroundcontrol.md`](docs/qgroundcontrol.md) | The parts of QGroundControl we use |
| [`docs/battery.md`](docs/battery.md) | Charging + battery settings |
| [`scripts/`](scripts/) | Windows scripts: install, find ports, load settings, flash ESP32, switch network |
| [`params/`](params/) | The known-good PX4 settings from the course |
| [`config/`](config/) | This laptop's Wi-Fi + drone settings (examples only; the real files are never committed) |
| [`drones/`](drones/) | One record per drone: what was done, what's different, settings snapshots |

## Where this comes from
Built from setting up drone 3 on 2026-10-30, on top of the CDE1302 course firmware and laptop
scripts ([linfengfrank/esp-everything-qgc-bridge](https://github.com/linfengfrank/esp-everything-qgc-bridge),
used as-is, pinned to a tested commit). Maintained by the team's object-detection lead.
Found a problem or a fix? Open an issue, or send it to the team.
