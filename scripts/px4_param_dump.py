"""Save every PX4 parameter to a file (read-only).

What it does: asks PX4 (over USB) for its full parameter list and writes it in QGroundControl's
.params format, so the file can be diffed between drones/dates or loaded back into QGC later.

Why it exists: the drone's configuration (which serial port the ESP32 uses, which sensors the
state estimator fuses, speed limits) decides whether offboard flight and our AprilTag tests work.
Keeping a dated dump in git means we always know what a drone was set to when an experiment ran.

Safety: read-only. It never writes a parameter.

Usage:  python scripts/px4_param_dump.py --port COMx --out drones/drone-<ID>/<date>-<what>.params
"""
import argparse
import struct
import sys
import time

from pymavlink import mavutil

M = mavutil.mavlink
INT_TYPES = {M.MAV_PARAM_TYPE_INT32, M.MAV_PARAM_TYPE_UINT32, M.MAV_PARAM_TYPE_INT16,
             M.MAV_PARAM_TYPE_UINT16, M.MAV_PARAM_TYPE_INT8, M.MAV_PARAM_TYPE_UINT8}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--port", required=True, help="flight controller COM port (see scripts/find-ports.ps1)")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    link = mavutil.mavlink_connection(args.port, baud=115200, source_system=255)
    link.mav.heartbeat_send(M.MAV_TYPE_GCS, M.MAV_AUTOPILOT_INVALID, 0, 0, 0)
    if link.wait_heartbeat(timeout=10) is None:
        sys.exit("No HEARTBEAT from PX4 within 10 s.")
    link.mav.param_request_list_send(link.target_system, link.target_component)

    params, total, last_rx = {}, None, time.time()
    while time.time() - last_rx < 3 and (total is None or len(params) < total):
        msg = link.recv_match(type="PARAM_VALUE", blocking=True, timeout=1)
        if msg is None:
            continue
        last_rx = time.time()
        total = msg.param_count
        val = msg.param_value
        if msg.param_type in INT_TYPES:
            val = struct.unpack("<i", struct.pack("<f", val))[0]
        params[msg.param_id] = (val, msg.param_type)

    # Re-request any that were dropped.
    if total and len(params) < total:
        for idx in range(total):
            link.mav.param_request_read_send(link.target_system, link.target_component, b"", idx)
        end = time.time() + 5
        while time.time() < end and len(params) < total:
            msg = link.recv_match(type="PARAM_VALUE", blocking=True, timeout=0.5)
            if msg:
                val = msg.param_value
                if msg.param_type in INT_TYPES:
                    val = struct.unpack("<i", struct.pack("<f", val))[0]
                params[msg.param_id] = (val, msg.param_type)

    with open(args.out, "w", newline="\n") as f:
        f.write(f"# PX4 parameter dump, {time.strftime('%Y-%m-%d %H:%M')}, port {args.port}\n")
        f.write("# Vehicle-Id Component-Id Name Value Type\n")
        for name in sorted(params):
            val, ptype = params[name]
            f.write(f"{link.target_system}\t{link.target_component}\t{name}\t{val}\t{ptype}\n")
    print(f"Saved {len(params)} of {total} parameters to {args.out}")


if __name__ == "__main__":
    main()
