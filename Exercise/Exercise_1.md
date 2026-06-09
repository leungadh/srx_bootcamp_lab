# Exercise 1: Base Network Configuration

## Objective

Apply the base configuration to both vSRX firewalls and configure the data-plane interfaces on the Kali Linux and Linux target VMs. By the end of this exercise, all four devices will have IP connectivity across the lab topology.

## Lab Topology

```
Kali Linux (attacker)          vSRX1                      vSRX2           Linux (target)
  eth1: 192.168.10.2/30  ---  ge-0/0/1: 192.168.10.1/30
                               ge-0/0/0: 10.0.0.1/30  ---  ge-0/0/0: 10.0.0.2/30
                                                            ge-0/0/1: 192.168.20.1/30  ---  eth1: 192.168.20.2/30

Management (fxp0, out-of-band):
  vSRX1 = 100.123.12.0   vSRX2 = 100.123.12.1
  Kali  = 100.123.38.1   Linux target = 100.123.33.1
```

**Zone assignment:**

| Device | Interface | Address       | Zone    |
|--------|-----------|---------------|---------|
| vSRX1  | ge-0/0/1  | 192.168.10.1/30 | untrust |
| vSRX1  | ge-0/0/0  | 10.0.0.1/30     | trust   |
| vSRX2  | ge-0/0/0  | 10.0.0.2/30     | untrust |
| vSRX2  | ge-0/0/1  | 192.168.20.1/30 | trust   |

## Prerequisites

- SSH access to all four VMs via their management IPs
- The `sshpass` and `scp` utilities installed on your workstation
- Config files `vSRX1-base.conf` and `vSRX2-base.conf` present in the repo root

All VMs share the password `Juniper!1`. Because these are older VMs, SSH requires legacy algorithm flags. Export this variable once before running any commands in this exercise:

```bash
export SSH_OPTS="-o StrictHostKeyChecking=no \
  -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 \
  -oHostKeyAlgorithms=+ssh-rsa \
  -oCiphers=+aes256-cbc,aes128-cbc"
```

---

## Step 1: Apply Base Configuration to vSRX1

The base config sets interface addresses, security zones, permissive policies, and a static route toward the target network.

**1a. Copy the config file to vSRX1:**

```bash
sshpass -p 'Juniper!1' scp $SSH_OPTS vSRX1-base.conf jcluser@100.123.12.0:/tmp/vSRX1-base.conf
```

**1b. Load and commit the configuration:**

```bash
printf 'configure
load override /tmp/vSRX1-base.conf
commit
exit
' | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0
```

Expected output ends with `commit complete`.

**What this config applies to vSRX1:**

| Setting | Value |
|---------|-------|
| ge-0/0/0 address | 10.0.0.1/30 (trust zone) |
| ge-0/0/1 address | 192.168.10.1/30 (untrust zone) |
| Static route | 192.168.20.0/30 via 10.0.0.2 |
| Security policies | permit-all in both directions |
| SCREEN profile | Applied to untrust zone |

---

## Step 2: Apply Base Configuration to vSRX2

**2a. Copy the config file to vSRX2:**

```bash
sshpass -p 'Juniper!1' scp $SSH_OPTS vSRX2-base.conf jcluser@100.123.12.1:/tmp/vSRX2-base.conf
```

**2b. Load and commit the configuration:**

```bash
printf 'configure
load override /tmp/vSRX2-base.conf
commit
exit
' | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.1
```

**What this config applies to vSRX2:**

| Setting | Value |
|---------|-------|
| ge-0/0/0 address | 10.0.0.2/30 (untrust zone) |
| ge-0/0/1 address | 192.168.20.1/30 (trust zone) |
| Static route | 192.168.10.0/30 via 10.0.0.1 |
| Security policies | permit-all in both directions |
| SCREEN profile | Applied to untrust zone |

---

## Step 3: Configure Kali Linux eth1

