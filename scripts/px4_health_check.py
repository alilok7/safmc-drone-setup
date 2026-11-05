"""PX4 health check over USB (read-only).

What it does: connects to a PX4 flight controller on a serial port, listens for ~15 s and prints
a plain-English report: board + firmware version, flight mode, armed state, which sensors PX4
reports as present / enabled / healthy, battery, attitude, position estimate, any warning text
PX4 sends (e.g. pre-arm failures), and the parameters that matter for the ESP32 link.

Why it exists: before any flight experiment (e.g. AprilTag detection distance vs speed) we need
to know the drone's sensors and estimator are healthy and that PX4 is set up to talk to the ESP32.

Safety: it never arms, never changes mode, never writes parameters. It only sends a ground-station
heartbeat (so PX4 starts talking on USB) and read requests (version, parameter values).

Usage:  python scripts/px4_health_check.py --port COMx [--seconds 15]
"""
import argparse
import struct
import sys
import time

from pymavlink import mavutil

M = mavutil.mavlink

# Parameters worth knowing for the ESP32 <-> PX4 link and indoor (no-GPS) flight.
PARAMS = [
    "SYS_AUTOSTART",                                  # airframe
    "MAV_0_CONFIG", "MAV_0_MODE", "MAV_0_RATE",
    "MAV_1_CONFIG", "MAV_1_MODE",
    "MAV_2_CONFIG", "MAV_2_MODE",
    "SER_TEL1_BAUD", "SER_TEL2_BAUD", "SER_TEL3_BAUD",
    "EKF2_HGT_REF", "EKF2_OF_CTRL", "EKF2_RNG_CTRL", "EKF2_GPS_CTRL", "EKF2_EV_CTRL",
    "COM_RC_IN_MODE", "COM_OF_LOSS_T", "COM_ARM_WO_GPS",
    "MPC_XY_VEL_MAX", "MPC_Z_VEL_MAX_UP",
]


def sensor_names(bits):
    names = []
    for value, entry in M.enums["MAV_SYS_STATUS_SENSOR"].items():
        if value and bits & value and (value & (value - 1)) == 0:
            names.append(entry.name.replace("MAV_SYS_STATUS_", ""))
    return names


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--port", required=True, help="flight controller COM port (see scripts/find-ports.ps1)")
    ap.add_argument("--seconds", type=float, default=15)
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    link = mavutil.mavlink_connection(args.port, baud=115200, source_system=255)
    gcs_hb = lambda: link.mav.heartbeat_send(M.MAV_TYPE_GCS, M.MAV_AUTOPILOT_INVALID, 0, 0, 0)
    gcs_hb()
    hb = link.wait_heartbeat(timeout=10)
    if hb is None:
        print("No HEARTBEAT from PX4 within 10 s. Wrong port, or not a MAVLink device.")
        return 2
    print(f"Connected: system {link.target_system}, component {link.target_component}")

    # Read-only requests: firmware version and the parameters above.
    link.mav.command_long_send(link.target_system, link.target_component,
                               M.MAV_CMD_REQUEST_MESSAGE, 0,
                               M.MAVLINK_MSG_ID_AUTOPILOT_VERSION, 0, 0, 0, 0, 0, 0)
    for name in PARAMS:
        link.mav.param_request_read_send(link.target_system, link.target_component,
                                         name.encode(), -1)

    latest, texts, params, seen = {}, [], {}, set()
    end = time.time() + args.seconds
    last_hb = 0
    while time.time() < end:
        if time.time() - last_hb > 1:
            gcs_hb()
            last_hb = time.time()
        msg = link.recv_match(blocking=True, timeout=0.5)
        if msg is None:
            continue
        t = msg.get_type()
        seen.add(t)
        if t == "STATUSTEXT":
            texts.append(msg.text)
        elif t == "PARAM_VALUE":
            # PX4 sends integer parameters bit-for-bit inside the float field; unpack them.
            val = msg.param_value
            if msg.param_type in (M.MAV_PARAM_TYPE_INT32, M.MAV_PARAM_TYPE_UINT32,
                                  M.MAV_PARAM_TYPE_INT16, M.MAV_PARAM_TYPE_UINT16,
                                  M.MAV_PARAM_TYPE_INT8, M.MAV_PARAM_TYPE_UINT8):
                val = struct.unpack("<i", struct.pack("<f", val))[0]
            params[msg.param_id] = val
        elif msg.get_srcSystem() == link.target_system:
            latest[t] = msg

    print("\n=== Board / firmware ===")
    hb = latest.get("HEARTBEAT", hb)
    print("Autopilot:", M.enums["MAV_AUTOPILOT"][hb.autopilot].name,
          "| vehicle:", M.enums["MAV_TYPE"][hb.type].name)
    print("Mode:", link.flightmode, "| armed:", bool(hb.base_mode & M.MAV_MODE_FLAG_SAFETY_ARMED),
          "| state:", M.enums["MAV_STATE"][hb.system_status].name)
    v = latest.get("AUTOPILOT_VERSION")
    if v:
        sw = v.flight_sw_version
        print(f"PX4 version: {sw >> 24 & 255}.{sw >> 16 & 255}.{sw >> 8 & 255}"
              f" (git {bytes(v.flight_custom_version).hex()[:8]}), board_version {v.board_version}")

    print("\n=== Sensors (from SYS_STATUS) ===")
    s = latest.get("SYS_STATUS")
    if s:
        present = sensor_names(s.onboard_control_sensors_present)
        enabled = s.onboard_control_sensors_enabled
        health = s.onboard_control_sensors_health
        for name in present:
            bit = getattr(M, "MAV_SYS_STATUS_" + name)
            state = "OK" if health & bit else "UNHEALTHY"
            on = "enabled" if enabled & bit else "not enabled"
            print(f"  {name:<28} {on:<12} {state}")
        volts = s.voltage_battery / 1000 if s.voltage_battery != 65535 else None
        print(f"Battery: {volts} V, {s.battery_remaining}% "
              "(None/-1 = no battery or not measured; USB-only power is normal on the bench)")
    else:
        print("  no SYS_STATUS received")

    print("\n=== State estimate ===")
    a = latest.get("ATTITUDE")
    if a:
        import math
        print(f"Attitude roll {math.degrees(a.roll):.1f}°, pitch {math.degrees(a.pitch):.1f}°,"
              f" yaw {math.degrees(a.yaw):.1f}°")
    p = latest.get("LOCAL_POSITION_NED")
    print("Local position:", f"x={p.x:.2f} y={p.y:.2f} z={p.z:.2f} m" if p else "not published"
          " (normal if no position source such as optical flow / ToF is fused yet)")
    for t in ("DISTANCE_SENSOR", "OPTICAL_FLOW_RAD", "OPTICAL_FLOW", "GPS_RAW_INT",
              "ESTIMATOR_STATUS", "RC_CHANNELS"):
        print(f"{t}: {'received' if t in latest else 'not received'}")
    if "DISTANCE_SENSOR" in latest:
        print(f"  range finder: {latest['DISTANCE_SENSOR'].current_distance} cm")

    print("\n=== Parameters ===")
    for name in PARAMS:
        val = params.get(name)
        print(f"  {name:<18} {'(not on this firmware)' if val is None else round(val, 3)}")

    print("\n=== Messages from PX4 (warnings, pre-arm checks) ===")
    for line in dict.fromkeys(texts):
        print(" ", line)
    if not texts:
        print("  none")
    print("\nMessage types seen:", ", ".join(sorted(seen)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
