# Exercise 2: SRX SCREEN (Intrusion Detection and Prevention)

## Objective

Configure the enhanced SCREEN IDS profile on vSRX1 and observe it detecting and dropping five categories of attack traffic launched from Kali Linux. By the end of this exercise, you will understand how SCREEN counters surface attack evidence and how the SRX protects the target without any manual intervention.

## Background

Juniper SRX SCREEN is a stateless first-pass IDS mechanism applied per security zone. It inspects packets entering an interface before the stateful firewall policy is evaluated. Because it operates at wire speed without session lookup, it can absorb large volumetric attacks (SYN floods, UDP floods) that would overwhelm a stateful engine.

In this lab, the SCREEN profile `untrust-screen` is attached to the **untrust zone** on vSRX1, which faces Kali Linux (the attacker) on `ge-0/0/1`.

```
Kali (192.168.10.2) → [ge-0/0/1 UNTRUST] vSRX1 [ge-0/0/0 TRUST] → vSRX2 → Linux (192.168.20.2)
                              ↑
                        SCREEN applied here
```

The base config (Exercise 1) already enables a minimal SCREEN profile. This exercise applies an enhanced profile that adds flood thresholds, port-scan detection, and malformed-packet protections.

## Prerequisites

- Exercise 1 complete: all four devices configured and end-to-end ping working
- `SSH_OPTS` exported in your shell (see Exercise 1)

---

## Step 1: Apply the Enhanced SCREEN Configuration

Run the configure script from the repo root. It connects to vSRX1 and pushes additional `set` commands on top of the base config:

```bash
bash screen-demo/configure-screen.sh
```

**What this adds to the existing SCREEN profile:**

| Category | Protection Added | Threshold |
|----------|-----------------|-----------|
| ICMP | Flood | 1000 pps |
| ICMP | Fragment | enabled |
| ICMP | Large packet | enabled |
| TCP | Port scan | 5000 µs between port hits |
| TCP | SYN+FIN / FIN-no-ACK / No-Flag | enabled |
| TCP | WinNuke | enabled |
| UDP | Flood | 1000 pps |
| UDP | Port scan | 5000 µs |
| IP | Block fragment | enabled |
| IP | Loose/strict source route | enabled |
| IP | Unknown protocol | enabled |

The script ends with `show security screen ids-option untrust-screen` — confirm the output lists all the protections above.

---

## Step 2: Verify the SCREEN Profile on vSRX1

Confirm the profile is complete and attached to the untrust zone:

```bash
# Full profile definition
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security screen ids-option untrust-screen"

# Confirm the profile is assigned to the untrust zone
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security zones security-zone untrust"
```

Expected: the zone output shows `screen: untrust-screen` under the untrust zone definition.

---

## Step 3: Open the SCREEN Monitor

Open a **second terminal** and run the monitor. It polls the SCREEN hit counters on `ge-0/0/1` every 3 seconds and will show attack detections in real time.

```bash
bash screen-demo/monitor.sh
```

Leave this running throughout the exercise. You will watch counters increment as each attack fires.

To poll manually instead:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security screen statistics interface ge-0/0/1"
```

---

## Step 4: Baseline Connectivity Check

Before any attack, confirm Kali can reach the Linux target normally:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.38.1 "ping -c 3 192.168.20.2"
```

Expected: 3 packets received, 0% loss. This establishes the pre-attack baseline.

---

## Scenario A: SYN Flood

**What it is:** The attacker sends thousands of TCP SYN packets per second to the target on port 80. Without protection, the target's TCP connection table fills up, causing a denial of service.

**How SCREEN stops it:** Once the SYN rate exceeds 200 SYNs/sec from a single source, vSRX1 engages SYN proxy — it answers SYNs on behalf of the target and only forwards legitimate completed handshakes.

**Clear counters before the attack:**
```bash
bash screen-demo/monitor.sh clear
```

**Launch the attack (runs for 10 seconds):**
```bash
bash screen-demo/attack-syn-flood.sh 10
```

**What to observe in the monitor:**
- `TCP SYN flood` counter incrementing during the 10-second window
- `TCP SYN flood drop` showing packets dropped once the attack threshold (200/s) is breached

**Additional verification on vSRX1:**
```bash
# Active session table — shrinks during SYN proxy (illegitimate SYNs never become sessions)
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security flow session destination-prefix 192.168.20.2"
```

---

## Scenario B: Port Scan

**What it is:** The attacker uses nmap to sweep ports 1–1024 at high speed, probing for services. This is typically a reconnaissance step before a targeted exploit.