Kali connects to vSRX1's untrust-facing interface. Configure eth1 with a static address and add routes so Kali can reach the target network through both SRXs.

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.38.1 \
  "echo 'Juniper!1' | sudo -S ip addr add 192.168.10.2/30 dev eth1 && \
   echo 'Juniper!1' | sudo -S ip link set eth1 up && \
   echo 'Juniper!1' | sudo -S ip route add 192.168.20.0/30 via 192.168.10.1"
```

> **Note:** These `ip` commands configure the interface for the current session only. They are sufficient for the lab; no persistent network config is needed.

---

## Step 4: Configure Linux Target eth1

The Linux target connects to vSRX2's trust-facing interface.

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@100.123.33.1 \
  "ip addr add 192.168.20.2/30 dev eth1 && \
   ip link set eth1 up && \
   ip route add 192.168.10.0/30 via 192.168.20.1"
```

---

## Step 5: Verify Connectivity

Run these checks in order. Each one builds on the previous.

### 5a. Verify vSRX1 interfaces and routing

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show interfaces terse"
```

Expected — ge-0/0/0.0 and ge-0/0/1.0 should show `up` with their assigned addresses:

```
Interface               Admin Link Proto    Local                 Remote
ge-0/0/0.0              up    up   inet     10.0.0.1/30
ge-0/0/1.0              up    up   inet     192.168.10.1/30
```

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show route"
```

Look for the static route `192.168.20.0/30` pointing to `10.0.0.2`.

### 5b. Verify vSRX2 interfaces and routing

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.1 "show interfaces terse"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.1 "show route"
```

Expected — ge-0/0/0.0 at `10.0.0.2/30`, ge-0/0/1.0 at `192.168.20.1/30`, static route `192.168.10.0/30` via `10.0.0.1`.

### 5c. Verify security zones

Confirm each interface is in the correct zone on both devices:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security zones"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.1 "show security zones"
```

### 5d. Verify Kali Linux interface

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.38.1 "ip addr show eth1"
```

Expected: `192.168.10.2/30` assigned to eth1.

### 5e. Ping from Kali to vSRX1 (first hop)

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.38.1 "ping -c 3 192.168.10.1"
```

Expected: 3 packets transmitted, 3 received, 0% packet loss.

### 5f. Ping from Kali to Linux target (end-to-end)

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.38.1 "ping -c 3 192.168.20.2"
```

Expected: 3 packets transmitted, 3 received, 0% packet loss. This validates the full path: Kali → vSRX1 → vSRX2 → Linux target.

### 5g. Ping from Linux target back to Kali

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@100.123.33.1 "ping -c 3 192.168.10.2"
```

Expected: 3 packets received. This confirms return-path routing is working.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `commit complete` not seen after load | Config syntax error | Run `show | compare` before committing to check for errors |
| ge-0/0/x shows `down` in `show interfaces terse` | Interface physically down in hypervisor | Check hypervisor port group / cable assignment |
| Ping to 192.168.10.1 fails from Kali | eth1 not up or wrong address | Re-run Step 3; check `ip addr show eth1` |
| Ping across SRXs fails, but first-hop ping works | Static route missing or wrong | Check `show route` on both SRXs; re-commit config |
| `load override` returns "unknown command" | SCP failed silently | Verify the file exists on the device: `file list /tmp/` |

> **Note:** Do not ping between vSRX1 and vSRX2 directly from the Junos CLI (e.g., `ping 10.0.0.2` on vSRX1). The trust/untrust zones do not have `host-inbound-traffic ping` configured, so CLI-originated pings to the opposite SRX will fail. Forwarded data-plane traffic (Step 5f/5g) is unaffected.

---

## Summary

After completing this exercise:

- vSRX1 has data-plane interfaces up, zones assigned, and a static route to the 192.168.20.0/30 network
- vSRX2 has data-plane interfaces up, zones assigned, and a static route to the 192.168.10.0/30 network
- Kali Linux can reach the Linux target through both SRX firewalls
- The lab topology is fully operational and ready for the security feature demos (SCREEN, IDP, VPN, URL Filtering)
