# Exercise 4: Site-to-Site IPsec VPN

## Objective

Build a route-based IPsec VPN tunnel between vSRX1 and vSRX2, encrypting all traffic crossing the WAN link. By the end of this exercise, you will have observed the same ping traffic appear as plain ICMP before the tunnel and as opaque ESP after, and be able to verify both IKE Phase 1 and IPsec Phase 2 security associations.

## Background

SCREEN and IDP protect against attacks visible in packet headers and payloads. VPN changes the problem: it makes the payload invisible to anyone on the WAN link between the two sites.

**The key message:** Traffic between Kali (site A, 192.168.10.0/30) and the Linux target (site B, 192.168.20.0/30) crosses the same 10.0.0.0/30 WAN link with or without VPN. Without VPN the ICMP payload is readable. With VPN, every packet is wrapped in ESP — encrypted and authenticated. The two SRX gateways handle all key negotiation and encryption transparently.

**Traffic path:**

```
Kali (192.168.10.2)
    → vSRX1 ge-0/0/1 [untrust]
    → vSRX1 ge-0/0/0 [trust]  ← tunnel starts here (10.0.0.1)
          ~~~ ESP-encrypted over WAN (10.0.0.0/30) ~~~
    → vSRX2 ge-0/0/0 [untrust] ← tunnel ends here (10.0.0.2)
    → vSRX2 ge-0/0/1 [trust]
    → Linux target (192.168.20.2)
```

**VPN parameters:**

| Parameter | Value |
|-----------|-------|
| VPN type | Route-based (st0 tunnel interface) |
| IKE version | IKEv2 |
| Authentication | Pre-shared key (`Juniper!1`) |
| IKE DH group | Group 14 (2048-bit) |
| IKE encryption | AES-256-CBC |
| IKE hash | SHA-256 |
| IPsec protocol | ESP |
| IPsec encryption | AES-256-CBC |
| IPsec auth | HMAC-SHA-256-128 |
| Tunnel endpoints | 10.0.0.1 (vSRX1) ↔ 10.0.0.2 (vSRX2) |
| Tunnel interface IPs | 172.16.0.1/30 (vSRX1) ↔ 172.16.0.2/30 (vSRX2) |
| Protected subnets | 192.168.10.0/30 ↔ 192.168.20.0/30 |

## Prerequisites

- Exercise 1 complete: all four devices configured, end-to-end ping working
- `SSH_OPTS` exported in your shell (see Exercise 1)

> **Conflict note:** The VPN and URL Filter demos both use the 10.0.0.0/30 WAN link but with different routing (st0 tunnel vs direct next-hop). If you previously ran the URL filter demo, the current state has direct routing in place — which is exactly what you need to start this exercise.

---

## Part A: Traffic in the Clear (Before VPN)

First demonstrate that without a VPN, traffic crossing the WAN link is fully readable.

**Ensure VPN is removed and direct routing is active:**

```bash
bash vpn-demo/remove-vpn.sh
```

Confirm no IKE security associations exist:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security ike security-associations"
```

Expected: empty output (no SAs).

**Send traffic from Kali to the Linux target:**

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.38.1 \
  "ping -c 5 192.168.20.2"
```

**Capture that traffic on vSRX1's WAN interface (ge-0/0/0):**

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "monitor traffic interface ge-0/0/0 count 10 no-resolve"
```

Expected output — ICMP packets fully visible:

```
...
IP 192.168.10.2 > 192.168.20.2: ICMP echo request, id 1, seq 1, length 64
IP 192.168.20.2 > 192.168.10.2: ICMP echo reply,   id 1, seq 1, length 64
...
```

The source IP, destination IP, and protocol are all readable to anyone with access to the WAN link.

---

## Step 1: Configure the VPN Tunnel

Run the configure script. It pushes IKE and IPsec config to both vSRX1 and vSRX2, then waits for Phase 1 to establish:

```bash
bash vpn-demo/configure-vpn.sh
```

The script configures each device in sequence:
1. vSRX1 — IKE proposal, policy, gateway; IPsec proposal, policy, VPN; st0 interface; vpn zone; security policies; route change
2. vSRX2 — mirror config with peer address `10.0.0.1`
3. Polls `show security ike security-associations` until `State = UP` (up to 60 seconds)
4. Prints the final Phase 1 and Phase 2 SA tables

Expected final output:

```
--- IKE Phase 1 (vSRX1) ---
Index   State  Initiator cookie  Responder cookie  Mode    Remote Address
331251  UP     97dab1804efbf1d9  d5a5e30f420eb3a8  IKEv2   10.0.0.2

