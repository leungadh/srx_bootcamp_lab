# SRX Bootcamp Lab — Exercises

Five hands-on exercises covering the core Juniper SRX security features. Each exercise builds on the previous — complete them in order.

## Lab Topology (Quick Reference)

```
Kali Linux (attacker)          vSRX1                      vSRX2           Linux (target)
  eth1: 192.168.10.2/30  ---  ge-0/0/1: 192.168.10.1/30
                               ge-0/0/0: 10.0.0.1/30  ---  ge-0/0/0: 10.0.0.2/30
                                                            ge-0/0/1: 192.168.20.1/30  ---  eth1: 192.168.20.2/30

Management: vSRX1=100.123.12.0  vSRX2=100.123.12.1  Kali=100.123.38.1  Target=100.123.33.1
Password: Juniper!1
```

## Exercises

| # | File | Topic | What you configure | What you observe |
|---|------|-------|--------------------|-----------------|
| 1 | [Exercise_1.md](Exercise_1.md) | Base Network Configuration | vSRX1/vSRX2 base configs, Linux eth1 interfaces | End-to-end ping across the full topology |
| 2 | [Exercise_2.md](Exercise_2.md) | SCREEN (L3/L4 IDS) | Enhanced SCREEN profile on vSRX1 | Five attack types blocked — SYN flood, port scan, ICMP flood, land attack, UDP flood |
| 3 | [Exercise_3.md](Exercise_3.md) | IDP (L7 Intrusion Prevention) | IDP-DEMO policy on vSRX1 | nikto aborted, sqlmap timed out, hydra rate collapsed — with signature-level evidence |
| 4 | [Exercise_4.md](Exercise_4.md) | Site-to-Site IPsec VPN | IKEv2 route-based VPN on vSRX1 and vSRX2 | WAN traffic changes from plaintext ICMP to encrypted ESP |
| 5 | [Exercise_5.md](Exercise_5.md) | URL Filtering (EWF) | EWF UTM policy on vSRX2 | Social/streaming sites blocked instantly; news/general sites permitted via fallback |

## Prerequisites (All Exercises)

Export the SSH options once before running any commands — all lab VMs require legacy algorithm flags:

```bash
export SSH_OPTS="-o StrictHostKeyChecking=no \
  -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 \
  -oHostKeyAlgorithms=+ssh-rsa \
  -oCiphers=+aes256-cbc,aes128-cbc"
```

## Key Concepts by Exercise

**Exercise 1** establishes the data-plane topology. All subsequent exercises depend on it.

**Exercise 2 (SCREEN)** — stateless, L3/L4. Inspects packet *headers* before the session table. Catches floods, spoofed packets, and malformed headers at wire speed. Cannot see inside a valid TCP session.

**Exercise 3 (IDP)** — stateful, L7. Reassembles TCP streams and matches payload against Juniper's signature database. Catches attacks that SCREEN cannot see (nikto, sqlmap, hydra) because they arrive as normal TCP sessions with valid port numbers.

**Exercise 4 (VPN)** — encrypts the WAN link between the two sites. SCREEN and IDP protect against visible threats; VPN makes the payload invisible to anyone on the transit path.

**Exercise 5 (URL Filter)** — content policy enforcement. vSRX2 inspects the HTTP `Host:` header and blocks or permits based on URL category, using both local custom categories and the Juniper EWF cloud.

## Demo Scripts (Quick Reference)

All scripts are run from the **repo root**, not from inside the demo subdirectory.

| Demo | Configure | Run/Attack | Remove |
|------|-----------|------------|--------|
| SCREEN | `bash screen-demo/configure-screen.sh` | `bash screen-demo/attack-*.sh` | — |
| IDP | `bash idp-demo/configure-idp.sh` | `bash idp-demo/attack-*.sh` | `bash idp-demo/remove-idp.sh` |
| VPN | `bash vpn-demo/configure-vpn.sh` | `bash vpn-demo/verify-vpn.sh` | `bash vpn-demo/remove-vpn.sh` |
| URL Filter | `bash url-filter-demo/configure-url-filter.sh` | `bash url-filter-demo/run-demo.sh` | `bash url-filter-demo/remove-url-filter.sh` |

## Known Constraints

- **VPN and URL Filter conflict** — both use the 10.0.0.0/30 link with different routing. Run `bash vpn-demo/remove-vpn.sh` before Exercise 5; run `bash vpn-demo/configure-vpn.sh` to restore.
- **EWF cloud is unreachable** in this isolated lab. Custom URL categories (local match) work instantly. Uncategorized sites trigger a cloud lookup that times out (~6s) before the `log-and-permit` fallback fires — this is expected.
- **IDP policy templates** must be installed once before Exercise 3 (Step 1 of that exercise covers this).
- **CLI pings between SRX devices** (e.g., vSRX1 pinging 10.0.0.2) will fail — `host-inbound-traffic ping` is not configured on the zones. Forwarded data-plane traffic between Kali and the Linux target is unaffected.
