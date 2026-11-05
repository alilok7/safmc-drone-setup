"""Load a PX4 parameter file onto a drone, skipping board-specific values (dry run by default).

What it does: reads a QGroundControl .params file, compares it with what the drone (over USB)
currently has, and lists every setting that would change. Only with --apply does it write them,
then it reads each one back to confirm it stuck.

Why it exists: the course gave us a known-good setup from another group's drone (same board and
PX4 version). Loading it the QGC way ("Parameters -> Tools -> Load from file") would also copy
that drone's *sensor calibration* and statistics, which belong to their board, not ours. This
script skips those, so we get their configuration but keep (then redo) our own calibration.

Skipped by default (board- or transmitter-specific, or just counters):
  CAL_*            IMU / baro calibration offsets and sensor IDs of the other board
  SENS_BOARD_*_OFF level-horizon trim of the other board
  RC<n>_MIN/MAX/TRIM/REV/DZ  the other group's transmitter calibration (we redo Radio calibration)
  LND_FLIGHT_T_*, COM_FLIGHT_UUID   flight-time statistics
  _HASH_CHECK      QGC bookkeeping

Safety: without --apply nothing is written. With --apply: props must be OFF and the drone
disarmed; the script refuses if PX4 reports armed. Reboot the drone afterwards (QGC or power cycle).

Usage:
  python scripts/px4_param_load.py --port COMx --file <file.params>            # preview only
  python scripts/px4_param_load.py --port COMx --file <file.params> --apply    # write
  add --set BAT1_N_CELLS=3 to override a value from the file
"""
import argparse
import re
import struct
import sys
import time

from pymavlink import mavutil

M = mavutil.mavlink
INT_TYPES = {M.MAV_PARAM_TYPE_INT32, M.MAV_PARAM_TYPE_UINT32, M.MAV_PARAM_TYPE_INT16,
             M.MAV_PARAM_TYPE_UINT16, M.MAV_PARAM_TYPE_INT8, M.MAV_PARAM_TYPE_UINT8}
SKIP = re.compile(r"^(CAL_.*|SENS_BOARD_[XYZ]_OFF|RC\d+_(MIN|MAX|TRIM|REV|DZ)|LND_FLIGHT_T_.*"
                  r"|COM_FLIGHT_UUID|_HASH_CHECK)$")


def read_file(path):
    """name -> (value, mavlink type) from a QGC .params file."""
    out = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            p = line.split()
            if line.startswith("#") or len(p) < 5:
                continue
            out[p[2]] = (float(p[3]), int(p[4]))
    return out


def decode(msg):
    v = msg.param_value
    if msg.param_type in INT_TYPES:
        v = struct.unpack("<i", struct.pack("<f", v))[0]
    return float(v)


def read_drone(link):
    link.mav.param_request_list_send(link.target_system, link.target_component)
    got, total, last = {}, None, time.time()
    while time.time() - last < 3 and (total is None or len(got) < total):
        m = link.recv_match(type="PARAM_VALUE", blocking=True, timeout=1)
        if m:
            last, total = time.time(), m.param_count
            got[m.param_id] = decode(m)
    return got


def write_param(link, name, value, ptype):
    """Send one PARAM_SET and wait for PX4 to echo the new value back."""
    raw = struct.unpack("<f", struct.pack("<i", int(value)))[0] if ptype in INT_TYPES else value
    for _ in range(3):
        link.mav.param_set_send(link.target_system, link.target_component,
                                name.encode(), raw, ptype)
        end = time.time() + 1.5
        while time.time() < end:
            m = link.recv_match(type="PARAM_VALUE", blocking=True, timeout=0.5)
            if m and m.param_id == name:
                return abs(decode(m) - value) <= 1e-4 * max(1, abs(value))
    return False


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--port", required=True, help="flight controller COM port (see scripts/find-ports.ps1)")
    ap.add_argument("--file", required=True)
    ap.add_argument("--apply", action="store_true", help="actually write (default: preview only)")
    ap.add_argument("--set", action="append", default=[], metavar="NAME=VALUE",
                    help="override a value from the file")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    wanted = read_file(args.file)
    for item in args.set:
        name, val = item.split("=", 1)
        wanted[name] = (float(val), wanted.get(name, (0, M.MAV_PARAM_TYPE_REAL32))[1])

    link = mavutil.mavlink_connection(args.port, baud=115200, source_system=255)
    link.mav.heartbeat_send(M.MAV_TYPE_GCS, M.MAV_AUTOPILOT_INVALID, 0, 0, 0)
    hb = link.wait_heartbeat(timeout=10)
    if hb is None:
        sys.exit("No HEARTBEAT from PX4 within 10 s.")
    current = read_drone(link)
    print(f"Drone has {len(current)} params; file has {len(wanted)}.\n")

    changes, skipped, missing = [], [], []
    for name in sorted(wanted):
        val, ptype = wanted[name]
        if SKIP.match(name):
            skipped.append(name)
        elif name not in current:
            missing.append(name)   # appears only after a reboot or when a sensor is present
        elif abs(current[name] - val) > 1e-4 * max(1, abs(val)):
            changes.append((name, current[name], val, ptype))

    for name, old, new, _ in changes:
        print(f"  {name:<18} {old:g} -> {new:g}")
    print(f"\n{len(changes)} to change, {len(skipped)} skipped (board/transmitter-specific), "
          f"{len(missing)} not on this drone yet: {', '.join(missing) or '-'}")

    if not args.apply:
        print("\nPreview only. Nothing was written. Re-run with --apply to write.")
        return
    if hb.base_mode & M.MAV_MODE_FLAG_SAFETY_ARMED:
        sys.exit("Drone is ARMED. Refusing to write parameters.")

    failed = [n for n, _, new, t in changes if not write_param(link, n, new, t)]
    print(f"\nWrote {len(changes) - len(failed)}/{len(changes)}."
          + (f" FAILED: {', '.join(failed)}" if failed else ""))
    print("Now reboot the drone, then run this again: parameters that only appear after a reboot "
          "(e.g. MAV_1_*, SER_TEL2_BAUD) get set on the second pass.")


if __name__ == "__main__":
    main()