--- IPsec Phase 2 (vSRX1) ---
  Total active tunnels: 1
  ID    Algorithm                  SPI      Life:sec/kb  Gateway
  <131073 ESP:aes-cbc-256/sha256  b17819a0 3599/ unlim  10.0.0.2
  >131073 ESP:aes-cbc-256/sha256  eec5927a 3599/ unlim  10.0.0.2
```

The `<` and `>` lines are the inbound and outbound Security Associations — each direction has its own SPI and key.

---

## Step 2: Verify Phase 1 (IKE)

IKE Phase 1 is the control-plane handshake where the two gateways authenticate each other and negotiate the cipher suite. Check it on vSRX1:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security ike security-associations detail"
```

Key fields to confirm:

| Field | Expected value |
|-------|---------------|
| `State` | `UP` |
| `Mode` | `IKEv2` |
| `Remote Address` | `10.0.0.2` |
| `Authentication` | `Pre-shared-keys` |
| `Encryption algorithm` | `AES-CBC-256` |
| `PRF algorithm` | `HMAC-SHA-256` |
| `DH group` | `DH-group-14` |

---

## Step 3: Verify Phase 2 (IPsec)

IPsec Phase 2 is the data-plane tunnel — the Security Associations that encrypt and authenticate actual traffic:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security ipsec security-associations detail"
```

Key fields to confirm:

| Field | Expected value |
|-------|---------------|
| `Total active tunnels` | `1` |
| `Direction` | Both `< (inbound)` and `> (outbound)` present |
| `Protocol` | `ESP` |
| `Encryption` | `aes-cbc-256` |
| `Authentication` | `hmac-sha256-128` |
| `Gateway` | `10.0.0.2` |

Confirm the route to site B now points through the tunnel interface:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show route 192.168.20.0/30"
```

Expected: `via st0.0` — traffic is routed into the tunnel, not directly to 10.0.0.2.

---

## Part B: Traffic Now Encrypted (After VPN)

Repeat the capture from Part A. Open two terminals — start the capture first, then send the ping.

**Terminal 1 — start capture on vSRX1 WAN interface:**

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "monitor traffic interface ge-0/0/0 count 10 no-resolve"
```

**Terminal 2 — send traffic from Kali:**

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.38.1 \
  "ping -c 5 192.168.20.2"
```

Expected capture output — the ICMP is gone, replaced by ESP:

```
IP 10.0.0.1 > 10.0.0.2: ESP(spi=0xb17819a0,seq=0x1), length 116
IP 10.0.0.2 > 10.0.0.1: ESP(spi=0xeec5927a,seq=0x1), length 116
```

The source and destination are now the tunnel endpoints (`10.0.0.1` / `10.0.0.2`), not the original hosts. The protocol is `ESP`. The original ICMP headers and payload are encrypted inside.

**Confirm encrypted packet counters incremented:**

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security ipsec statistics"
```

Expected (after 5-ping test):

```
ESP Statistics:
  Encrypted bytes:   780
  Decrypted bytes:   420
  Encrypted packets:   5
  Decrypted packets:   5
