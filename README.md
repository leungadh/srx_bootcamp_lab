# Juniper SRX Security Lab

Hands-on demos and exercises for four core SRX security features: SCREEN, IDP, IPsec VPN, and URL Filtering. All labs run on the **"2 vSRX with KaliLinux"** sandbox in the [Juniper Cloud Labs (JCL) portal](https://services.jlabs.juniper.net/jcl).

---

## Lab Access

1. Log in to [https://services.jlabs.juniper.net/jcl](https://services.jlabs.juniper.net/jcl)
2. Reserve the **"2 vSRX with KaliLinux"** sandbox blueprint
3. Once the sandbox is active, note the management IPs assigned to each VM
4. All commands in this repo are run from the **Claude/helper host** (`100.123.0.8`)

> All VMs share the password **`Juniper!1`**. SSH to the SRXes and Kali requires legacy algorithm flags — see [SSH Notes](#ssh-notes) below.

---

## Network Topology

```
Kali Linux (attacker)          vSRX1                      vSRX2           Linux (target)
  eth1: 192.168.10.2/30  ---  ge-0/0/1: 192.168.10.1/30
                               ge-0/0/0: 10.0.0.1/30  ---  ge-0/0/0: 10.0.0.2/30
                                                            ge-0/0/1: 192.168.20.1/30  ---  eth1: 192.168.20.2/30

Management (fxp0, out-of-band):
  vSRX1=100.123.12.0   vSRX2=100.123.12.1   Kali=100.123.38.1   Target=100.123.33.1
```

### Device Reference

| Device | Role | Management IP | Data-Plane IPs |
|--------|------|---------------|----------------|
| vSRX1 | Firewall (attacker-side) | `100.123.12.0` | ge-0/0/1: `192.168.10.1/30` · ge-0/0/0: `10.0.0.1/30` |
| vSRX2 | Firewall (target-side) | `100.123.12.1` | ge-0/0/0: `10.0.0.2/30` · ge-0/0/1: `192.168.20.1/30` |
| Kali Linux | Attacker | `100.123.38.1` | eth1: `192.168.10.2/30` |
| Linux Target | Victim/server | `100.123.33.1` | eth1: `192.168.20.2/30` |

### Security Zones

| Device | Zone | Interface | Faces |
|--------|------|-----------|-------|
| vSRX1 | untrust | ge-0/0/1 | Kali (attacker) — SCREEN applied here |
| vSRX1 | trust | ge-0/0/0 | Transit WAN link to vSRX2 |
| vSRX2 | untrust | ge-0/0/0 | Transit WAN link from vSRX1 |
| vSRX2 | trust | ge-0/0/1 | Linux target |

---

## Exercises

Step-by-step lab guides are in the [`Exercise/`](Exercise/) folder. Complete them in order — each builds on the previous.

| # | Exercise | Topic |
|---|----------|-------|
| 1 | [Exercise_1.md](Exercise/Exercise_1.md) | Base network configuration — apply vSRX base configs, configure Linux interfaces, verify end-to-end connectivity |
| 2 | [Exercise_2.md](Exercise/Exercise_2.md) | SCREEN — configure the enhanced IDS profile, run five attack scenarios, observe hit counters |
| 3 | [Exercise_3.md](Exercise/Exercise_3.md) | IDP — install templates, show attacks bypass SCREEN, enable IDP and observe payload-level blocking |
| 4 | [Exercise_4.md](Exercise/Exercise_4.md) | IPsec VPN — capture plaintext traffic, build IKEv2 tunnel, verify ESP encryption on the WAN link |
| 5 | [Exercise_5.md](Exercise/Exercise_5.md) | URL Filtering — configure EWF on vSRX2, block social/streaming categories, read UTM statistics |

See [`Exercise/README.md`](Exercise/README.md) for the index, key concept summaries, and lab constraints.

---

## Demos

### 1. SCREEN — L3/L4 DoS & Reconnaissance Protection

**Folder:** `screen-demo/`

Demonstrates Juniper SRX SCREEN protecting against volumetric and malformed-packet attacks. SCREEN operates at Layer 3/4 — it inspects packet headers before the session table, with no payload inspection.

**Traffic path:**
```
Kali → vSRX1 ge-0/0/1 [untrust / SCREEN] → vSRX2 → Linux target
```

**Protections configured:** SYN flood (200 pps attack threshold), TCP port scan (5000 µs), ICMP flood (1000 pps), TCP land, UDP flood (1000 pps), Ping-of-Death, and more.

**Quick start:**
```bash
bash screen-demo/configure-screen.sh      # push enhanced SCREEN config to vSRX1

# In a second terminal:
bash screen-demo/monitor.sh               # watch SCREEN counters live

# Attack scenarios:
bash screen-demo/attack-syn-flood.sh 10
bash screen-demo/attack-port-scan.sh
bash screen-demo/attack-icmp-flood.sh 10
bash screen-demo/attack-land.sh 100
bash screen-demo/attack-udp-flood.sh 10
```

See [`screen-demo/DEMO.md`](screen-demo/DEMO.md) for the full demo guide.

---

### 2. IDP — Layer 7 Intrusion Detection & Prevention

**Folder:** `idp-demo/`

Demonstrates SRX IDP detecting and blocking Layer 7 attacks that SCREEN never sees — nikto web scans, sqlmap SQL injection, and hydra SSH brute force. IDP reassembles TCP streams and matches the payload against Juniper's signature database.

> **Key point:** All three attacks use valid TCP handshakes and legitimate destination ports. SCREEN lets them through. IDP reads the payload and matches attack signatures.

**Traffic path:**
```
Kali → vSRX1 ge-0/0/1 [untrust / IDP] → vSRX2 → Linux target
```

**Quick start:**
```bash
bash idp-demo/setup-target.sh             # start HTTP server on Linux target
bash idp-demo/configure-idp.sh            # push IDP-DEMO policy to vSRX1

# In a second terminal:
bash idp-demo/monitor-idp.sh              # watch IDP hit counters live

# Attack scenarios:
bash idp-demo/attack-webscan.sh           # nikto web vulnerability scan
bash idp-demo/attack-sqli.sh              # sqlmap SQL injection
bash idp-demo/attack-httpbrute.sh         # hydra SSH brute force

# Reset:
bash idp-demo/remove-idp.sh
```

See [`idp-demo/DEMO.md`](idp-demo/DEMO.md) for attack-by-attack expected output, IDP signature details, and the before/after contrast.

---

### 3. IPsec VPN — Site-to-Site Encrypted Tunnel

**Folder:** `vpn-demo/`

Demonstrates a route-based IKEv2/IPsec tunnel between vSRX1 and vSRX2, encrypting all traffic crossing the WAN link. The demo captures traffic in the clear first, then enables the tunnel and proves the same packets are now opaque ESP.

**Traffic path (with VPN):**
```
Kali → vSRX1 [encapsulate ESP] ~~~ WAN 10.0.0.0/30 ~~~ vSRX2 [decapsulate] → Linux target
```

**Tunnel parameters:** IKEv2 · AES-256-CBC · SHA-256 · Group 14 · PSK `Juniper!1` · Route-based (st0)

**Quick start:**
```bash
bash vpn-demo/remove-vpn.sh               # ensure clean state; capture plaintext ICMP
bash vpn-demo/configure-vpn.sh            # build tunnel on both vSRX1 and vSRX2
bash vpn-demo/verify-vpn.sh               # show SA tables, packet counts, ping test
bash vpn-demo/remove-vpn.sh               # restore direct routing when done
```

> **Note:** Run `remove-vpn.sh` before starting the URL Filtering demo — they conflict on the 10.0.0.0/30 routing.

See [`vpn-demo/DEMO.md`](vpn-demo/DEMO.md) for the three-phase walkthrough and verification checklist.

---

### 4. URL Filtering — EWF (Juniper Enhanced Web Filtering)

**Folder:** `url-filter-demo/`

Demonstrates vSRX2 intercepting outbound HTTP from the Linux target and blocking specific website categories using the EWF UTM engine. Blocked sites (social media, streaming) get an instant HTTP 403; permitted sites (news, general) pass through via EWF cloud fallback.

**Traffic path:**
```
Linux target → vSRX2 ge-0/0/1 [trust / EWF UTM] → vSRX2 ge-0/0/0 → vSRX1 → Kali (web server)
```

Kali runs a lightweight HTTP server simulating the internet. The Linux target's `/etc/hosts` maps demo domains to Kali's IP; vSRX2 inspects the HTTP `Host:` header to enforce category policy.

**Blocked:** Social Networking (Facebook, Instagram, Twitter) · Streaming Media (YouTube, Netflix)

**Quick start:**
```bash
bash url-filter-demo/configure-url-filter.sh    # configure vSRX2, start Kali web server
bash url-filter-demo/run-demo.sh                # run all test requests

# In a second terminal:
bash url-filter-demo/monitor-utm.sh             # watch UTM counters live

# Cleanup:
bash url-filter-demo/remove-url-filter.sh
```

**Expected output:**
```
--- BLOCKED: Social Networking (www.facebook.com) ---
HTTP 403 in 0.05s

--- BLOCKED: Streaming Media (www.youtube.com) ---
HTTP 403 in 0.05s

--- ALLOWED: News (www.cnn.com) ---
HTTP 200 in ~10s

--- ALLOWED: Shopping (www.amazon.com) ---
HTTP 200 in ~10s
```

> Blocked sites respond instantly (local custom category match). Allowed sites take ~10s because vSRX2 queries the EWF cloud, which is unreachable in this isolated lab — the `log-and-permit` fallback fires after the timeout.

See [`url-filter-demo/DEMO.md`](url-filter-demo/DEMO.md) for monitoring commands and config details.

---

## Demo Compatibility

| | SCREEN | IDP | VPN | URL Filter |
|--|--------|-----|-----|------------|
| **SCREEN** | — | ✅ | ✅ | ✅ |
| **IDP** | ✅ | — | ✅ | ✅ |
| **VPN** | ✅ | ✅ | — | ⚠️ |
| **URL Filter** | ✅ | ✅ | ⚠️ | — |

⚠️ VPN and URL Filter use different routing for the 10.0.0.0/30 link (tunnel vs. direct next-hop). Run `bash vpn-demo/remove-vpn.sh` before the URL filter demo; run `bash vpn-demo/configure-vpn.sh` to restore.

---

## SSH Notes

All VMs in this sandbox use older SSH key exchange and cipher algorithms. Export this variable once per session before running any commands:

```bash
export SSH_OPTS="-o StrictHostKeyChecking=no \
  -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 \
  -oHostKeyAlgorithms=+ssh-rsa \
  -oCiphers=+aes256-cbc,aes128-cbc"

# Example — run a Junos show command:
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show interfaces terse"
```

To push Junos config changes, use the `printf` pipe method:

```bash
printf 'configure
set ...
commit
exit
' | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0
```

> `cli -c '...'` does **not** work for config pushes in this lab — use the `printf` pipe method above.

---

## Resetting to Baseline

To fully reset both SRXes to the base config (Exercise 1 starting state):

```bash
# Copy base configs to the devices
sshpass -p 'Juniper!1' scp $SSH_OPTS vSRX1-base.conf jcluser@100.123.12.0:/tmp/vSRX1-base.conf
sshpass -p 'Juniper!1' scp $SSH_OPTS vSRX2-base.conf jcluser@100.123.12.1:/tmp/vSRX2-base.conf

# Load and commit
printf 'configure\nload override /tmp/vSRX1-base.conf\ncommit\nexit\n' \
  | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0

printf 'configure\nload override /tmp/vSRX2-base.conf\ncommit\nexit\n' \
  | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.1
```

---

## Repository Layout

```
.
├── README.md
├── vSRX1-base.conf               # vSRX1 baseline Junos config (curly-brace format)
├── vSRX2-base.conf               # vSRX2 baseline Junos config (curly-brace format)
├── Exercise/
│   ├── README.md                 # Exercise index and quick reference
│   ├── Exercise_1.md             # Base network configuration
│   ├── Exercise_2.md             # SCREEN IDS
│   ├── Exercise_3.md             # IDP
│   ├── Exercise_4.md             # IPsec VPN
│   └── Exercise_5.md             # URL Filtering (EWF)
├── screen-demo/
│   ├── DEMO.md
│   ├── configure-screen.sh
│   ├── monitor.sh
│   ├── attack-syn-flood.sh
│   ├── attack-port-scan.sh
│   ├── attack-icmp-flood.sh
│   ├── attack-land.sh
│   └── attack-udp-flood.sh
├── idp-demo/
│   ├── DEMO.md
│   ├── configure-idp.sh
│   ├── remove-idp.sh
│   ├── setup-target.sh
│   ├── monitor-idp.sh
│   ├── attack-webscan.sh
│   ├── attack-sqli.sh
│   └── attack-httpbrute.sh
├── vpn-demo/
│   ├── DEMO.md
│   ├── configure-vpn.sh
│   ├── remove-vpn.sh
│   ├── verify-vpn.sh
│   ├── vsrx1-config.txt
│   └── vsrx2-config.txt
└── url-filter-demo/
    ├── DEMO.md
    ├── configure-url-filter.sh
    ├── run-demo.sh
    ├── monitor-utm.sh
    ├── remove-url-filter.sh
    └── vSRX2-urlfilter-snapshot.conf
```
