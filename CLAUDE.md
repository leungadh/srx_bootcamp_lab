# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Lab Purpose

This is a Juniper SRX security lab workspace used to demo features including SCREEN, IDP, VPN, and URL filtering. Configuration and scripts live here; network state lives on the devices.

All four demos are implemented and tested. See `README.md` for the full lab guide.

Five hands-on exercises are in the `Exercise/` folder — see `Exercise/README.md` for the index.

## Network Topology

```
Kali (attacker)        vSRX1                    vSRX2          Linux (target)
192.168.10.2/30 --[ge-0/0/1] 192.168.10.1/30
                    10.0.0.1/30 [ge-0/0/0]--[ge-0/0/0] 10.0.0.2/30
                                               192.168.20.1/30 [ge-0/0/1]--192.168.20.2/30

Management (fxp0): vSRX1=100.123.12.0, vSRX2=100.123.12.1
Claude host: 100.123.0.8
```

## Device Access

All devices share password `Juniper!1`. SSH requires legacy algorithm flags for all VMs in this lab:

```bash
SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
sshpass -p 'Juniper!1' ssh $SSH_OPTS <user>@<host> "<command>"
```

| Device | IP | User |
|---|---|---|
| vSRX1 | 100.123.12.0 | jcluser |
| vSRX2 | 100.123.12.1 | jcluser |
| Kali Linux | 100.123.38.1 | jcluser |
| Linux target | 100.123.33.1 | root |

## Junos Commands

Run Junos operational commands directly over SSH:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show interfaces terse"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security policies"
```

To push config changes, pipe `configure / set ... / commit` via printf into SSH:

```bash
printf 'configure
set ...
commit
exit
' | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0
```

> **Note:** `cli -c '...'` does NOT work for config pushes in this lab — use the printf pipe method above.

## Current Device State (as of last session)

- **VPN tunnel**: removed from both vSRX1 and vSRX2 (run `vpn-demo/configure-vpn.sh` to restore)
- **URL filtering**: active on vSRX2 (EWF UTM policy applied to trust→untrust, custom URL categories blocking social/streaming)
- **Kali web server**: may or may not be running (python3 http.server on port 80); `configure-url-filter.sh` restarts it
- **Linux target /etc/hosts**: contains demo domain entries pointing to 192.168.10.2 (Kali)
- **vSRX2 routing**: 192.168.10.0/30 via 10.0.0.1 (direct, not via VPN)
- **vSRX1 routing**: 192.168.20.0/30 via 10.0.0.2 (direct, not via VPN)

## Known Constraints & Gotchas

- **fxp0 cannot be placed in a security zone** — Junos rejects it with "This interface cannot be configured in a zone". Internet routing for data-plane traffic must go through ge-0/0/x interfaces only.
- **EWF cloud is unreachable** in this isolated lab environment. Custom URL categories (local pattern matching) work instantly. Uncategorized URLs trigger an EWF cloud lookup that times out (~6s) before the `log-and-permit` fallback kicks in. This is expected behavior.
- **VPN and URL Filter demos conflict** — both use the 10.0.0.0/30 link but with different routing (st0 tunnel vs direct). Run `vpn-demo/remove-vpn.sh` before the URL filter demo; run `vpn-demo/configure-vpn.sh` to restore.
- **Junos config push syntax**: use `printf '...' | ssh ...` not `ssh ... "cli -c '...'"` — the latter fails with "unknown command: cli".
- **CLI pings between SRX devices** (e.g., vSRX2 pinging 10.0.0.1) fail because the trust/untrust zones have no `host-inbound-traffic ping` configured. This is normal and does not affect forwarded data-plane traffic.
- **jcluser on Kali has sudo** with password `Juniper!1` — use `echo 'Juniper!1' | sudo -S <cmd>` for root-level operations like binding to port 80.

## Demo Scripts

| Demo | Configure | Run/Attack | Remove |
|---|---|---|---|
| SCREEN | `screen-demo/configure-screen.sh` | `screen-demo/attack-*.sh` | — |
| IDP | `idp-demo/configure-idp.sh` | `idp-demo/attack-*.sh` | `idp-demo/remove-idp.sh` |
| VPN | `vpn-demo/configure-vpn.sh` | `vpn-demo/verify-vpn.sh` | `vpn-demo/remove-vpn.sh` |
| URL Filter | `url-filter-demo/configure-url-filter.sh` | `url-filter-demo/run-demo.sh` | `url-filter-demo/remove-url-filter.sh` |

## Exercises

| # | File | Topic |
|---|------|-------|
| 1 | `Exercise/Exercise_1.md` | Base network configuration — apply base configs, configure Linux interfaces, verify connectivity |
| 2 | `Exercise/Exercise_2.md` | SCREEN — enhanced IDS profile, five attack scenarios, SCREEN counter observation |
| 3 | `Exercise/Exercise_3.md` | IDP — template install, before/after contrast, nikto / sqlmap / hydra blocking |
| 4 | `Exercise/Exercise_4.md` | IPsec VPN — plaintext vs ESP capture, IKEv2 tunnel build and verification |
| 5 | `Exercise/Exercise_5.md` | URL Filtering — EWF UTM config on vSRX2, category blocking, UTM statistics |
