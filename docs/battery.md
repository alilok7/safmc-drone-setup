# Battery: charging and PX4 settings

**What this is:** how we charge the drone battery (steps taught in the CDE1302 course,
2026-10-30) and how to tell PX4 what battery it has. Our drone batteries so far are **2S LiPo**
(2 cells): full = 4.2 V per cell = **8.4 V**. Check **your** label: the steps change for 3S or HV.

## Charging
1. **Battery → charger lead:** red to red (positive), black to black (negative).
2. **Charger lead → charger:** red to red, black to black. The **balance plug** (the small
   multi-pin lead on the battery) goes in the balance port with its **pin for charging on the
   rightmost side (negative side)** (as the course taught it).
3. **Battery type: LiPo** (or LiHV if the label says HV). The wrong type over- or under-charges.
4. **Mode: Charge.** **Current: 1 A**, then start.
5. **Never leave it charging unattended.**
6. Done when it beeps: 4.2 V per cell (LiPo). Unplug.

General LiPo safety: don't charge a battery that's puffy, dented or hot. Charge on a
non-flammable surface or in a LiPo bag. If it heats up or swells: stop, unplug, move it away.

## On the drone
- PX4 must know the cell count (`BAT1_N_CELLS`) or it shows the wrong % (see setup guide phase 4).
- Fly only above about **3.8 V/cell** (7.6 V for 2S). Land at about **3.5 V/cell** (7.0 V).
- QGroundControl's top bar shows voltage and %.
- Unplug the battery when not testing: the ESP32, camera and Wi-Fi drain it even when idle.