**How SCREEN stops it:** The port-scan detector tracks the time between SYN packets hitting different destination ports from the same source. If hits arrive faster than 5000 µs apart, the source is flagged and subsequent packets are dropped.

**Clear counters:**
```bash
bash screen-demo/monitor.sh clear
```

**Launch the scan:**
```bash
bash screen-demo/attack-port-scan.sh
```

**What to observe:**
- `TCP port scan` counter in the monitor
- nmap output will report most ports as `filtered` rather than `open` or `closed` — evidence that the SRX is blocking the probes before they reach the target

---

## Scenario C: ICMP Flood

**What it is:** A high-rate ping flood (hping3 `--flood`) that saturates bandwidth and CPU with ICMP echo requests.

**How SCREEN stops it:** ICMP flood protection drops ICMP traffic from a source once it exceeds 1000 packets per second.

**Clear counters:**
```bash
bash screen-demo/monitor.sh clear
```

**Launch the attack (10 seconds):**
```bash
bash screen-demo/attack-icmp-flood.sh 10
```

**What to observe:**
- `ICMP flood` counter incrementing
- Note the 1000 pps threshold — packets above this rate are dropped at the SRX; the target does not see them

---

## Scenario D: TCP Land Attack

**What it is:** A crafted TCP SYN packet where the source IP is spoofed to equal the destination IP. When the target receives this, it sends a SYN-ACK to itself, potentially causing a processing loop or crash on vulnerable systems.

**How SCREEN stops it:** vSRX1 inspects each packet for matching source/destination IP addresses and drops the packet before it reaches the target.

**Clear counters:**
```bash
bash screen-demo/monitor.sh clear
```

**Launch the attack (100 packets):**
```bash
bash screen-demo/attack-land.sh 100
```

**What to observe:**
- `TCP land` counter showing the 100 dropped packets
- Because each packet is individually inspected (not rate-limited), every single land packet is dropped immediately

---

## Scenario E: UDP Flood

**What it is:** High-rate UDP packets targeting port 53, saturating the link and the target's processing capacity.

**How SCREEN stops it:** Same flood mechanism as ICMP — once UDP exceeds 1000 pps from a source, excess packets are dropped.

**Clear counters:**
```bash
bash screen-demo/monitor.sh clear
```

**Launch the attack (10 seconds):**
```bash
bash screen-demo/attack-udp-flood.sh 10
```

**What to observe:**
- `UDP flood` counter incrementing in the monitor

---

## Step 5: Final Summary Check

After all scenarios, pull a final statistics snapshot and the full profile side-by-side:

```bash
# SCREEN hit counters (cumulative since last clear)
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security screen statistics interface ge-0/0/1"

# Full SCREEN profile definition
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security screen ids-option untrust-screen"
```

**Confirm the target is still reachable** — SCREEN drops only attack traffic; legitimate traffic is unaffected:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.38.1 "ping -c 3 192.168.20.2"
```

Expected: 3 packets received. The target remained available throughout all five attack scenarios.

---

## Key Show Commands Reference

| Command | Purpose |
|---------|---------|
| `show security screen statistics interface ge-0/0/1` | Hit counters per protection type |
| `show security screen ids-option untrust-screen` | Full profile definition |
| `show security zones` | Confirm profile-to-zone binding |
| `show security flow session` | Active session table |
| `clear security screen statistics interface ge-0/0/1` | Reset counters for a clean run |

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `configure-screen.sh` shows commit error | VPN config conflict (st0 interface present) | Run `vpn-demo/remove-vpn.sh` first, then re-run |
| SCREEN counters stay at zero during flood | Attack traffic not reaching ge-0/0/1 | Verify Kali's eth1 is up and routing table points to 192.168.10.1 |
| nmap sees ports as `open` (no port-scan drops) | Scan rate below 5000 µs threshold | Use `--min-rate 1000` flag as the script already does; confirm script ran from repo root |
| monitor.sh SSH hangs | Legacy SSH negotiation timeout | Re-export `SSH_OPTS` in the monitor terminal and restart |

---

## Summary

In this exercise you:

1. Applied the enhanced SCREEN profile that adds flood thresholds and malformed-packet detections on top of the base config
2. Observed five distinct attack types — SYN flood, port scan, ICMP flood, land attack, UDP flood — each generating unique SCREEN counters on vSRX1
3. Confirmed that the Linux target remained reachable throughout, demonstrating that SCREEN selectively drops attack traffic without disrupting legitimate flows

The next exercise (IDP) builds on this topology to detect application-layer attacks that SCREEN, operating at the packet level, cannot see.
