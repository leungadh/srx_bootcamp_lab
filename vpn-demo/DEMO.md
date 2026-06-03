# SRX VPN Demo — Site-to-Site IPsec Tunnel (vSRX1 ↔ vSRX2)

## Overview

This demo shows how SRX builds an IPsec VPN tunnel between two sites, encrypting all
traffic crossing the WAN link. SCREEN and IDP inspect packets — VPN hides what's inside them.

> **Key message:** Traffic between Kali (site A) and the Linux target (site B) crosses the
> same 10.0.0.0/30 WAN link with or without VPN. Without VPN the payload is visible. With
> VPN, every packet is wrapped in ESP — encrypted and authenticated end-to-end. The SRX
> gateways do all the key management and encryption transparently.

### Traffic Path

```
Kali (192.168.10.2)
    → vSRX1 ge-0/0/1  [untrust zone]
    → vSRX1 ge-0/0/0  [trust zone]  ← IPsec tunnel starts here (10.0.0.1)
         ~~~ encrypted ESP over WAN (10.0.0.0/30) ~~~
    → vSRX2 ge-0/0/0  [untrust zone] ← IPsec tunnel ends here (10.0.0.2)
    → vSRX2 ge-0/0/1  [trust zone]
    → Linux target (192.168.20.2)
```

### VPN Parameters

| Parameter | Value |
|---|---|
| VPN type | Route-based IPsec (st0 tunnel interface) |
| IKE version | IKEv2 |
| IKE auth | Pre-shared key (`Juniper!1`) |
| IKE DH group | Group 14 (2048-bit) |
| IKE encryption | AES-256-CBC |
| IKE hash | SHA-256 |
| IPsec protocol | ESP |
| IPsec encryption | AES-256-CBC |
| IPsec auth | HMAC-SHA-256-128 |
| Tunnel endpoints | 10.0.0.1 (vSRX1) ↔ 10.0.0.2 (vSRX2) |
| Tunnel IPs | 172.16.0.1/30 (vSRX1) ↔ 172.16.0.2/30 (vSRX2) |
| Protected traffic | 192.168.10.0/30 ↔ 192.168.20.0/30 |

---

## Demo Flow

### Phase 1: Show traffic in the clear (no VPN)

Remove VPN so traffic flows unencrypted over the WAN link:

```bash
bash /root/lab/vpn-demo/remove-vpn.sh
```

Ping from Kali to Linux target to generate traffic:

```bash
SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.38.1 "ping -c 3 192.168.20.2" 2>/dev/null
```

Capture traffic on vSRX1's WAN interface to show it in clear:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
    "monitor traffic interface ge-0/0/0 count 10 no-resolve" 2>/dev/null
```

Expected: ICMP packets visible in plain text — protocol shows `ICMP`, payload readable.

**Talk track:** "This is a plain ICMP echo. Anyone on the WAN link can see the source,
destination, and payload. No encryption, no authentication."

---

### Phase 2: Enable VPN

```bash
bash /root/lab/vpn-demo/configure-vpn.sh
```

This pushes IKE/IPsec config to both vSRX1 and vSRX2, waits for Phase 1 to come UP,
then shows the SA table.

Expected output:
```
=== IKE Phase 1 Security Associations (vSRX1) ===
Index   State  Initiator cookie  Responder cookie  Mode    Remote Address
331251  UP     97dab1804efbf1d9  d5a5e30f420eb3a8  IKEv2   10.0.0.2

=== IPsec Phase 2 Security Associations (vSRX1) ===
  Total active tunnels: 1
  ID    Algorithm       SPI      Life:sec/kb  Gateway
  <131073 ESP:aes-cbc-256/sha256 b17819a0 3599/ unlim  10.0.0.2
  >131073 ESP:aes-cbc-256/sha256 eec5927a 3599/ unlim  10.0.0.2
```

**Talk track:** "Phase 1 is the IKE handshake — the two SRXes authenticate each other and
negotiate cipher parameters. Phase 2 is the IPsec tunnel itself. The `<` and `>` lines are
the inbound and outbound Security Associations — each direction has its own SPI and key."

---

### Phase 3: Show traffic is now encrypted

Ping again while capturing on the WAN interface:

```bash
SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"

# In one terminal — start capture on vSRX1 WAN interface
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
    "monitor traffic interface ge-0/0/0 count 10 no-resolve" 2>/dev/null &

# In another terminal — send traffic from Kali
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.38.1 \
    "ping -c 5 192.168.20.2" 2>/dev/null
```

Expected on the WAN capture: protocol shows `ESP` — no ICMP visible, no readable payload.

Show encrypted packet count climbed:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
    "show security ipsec statistics" 2>/dev/null
```

Expected:
```
ESP Statistics:
  Encrypted bytes:   780
  Decrypted bytes:   420
  Encrypted packets:   5
  Decrypted packets:   5
```

**Talk track:** "Same source, same destination, same WAN link — but now the protocol is ESP.
The ICMP payload is gone, replaced by opaque ciphertext. The SPI in each packet points to
the Security Association that holds the decryption key — and only the two SRX gateways
have those keys."

---

### Phase 4: Verify full status (convenience script)

```bash
bash /root/lab/vpn-demo/verify-vpn.sh
```

Shows Phase 1, Phase 2, ESP stats, a live ping, and the route table confirming traffic
goes via st0.0 (the tunnel interface).

---

## Verification Checklist

**1. Phase 1 (IKE) is UP**
```bash
SSH_OPTS="..."
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
    "show security ike security-associations" 2>/dev/null
```
Expected: `State = UP`, `Mode = IKEv2`, `Remote Address = 10.0.0.2`

