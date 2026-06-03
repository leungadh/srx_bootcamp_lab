# Juniper SRX Security Lab

Hands-on demos for four core SRX security features: SCREEN, IDP, IPsec VPN, and URL Filtering.
All demos run on the **"2 vSRX with KaliLinux"** sandbox in the
[Juniper Cloud Labs (JCL) portal](https://services.jlabs.juniper.net/jcl).

---

## Lab Access

1. Log in to [https://services.jlabs.juniper.net/jcl](https://services.jlabs.juniper.net/jcl)
2. Reserve the **"2 vSRX with KaliLinux"** sandbox blueprint
3. Once the sandbox is active, note the management IPs assigned to each VM
4. All commands in this repo are run from the **Claude/helper host** (`100.123.0.8`)

> All VMs share the password **`Juniper!1`**. SSH to the SRXes and Kali requires
> legacy algorithm flags — see [SSH Notes](#ssh-notes) below.

---

## Network Topology

```
                     ┌──────────────────────────────────────┐
                     │           Transit Link (WAN)          │
  ┌──────────┐       │  vSRX1                    vSRX2       │       ┌──────────────┐
  │   Kali   │ eth1  │  ge-0/0/1    ge-0/0/0──ge-0/0/0    ge-0/0/1  │ Linux Target │
  │ attacker │───────│──[untrust]   [trust]    [untrust]  [trust]───│   victim     │
  └──────────┘       └──────────────────────────────────────┘       └──────────────┘
  192.168.10.2/30    10.1/30  10.1/30  10.2/30  10.2/30            192.168.20.2/30
```

### Device Reference

| Device | Role | Management IP | Data IPs |
|---|---|---|---|
| vSRX1 | Firewall (attacker-side) | `100.123.12.0` | ge-0/0/1: `192.168.10.1/30` · ge-0/0/0: `10.0.0.1/30` |
| vSRX2 | Firewall (target-side) | `100.123.12.1` | ge-0/0/0: `10.0.0.2/30` · ge-0/0/1: `192.168.20.1/30` |
| Kali Linux | Attacker | `100.123.38.1` | eth1: `192.168.10.2/30` |
| Linux Target | Victim/server | `100.123.33.1` | eth1: `192.168.20.2/30` |

### Security Zones

| Device | Zone | Interface | Faces |
|---|---|---|---|
| vSRX1 | untrust | ge-0/0/1 | Kali (attacker) — SCREEN applied here |
| vSRX1 | trust | ge-0/0/0 | Transit link to vSRX2 |
| vSRX2 | untrust | ge-0/0/0 | Transit link from vSRX1 |
| vSRX2 | trust | ge-0/0/1 | Linux target |

---

## Demos

### 1. SCREEN — L3/L4 DoS & Reconnaissance Protection

**Folder:** `screen-demo/`

Demonstrates Juniper SRX SCREEN protecting against volumetric and malformed-packet
attacks: SYN flood, port scan, ICMP flood, land attack, and UDP flood. SCREEN operates
at Layer 3/4 — it inspects packet headers only, with no session state required.

**Traffic path:**
```
Kali → vSRX1 ge-0/0/1 [untrust / SCREEN] → vSRX1 trust → vSRX2 → Linux target
```

**Protections configured:** SYN flood (200 pps attack threshold), TCP port scan,
ICMP flood (1000 pps), TCP land, UDP flood (1000 pps), Ping-of-Death, and more.

**Quick start:**
```bash
bash screen-demo/configure-screen.sh   # push enhanced SCREEN config to vSRX1

# Then in separate terminals:
bash screen-demo/monitor.sh            # watch SCREEN counters live
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

Demonstrates SRX IDP detecting and blocking Layer 7 attacks that SCREEN never sees —
nikto web scans, sqlmap SQL injection probes, and hydra SSH brute-force. IDP inspects
the payload inside established TCP sessions.

> **Key point:** All three attacks have valid TCP handshakes and use legitimate
> destination ports. SCREEN lets them through. IDP reads the payload and matches
> attack signatures.

**Traffic path:**
```
Kali → vSRX1 ge-0/0/1 [untrust / IDP] → vSRX1 trust → vSRX2 → Linux target
```

**Quick start:**
```bash
bash idp-demo/configure-idp.sh        # push IDP policy to vSRX1
bash idp-demo/setup-target.sh         # start nginx + MySQL on Linux target

# Then:
bash idp-demo/monitor-idp.sh          # watch IDP hit counters live
bash idp-demo/attack-webscan.sh       # nikto web vulnerability scan
bash idp-demo/attack-sqli.sh          # sqlmap SQL injection
bash idp-demo/attack-httpbrute.sh     # hydra HTTP brute force
```

**SSH brute force scenario** (requires IDP configured):
```bash
# From Kali — targets Linux target port 22
bash idp-demo/attack-sqli.sh          # note: SSH:BRUTE-LOGIN signature
```

See [`idp-demo/DEMO.md`](idp-demo/DEMO.md) for attack-by-attack expected output and IDP signature details.

---

### 3. IPsec VPN — Site-to-Site Encrypted Tunnel

**Folder:** `vpn-demo/`

Demonstrates a route-based IKEv2/IPsec tunnel between vSRX1 and vSRX2, encrypting
all traffic crossing the WAN link (`10.0.0.0/30`). The demo shows traffic in the clear
first, then enables the tunnel and proves the same packets are now opaque ESP.

**Traffic path (with VPN):**
```
Kali → vSRX1 [encapsulate ESP] ~~~ WAN (10.0.0.0/30) ~~~ vSRX2 [decapsulate] → Linux target
```

**Tunnel parameters:** IKEv2, AES-256-CBC, SHA-256, Group 14, pre-shared key `Juniper!1`.

**Quick start:**
```bash
bash vpn-demo/remove-vpn.sh           # phase 1: show traffic in the clear
# ... capture unencrypted traffic on vSRX1 WAN interface ...

bash vpn-demo/configure-vpn.sh        # phase 2: enable VPN on both SRXes
# ... show ESP-encrypted traffic on same interface ...

bash vpn-demo/verify-vpn.sh           # show SA table, packet counts, ping test
```

> **Note:** The VPN demo adds a `vpn` zone with st0 tunnel interface and routes
> `192.168.10.0/30 ↔ 192.168.20.0/30` through the tunnel. Run
> `remove-vpn.sh` before running the URL Filtering demo.

See [`vpn-demo/DEMO.md`](vpn-demo/DEMO.md) for the three-phase walkthrough and verification checklist.

---

### 4. URL Filtering — EWF (Juniper Enhanced Web Filtering)

**Folder:** `url-filter-demo/`

Demonstrates vSRX2 intercepting outbound HTTP from the Linux target and blocking
specific website categories using the Juniper Enhanced Web Filtering (EWF) license.
Social media and streaming sites get an HTTP 403; news and general sites pass through.

> **Prerequisite:** VPN demo must not be running. Run `vpn-demo/remove-vpn.sh` first
> if the VPN is active.

**Traffic path:**
```
Linux target → vSRX2 ge-0/0/1 [trust / EWF UTM] → vSRX2 ge-0/0/0 [untrust] → vSRX1 → Kali
```

Kali runs a lightweight HTTP server that simulates the internet. The Linux target's
`/etc/hosts` maps demo domains (`www.facebook.com`, `www.cnn.com`, etc.) to Kali's IP.
vSRX2 inspects the HTTP `Host:` header to apply category-based filtering.

**Blocked categories:** Social Networking (Facebook, Instagram, Twitter),
Streaming Media (YouTube, Netflix)

**Quick start:**
```bash
bash url-filter-demo/configure-url-filter.sh   # configure vSRX2 + start Kali web server
bash url-filter-demo/run-demo.sh               # run all test requests and show results

# In a second terminal:
bash url-filter-demo/monitor-utm.sh            # watch UTM counters live
```

**Expected output:**
```
--- BLOCKED: Social Networking (www.facebook.com) ---
HTTP 403 in 0.002s

--- BLOCKED: Streaming Media (www.youtube.com) ---
HTTP 403 in 0.002s

--- ALLOWED: News (www.cnn.com) ---
HTTP 200 in ~6s

--- ALLOWED: Shopping (www.amazon.com) ---
HTTP 200 in ~6s
```

```bash
bash url-filter-demo/remove-url-filter.sh      # cleanup
```

See [`url-filter-demo/DEMO.md`](url-filter-demo/DEMO.md) for monitoring commands and config details.

---

## Demo Compatibility

| | SCREEN | IDP | VPN | URL Filter |
|---|---|---|---|---|
| **SCREEN** | — | ✅ | ✅ | ✅ |
| **IDP** | ✅ | — | ✅ | ✅ |
| **VPN** | ✅ | ✅ | — | ⚠️ |
| **URL Filter** | ✅ | ✅ | ⚠️ | — |

⚠️ VPN and URL Filter share the same routing path between vSRX1 and vSRX2. Run
`vpn-demo/remove-vpn.sh` before starting the URL filter demo. To restore the VPN
afterwards, run `vpn-demo/configure-vpn.sh`.

---

## SSH Notes

All VMs in this sandbox use older SSH key exchange and cipher algorithms. Every SSH
command must include these options:

```bash
SSH_OPTS="-o StrictHostKeyChecking=no \
  -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 \
  -oHostKeyAlgorithms=+ssh-rsa \
  -oCiphers=+aes256-cbc,aes128-cbc"

sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show version"
```

To push Junos config changes, pipe `configure / set ... / commit` over SSH:

```bash
printf 'configure
set ...
commit
exit
' | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0
```

---

## Resetting to Baseline

Each demo folder has a `remove-*.sh` script. To fully reset both SRXes to the
original base config:

```bash
# Restore vSRX1 and vSRX2 from saved base configs
SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"

cat vSRX1-base.conf | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0
cat vSRX2-base.conf | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.1
```

---

## Repository Layout

```
.
├── README.md
├── lab_network.md            # topology, IPs, zones, credentials reference
├── vSRX1-base.conf           # vSRX1 baseline Junos config (set format)
├── vSRX2-base.conf           # vSRX2 baseline Junos config (set format)
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
│   └── verify-vpn.sh
└── url-filter-demo/
    ├── DEMO.md
    ├── configure-url-filter.sh
    ├── run-demo.sh
    ├── monitor-utm.sh
    └── remove-url-filter.sh
```
