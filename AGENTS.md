# AGENTS.md: instructions for an AI agent (Claude Code, Codex, others)

You've been pointed at this repo to **set up one SAFMC drone on this Windows laptop** for the
person you're working with. They may be new to drones and to the command line. You run commands
and explain; they do the physical work and give you the details only they can know.

## Start
1. If you're not inside a clone yet: clone this repo to a path **without spaces**, outside
   OneDrive, e.g. `git clone https://github.com/alilok7/safmc-drone-setup C:\dev\safmc-drone-setup`.
   Work from that folder.
2. Read [`docs/setup-guide.md`](docs/setup-guide.md) fully before doing anything. It's the
   procedure. Keep [`docs/troubleshooting.md`](docs/troubleshooting.md) and [`docs/wiring.md`](docs/wiring.md) at hand.
3. Ask the person whether this drone is partly set up already. If it is, check the earlier phases'
   **Pass when** conditions (read-only) and continue from the first that fails.
4. Tell them the plan in a few lines: the phases, roughly how long (~1-2 h, most of it
   installs), what they'll need nearby (drone, battery, USB data cable, router password, props
   off).

## How to work
- **Ask for details only when the phase needs them,** one or two questions at a time, in plain
  words. Phase 0 of the guide lists what to ask and when. **Never guess** a drone ID, a password, a
  COM port, a pin number or a battery type. If they don't know, say who might (their team) or how
  to find out (the label, a photo of the cable).
- **Say what you're about to do and why, before each command.** After it, say in one line what the
  output means.
- **Check each phase's "Pass when" before moving on.** If it fails, use troubleshooting.md: work
  through the causes in order, tell the person what you're checking, and ask them to look at the
  hardware when the answer can't be read from the laptop. If you fix something new, add it to
  troubleshooting.md in the same style.
- **Record as you go** in `drones/drone-<ID>.md` (from `drones/TEMPLATE.md`): each phase's result,
  anything different about this drone (wiring, battery, ports), and the param snapshots in
  `drones/drone-<ID>/`.

## Safety rules (not negotiable)
- **Never arm, take off, spin motors or send flight commands.** Motor test, kill-switch test and
  flying are done by the person, with props off for everything except phase 10.
- **Before any write to the drone** (`px4_param_load.py --apply`, `flash-drone.ps1 -Port`), show
  what will change and get an explicit OK. Make the backups the guide says first.
- Ask the person to confirm **props are off** before any step where the battery is plugged in.
- **Never commit or print secrets:** `config/*.env` holds the Wi-Fi password and is gitignored.
  Don't paste the password into docs, logs, commit messages or chat summaries.
- Don't change the course firmware in `external/`, and don't change PX4 settings outside the
  guide without explaining why and getting an OK.

## Git
This is a public repo. The person may not be able to push to it. Commit their drone's record
locally (`drones/drone-<ID>.md` + `drones/drone-<ID>/`). At the end, if they want to share it: fork + pull
request, or send the files to the team. Never force-push. Never commit `config/*.env`, `external/`
or `build/`.

## Done
At the end, give the person a short summary: which phases passed, what's left (usually RC or
first hover), anything unusual about their drone, and how to turn the laptop's drone network off
(`scripts\drone-net.ps1 -Off`).
