# Security Lab Network — Topology & Configuration Reference

## Topology Diagram

```
                        ┌─────────────────────────────────────────┐
                        │              Transit Link                │
  ┌──────────┐          │  vSRX1                      vSRX2        │          ┌──────────────┐
  │   Kali   │  eth1    │  ge-0/0/1      ge-0/0/0──ge-0/0/0      ge-0/0/1  eth1│ Linux Target │
  │ (attack) │──────────│──[untrust]      [trust]    [untrust]    [trust]───────│  (victim)    │
  │          │          │  192.168.10.1/30  10.0.0.1/30  10.0.0.2/30  192.168.20.1/30│          │
  └──────────┘          └─────────────────────────────────────────┘          └──────────────┘
  192.168.10.2/30                                                             192.168.20.2/30
```

## Devices

| Device | Role | Management IP | Data Plane IPs |
|---|---|---|---|
| vSRX1 | Firewall (attacker-side) | 100.123.12.0 (fxp0) | ge-0/0/1: 192.168.10.1/30 · ge-0/0/0: 10.0.0.1/30 |
| vSRX2 | Firewall (target-side) | 100.123.12.1 (fxp0) | ge-0/0/0: 10.0.0.2/30 · ge-0/0/1: 192.168.20.1/30 |
| Kali Linux | Attacker | 100.123.38.1 (eth0) | eth1: 192.168.10.2/30 |
| Linux Target | Victim/server | 100.123.33.1 (eth0) | eth1: 192.168.20.2/30 |
| Claude host | Lab controller | 100.123.0.8 | — |

## Credentials

| Device | Username | Password |
|---|---|---|
| vSRX1, vSRX2 | jcluser | Juniper!1 |
| Kali Linux | jcluser | Juniper!1 |
| Linux Target | root | Juniper!1 |

## Routing

| Device | Destination | Next-hop | Purpose |
|---|---|---|---|
| vSRX1 | 192.168.20.0/30 | 10.0.0.2 | Reach Linux target subnet |
| vSRX2 | 192.168.10.0/30 | 10.0.0.1 | Reach Kali subnet |
| Kali | 192.168.20.0/30 | 192.168.10.1 | Reach Linux target |
| Linux Target | 192.168.10.0/30 | 192.168.20.1 | Reach Kali |

Both SRXes have a default route via `100.123.0.1` on fxp0 (management only).

## Security Zones

### vSRX1
| Zone | Interface | Notes |
|---|---|---|
| untrust | ge-0/0/1.0 | Kali (attacker) faces this zone · SCREEN `untrust-screen` applied |
| trust | ge-0/0/0.0 | Transit link toward vSRX2 |

### vSRX2
| Zone | Interface | Notes |
|---|---|---|
| untrust | ge-0/0/0.0 | Transit link from vSRX1 · SCREEN `untrust-screen` applied |
| trust | ge-0/0/1.0 | Linux target faces this zone |

## Security Policies (both SRXes)

| From | To | Policy | Action |
|---|---|---|---|
| trust | trust | default-permit | permit any/any/any |
| trust | untrust | default-permit | permit any/any/any |
| trust | untrust | permit-all | permit any/any/any |
| untrust | trust | permit-all | permit any/any/any |

> The duplicate `trust→untrust` policies (default-permit + permit-all) should be cleaned up before demos.

## SCREEN Profile — `untrust-screen` (pre-configured, both SRXes)

| Category | Protection |
|---|---|
| ICMP | ping-of-death |
| IP | source-route-option, tear-drop |
| TCP | SYN flood (alarm: 1024, attack: 200, src: 1024, dst: 2048, timeout: 20s), land |

## Base Config Files

| File | Device |
|---|---|
| `vSRX1-base.conf` | vSRX1 full Junos config (Junos 24.4R1-S2.9) |
| `vSRX2-base.conf` | vSRX2 full Junos config (Junos 24.4R1-S2.9) |

## SSH Access Notes

All VMs require legacy SSH options:

```bash
SSH_OPTS="-o StrictHostKeyChecking=no \
  -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 \
  -oHostKeyAlgorithms=+ssh-rsa \
  -oCiphers=+aes256-cbc,aes128-cbc"
```

Push Junos config changes by piping set commands to SSH:

```bash
echo "configure
set ...
commit" | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@<srx-ip>
```

## Planned Demo Features

- [ ] SCREEN — SYN flood, port scan, ICMP flood protection (vSRX1 untrust zone)
- [ ] IDP — Intrusion detection/prevention on traffic from Kali
- [ ] IPsec VPN — Site-to-site tunnel between vSRX1 ge-0/0/0 ↔ vSRX2 ge-0/0/0
- [ ] URL Filtering — Control outbound HTTP/HTTPS from the trust zone
