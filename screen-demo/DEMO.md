# SRX SCREEN Demo Guide

## Overview

Demonstrates Juniper SRX SCREEN (IDS) protection against common DoS/reconnaissance attacks launched from Kali Linux toward a Linux target.

```
Kali (192.168.10.2) → [ge-0/0/1 untrust] vSRX1 [ge-0/0/0 trust] → vSRX2 → Linux (192.168.20.2)
                              SCREEN applied here
```

## SCREEN Protections Configured

| Category | Protection | Threshold |
|---|---|---|
| TCP | SYN Flood | alarm: 1024/s · attack: 200/s · src: 1024 · dst: 2048 |
| TCP | Port Scan | 5000 µs between port hits |
| TCP | Land Attack | enabled |
| TCP | SYN+FIN / FIN-no-ACK / No-Flag | enabled |
| TCP | WinNuke | enabled |
| ICMP | Flood | 1000 pps |
| ICMP | Ping-of-Death | enabled |
| ICMP | Fragment / Large | enabled |
| UDP | Flood | 1000 pps |
| UDP | Port Scan | 5000 µs |
| IP | Block Fragment | enabled |
| IP | Source Route Options | enabled |
| IP | Tear Drop | enabled |

---

## Setup (run once)

```bash
# Push enhanced SCREEN config to vSRX1
bash /root/lab/screen-demo/configure-screen.sh
```

---

## Demo Steps

### Step 1 — Verify baseline connectivity

```bash
# From this host — confirm Kali can reach the Linux target
SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.38.1 "ping -c 3 192.168.20.2"
```

Expected: 3 packets received — connectivity is up before any attack.

---

### Step 2 — Open SCREEN monitor (keep this running in a separate terminal)

```bash
bash /root/lab/screen-demo/monitor.sh
```

Or poll manually:
```bash
SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security screen statistics interface ge-0/0/1"
```

---

### Scenario A — SYN Flood

**What it is:** Attacker sends thousands of TCP SYN packets per second, exhausting connection tables.

**Attack:**
```bash
bash /root/lab/screen-demo/attack-syn-flood.sh 10
```

**What to show:** The `TCP SYN flood` counter incrementing in the monitor. SYN cookies / proxy kicks in above 200 SYNs/sec.

**Junos verification:**
```
show security screen statistics interface ge-0/0/1
show security flow session destination-prefix 192.168.20.2
```

---

### Scenario B — Port Scan

**What it is:** Attacker uses nmap to discover open ports — a common reconnaissance step.

**Attack:**
```bash
bash /root/lab/screen-demo/attack-port-scan.sh
```

**What to show:** The `TCP port scan` counter incrementing. nmap will show filtered/closed ports instead of open ones.

---

### Scenario C — ICMP Flood

**What it is:** Attacker floods the target with ICMP echo requests to consume bandwidth and CPU.

**Attack:**
```bash
bash /root/lab/screen-demo/attack-icmp-flood.sh 10
```

**What to show:** The `ICMP flood` counter incrementing above 1000 pps threshold.

---

### Scenario D — TCP Land Attack

**What it is:** Crafted packet where source IP = destination IP, causing some hosts to loop-process it.

**Attack:**
```bash
bash /root/lab/screen-demo/attack-land.sh 100
```

**What to show:** The `TCP land` counter — vSRX1 drops the packet before it reaches the target.

---

### Scenario E — UDP Flood

**What it is:** High-rate UDP packets targeting a port, saturating bandwidth.

**Attack:**
```bash
bash /root/lab/screen-demo/attack-udp-flood.sh 10
```

**What to show:** The `UDP flood` counter incrementing above 1000 pps threshold.

---

## Reset Between Demos

```bash
# Clear SCREEN counters before each scenario for a clean counter view
bash /root/lab/screen-demo/monitor.sh clear
```

---

## Key Show Commands (vSRX1)

```bash
SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"

# SCREEN hit counters per interface
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security screen statistics interface ge-0/0/1"

# SCREEN profile definition
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security screen ids-option untrust-screen"

# Active sessions (shrinks during SYN flood proxy)
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security flow session"

# Security zone assignments
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security zones"
```