**2. Phase 2 (IPsec) has an active tunnel**
```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
    "show security ipsec security-associations" 2>/dev/null
```
Expected: `Total active tunnels: 1`, inbound and outbound ESP SAs with matching SPIs

**3. Traffic is encrypted**
```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
    "show security ipsec statistics" 2>/dev/null
```
Expected: `Encrypted packets` and `Decrypted packets` non-zero and equal after a ping

**4. Route points to tunnel interface**
```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
    "show route 192.168.20.0/30" 2>/dev/null
```
Expected: `via st0.0`

**5. End-to-end connectivity works**
```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.38.1 \
    "ping -c 5 192.168.20.2" 2>/dev/null
```
Expected: 0% packet loss

If the tunnel is DOWN, check: `show log kmd` on vSRX1 for IKE negotiation errors.

---

## VPN Policy Configuration Reference

**vSRX1:**
```
# IKE Phase 1
set security ike proposal IKE-PROP authentication-method pre-shared-keys
set security ike proposal IKE-PROP dh-group group14
set security ike proposal IKE-PROP authentication-algorithm sha-256
set security ike proposal IKE-PROP encryption-algorithm aes-256-cbc
set security ike proposal IKE-PROP lifetime-seconds 86400
set security ike policy IKE-POL mode main
set security ike policy IKE-POL proposals IKE-PROP
set security ike policy IKE-POL pre-shared-key ascii-text "Juniper!1"
set security ike gateway IKE-GW ike-policy IKE-POL
set security ike gateway IKE-GW address 10.0.0.2
set security ike gateway IKE-GW external-interface ge-0/0/0.0
set security ike gateway IKE-GW version v2-only

# IPsec Phase 2
set security ipsec proposal IPSEC-PROP protocol esp
set security ipsec proposal IPSEC-PROP authentication-algorithm hmac-sha-256-128
set security ipsec proposal IPSEC-PROP encryption-algorithm aes-256-cbc
set security ipsec proposal IPSEC-PROP lifetime-seconds 3600
set security ipsec policy IPSEC-POL proposals IPSEC-PROP
set security ipsec vpn VPN-DEMO bind-interface st0.0
set security ipsec vpn VPN-DEMO ike gateway IKE-GW
set security ipsec vpn VPN-DEMO ike ipsec-policy IPSEC-POL
set security ipsec vpn VPN-DEMO establish-tunnels immediately

# Tunnel interface and zone
set interfaces st0 unit 0 family inet address 172.16.0.1/30
set security zones security-zone vpn interfaces st0.0
set security zones security-zone trust host-inbound-traffic system-services ike

# Security policies (Kali ↔ Linux via tunnel)
set security policies from-zone untrust to-zone vpn policy VPN-PERMIT match source-address any
set security policies from-zone untrust to-zone vpn policy VPN-PERMIT match destination-address any
set security policies from-zone untrust to-zone vpn policy VPN-PERMIT match application any
set security policies from-zone untrust to-zone vpn policy VPN-PERMIT then permit
set security policies from-zone vpn to-zone untrust policy VPN-RETURN match source-address any
set security policies from-zone vpn to-zone untrust policy VPN-RETURN match destination-address any
set security policies from-zone vpn to-zone untrust policy VPN-RETURN match application any
set security policies from-zone vpn to-zone untrust policy VPN-RETURN then permit

# Route interesting traffic through tunnel
set routing-options static route 192.168.20.0/30 next-hop st0.0
```

**vSRX2:** mirror config — peer address is `10.0.0.1`, st0 IP is `172.16.0.2/30`,
IKE is enabled on the `untrust` zone (not trust), policies are vpn↔trust.

### Key design decisions

- **Route-based VPN (st0)** — traffic is routed to the tunnel interface. More flexible
  than policy-based: no traffic selectors to manage, supports dynamic routing over the tunnel.
- **`establish-tunnels immediately`** — tunnel comes up at commit time rather than waiting
  for the first packet. Ensures the SA is ready before the demo starts.
- **`host-inbound-traffic system-services ike`** — tells the SRX to accept IKE (UDP 500/4500)
  on that zone's interfaces. On vSRX1 this is the trust zone (ge-0/0/0); on vSRX2 it is
  the untrust zone (ge-0/0/0). Without this, IKE packets are dropped silently.
- **vpn zone for st0** — decrypted traffic exits st0 into the vpn zone. Zone-based policies
  then control what that traffic can reach (untrust on vSRX1, trust on vSRX2).

---

## Reset

```bash
# Remove VPN (restores direct routing)
bash /root/lab/vpn-demo/remove-vpn.sh

# Re-apply VPN
bash /root/lab/vpn-demo/configure-vpn.sh
```

---

## Useful Show Commands

```
# Phase 1 status
show security ike security-associations

# Phase 1 detail (includes cipher suite, lifetime remaining)
show security ike security-associations detail

# Phase 2 status
show security ipsec security-associations

# Phase 2 detail (includes traffic selectors, byte counts)
show security ipsec security-associations detail

# Encrypted/decrypted packet counts
show security ipsec statistics

# IKE negotiation log (troubleshooting)
show log kmd

# Route table (confirm st0.0 is next-hop)
show route

# Tunnel interface state
show interfaces st0 terse
```

---

## Files in This Directory

| File | Purpose |
|---|---|
| `DEMO.md` | This guide |
| `vsrx1-config.txt` | Full vSRX1 config snapshot (set format) with VPN active |
| `vsrx2-config.txt` | Full vSRX2 config snapshot (set format) with VPN active |
| `configure-vpn.sh` | Push VPN config to vSRX1 and vSRX2 |
| `remove-vpn.sh` | Remove VPN, restore direct routing |
| `verify-vpn.sh` | Show tunnel status, stats, and ping test |