```

`Encrypted packets` and `Decrypted packets` should be equal — every packet sent was also received and decrypted on the far side.

---

## Step 4: Full Status Verification

Run the convenience script for a complete status snapshot:

```bash
bash vpn-demo/verify-vpn.sh
```

This shows Phase 1 SA, Phase 2 SA, IPsec statistics, a live ping through the tunnel, and the route table — all in one output.

Expected: `0% packet loss` on the ping, `via st0.0` on the route, non-zero encrypted/decrypted packet counts.

---

## Step 5: Understand the Configuration

Review the key design decisions in this VPN setup:

**Route-based vs policy-based VPN:**
This lab uses a route-based VPN (`bind-interface st0.0`). Traffic is steered into the tunnel by the routing table — the static route `192.168.20.0/30 via st0.0` is what makes the SRX encrypt it. Policy-based VPNs use traffic selectors instead; route-based is more flexible and supports dynamic routing protocols over the tunnel.

**`establish-tunnels immediately`:**
The tunnel comes up at commit time rather than waiting for the first data packet to trigger negotiation. This ensures the SA is ready before any traffic needs it.

**`host-inbound-traffic system-services ike`:**
IKE uses UDP ports 500 and 4500. Without this setting on the zone whose interface receives IKE packets, the SRX drops them silently. On vSRX1 this is added to the `trust` zone (ge-0/0/0 faces vSRX2); on vSRX2 it is added to the `untrust` zone (same interface, opposite role).

**The `vpn` zone for st0:**
Decrypted traffic exits the tunnel into st0, which sits in a dedicated `vpn` zone. Zone-based security policies (`vpn → untrust` on vSRX1, `vpn → trust` on vSRX2) then control what that decrypted traffic can reach. This provides policy control over tunnel traffic just like any other zone pair.

Inspect the applied configuration:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show configuration security ike"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show configuration security ipsec"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show interfaces st0"
```

---

## Key Show Commands Reference

| Command | Purpose |
|---------|---------|
| `show security ike security-associations` | Phase 1 state — is the IKE handshake UP? |
| `show security ike security-associations detail` | Phase 1 cipher suite and lifetime |
| `show security ipsec security-associations` | Phase 2 active tunnels and SPIs |
| `show security ipsec security-associations detail` | Phase 2 traffic selectors and byte counts |
| `show security ipsec statistics` | Encrypted/decrypted packet and byte counters |
| `show route 192.168.20.0/30` | Confirm next-hop is `st0.0` (not `10.0.0.2`) |
| `show interfaces st0 terse` | Tunnel interface state (should be `up/up`) |
| `show log kmd` | IKE negotiation log for troubleshooting |

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Phase 1 stays `DOWN` after `configure-vpn.sh` | IKE packets dropped — missing `host-inbound-traffic ike` | Check `show log kmd`; verify `show configuration security zones` on both SRXes |
| Phase 2 shows `Total active tunnels: 0` | Phase 1 not UP | Resolve Phase 1 first; Phase 2 cannot establish without it |
| Ping through tunnel fails (Phase 1+2 both UP) | Route not pointing to st0.0, or VPN zone policies missing | Check `show route 192.168.20.0/30`; verify `show security policies` includes vpn↔untrust rules on vSRX1 |
| Capture still shows ICMP (not ESP) after VPN | Traffic taking the old direct route | Confirm `show route 192.168.20.0/30` shows `st0.0`; re-run configure script if route was not updated |
| `configure-vpn.sh` fails with "st0 already exists" | Previous VPN config partially present | Run `remove-vpn.sh` first to clean state, then re-run configure |

---

## Resetting for the URL Filter Demo

The URL filter exercise (Exercise 5) requires direct routing, not tunnel routing. Run the remove script before starting it:

```bash
bash vpn-demo/remove-vpn.sh
```

To restore the VPN at any time:

```bash
bash vpn-demo/configure-vpn.sh
```

---

## Summary

In this exercise you:

1. Captured plaintext ICMP on the WAN link before the tunnel — source IP, destination IP, and payload fully visible
2. Configured a route-based IKEv2 IPsec VPN on both vSRX1 and vSRX2 using `configure-vpn.sh`
3. Verified Phase 1 (IKE SA `UP`, IKEv2, AES-256 / SHA-256 / Group 14) and Phase 2 (ESP tunnel, inbound and outbound SAs)
4. Captured the same traffic after the tunnel came up — protocol changed from `ICMP` to `ESP`, payload opaque
5. Confirmed encrypted and decrypted packet counts match, and that the route to site B points through `st0.0`

The final exercise (URL Filtering) demonstrates how vSRX2 can enforce web access policy for the target network using the Juniper Enhanced Web Filtering (EWF) engine.
