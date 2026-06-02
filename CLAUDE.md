# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Lab Purpose

This is a Juniper SRX security lab workspace used to demo features including SCREEN, IDP, VPN, and URL filtering. Configuration and scripts live here; network state lives on the devices.

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

Run Junos operational commands directly over SSH (no CLI wrapper needed):

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show interfaces terse"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security policies"
```

To push config changes, use a heredoc with `cli -c`:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "cli -c '
configure
set ...
commit
'"
```
