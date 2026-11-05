# Laptop network: drone Wi-Fi + internet at the same time

**What this is:** how to set up the laptop's Wi-Fi so it can talk to the drone, and how to keep
internet (for the AI agent, GitHub, docs) while you do.

## Why the laptop needs a fixed IP
The course firmware sends drone N's telemetry to **one fixed laptop address: 192.168.1.(100+N)**,
and the drone itself is at **192.168.1.(200+N)**. So the laptop flying drone 7 must be
192.168.1.107. The drone router has no internet.

## Internet at the same time
Use **two connections**: Wi-Fi → the drone router (local only), and internet from a second adapter:
- **Phone USB tethering** (easiest): plug in the phone, turn on USB tethering. It shows up as a
  separate network adapter with internet.
- Or an Ethernet cable, or a second USB Wi-Fi adapter.

The key: on the drone Wi-Fi, set the fixed IP with **no default gateway**. Then Windows sends only
192.168.1.x traffic to the drone router and everything else out through the phone/Ethernet. (A
phone *hotspot* can't replace the router: it uses a different IP range and usually blocks
device-to-device traffic.)

## Do it: script (easiest)
1. Join the drone router's Wi-Fi.
2. Turn on phone USB tethering (optional, for internet).
3. Run (it asks for admin):
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\drone-net.ps1 -On
   ```
   It reads the drone ID from `config\my-drone.env` (or pass `-DroneId 7`), sets the IP with no
   gateway, and marks the network Private (so the firewall lets the drone data in).
4. When done: `scripts\drone-net.ps1 -Off` **before joining any other Wi-Fi**. Windows keeps the
   fixed IP on the adapter for every network until you turn it off.

## Do it: by hand
Settings → Network & internet → Wi-Fi → (your connection) / Hardware properties → IP assignment →
Edit → **Manual**, IPv4 **On**:
- IP address `192.168.1.(100+ID)`, subnet mask `255.255.255.0`
- Gateway: **leave empty**. DNS: leave empty.

Or in an admin PowerShell: `netsh interface ipv4 set address name="Wi-Fi" static 192.168.1.107 255.255.255.0 none`
(`none` = no gateway). Back to normal: `netsh interface ipv4 set address name="Wi-Fi" source=dhcp`.

## Check
`Get-NetRoute -DestinationPrefix '0.0.0.0/0'`: the default route (0.0.0.0) should point **only**
at the phone/Ethernet adapter, never at Wi-Fi. `ping 192.168.1.(200+ID)` should reply once the
drone is on.
