# SRX IDP Demo — HTTP Attack Detection (nikto + sqlmap)

## Overview

This demo shows how SRX IDP (Intrusion Detection and Prevention) detects and blocks Layer 7
HTTP attacks that bypass SCREEN entirely. SCREEN operates at L3/L4 — it sees only packet
headers. IDP inspects the **payload** inside a valid TCP session.

> **Key message:** A nikto probe or sqlmap payload has a normal TCP handshake, correct packet
> size, and a valid destination port. SCREEN lets it through. IDP reads the HTTP request,
> matches attack signatures, and drops the connection.

### Traffic Path

```
Kali (192.168.10.2) eth1
    → vSRX1 ge-0/0/1  [untrust zone] ← IDP inspects here
    → vSRX1 ge-0/0/0  [trust zone]
    → vSRX2 ge-0/0/0
    → vSRX2 ge-0/0/1
    → Linux target (192.168.20.2:80)
```

### What IDP Detects — nikto (web vulnerability scan)

| Signature | Hits (typical) | What it catches |
|-----------|---------------|-----------------|
| `HTTP:INVALID:CONTENT_UNEXPECTED` | ~54 | Malformed/unexpected HTTP content in nikto probes |
| `HTTP:AUDIT:URL` | ~27 | Suspicious URL patterns, directory probing |
| `HTTP:REMOTE-URL-IN-VAR` | ~27 | Remote file inclusion attempts in URL parameters |
| `HTTP:DIR:PARAMETER-TRAVERSE-1` | ~2 | Directory traversal (`../`) attempts |

### What IDP Detects — sqlmap (SQL injection)

| Signature | Hits (typical) | What it catches |
|-----------|---------------|-----------------|
| `HTTP:INVALID:CONTENT_UNEXPECTED` | ~69 | Malformed HTTP in sqlmap probes |
| `HTTP:AUDIT:URL` | ~42 | Suspicious URL patterns |
| `HTTP:REMOTE-URL-IN-VAR` | ~27 | Remote file inclusion in parameters |
| `HTTP:SQL:INJ:SQLMAP-ACTIVITY` | ~15 | **sqlmap tool fingerprint specifically** |
| `HTTP:SQL:INJ:REQ-VAR-1` | ~10 | SQL injection in request variables |
| `HTTP:SQL:INJ:GENERIC` | ~8 | Generic SQL injection payloads |
| `HTTP:SQL:INJ:REQ-VAR-5` | ~8 | SQL injection variant |
| `HTTP:SQL:INJ:AND-NUMBER-EQUALS` | ~2 | Boolean-based blind SQL injection |
| `HTTP:DIR:PARAMETER-TRAVERSE-1` | ~2 | Directory traversal attempts |

---

## Pre-Requisites (One-Time Setup)

### 1. Install IDP policy templates on vSRX1

Policy templates are required for predefined attack groups to compile correctly. Without them
the IDP policy loads but produces no rules and blocks nothing.

```bash
SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"

# Download templates from Juniper cloud (requires internet on fxp0)
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
    "request security idp security-package download policy-templates"

# Poll until done
until sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
    "request security idp security-package download status" 2>/dev/null | grep -q "Done"; do
  sleep 5; done

# Install
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
    "request security idp security-package install policy-templates"

until sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
    "request security idp security-package install status" 2>/dev/null | grep -q "Done"; do
  sleep 5; done

# Verify — all three fields should show version 3912 (or current)
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
    "show security idp security-package-version"
```

Expected output:
```
Attack database version:3912(Minor, ...)
Detector version       :12.6.180250827
Policy template version:3912            ← must not be N/A
```

### 2. Note on supported attack groups on this vSRX

Not all predefined attack groups compile to IPv4 rules on this vSRX/detector version.
Tested results:

| Attack Group | Works on this vSRX |
|---|---|
| `HTTP - All` | ✅ Yes |
| `SSH - All` | ✅ Yes |
| `FTP - All` | ✅ Yes |
| `DNS - All` | ✅ Yes |
| `SCAN - All` | ❌ No (static persistent context — no IPv4 rules) |
| `All Attacks` | ❌ No (OOM — too large for vSRX memory) |

---

## Demo Setup

### Step 1: Start the web target on Linux

```bash
bash /root/lab/idp-demo/setup-target.sh
```

This kills any existing HTTP server, opens port 80 in firewalld, creates a demo web page
in `/tmp/www/`, and starts `python3 -m http.server 80`. Ends with a connectivity check
from Kali confirming end-to-end reachability.

Expected output:
```
HTTP 200 from 192.168.20.2 in 0.012s
Target ready. Web server running on 192.168.20.2:80
```

To start the server manually on the Linux target:
```bash
SSH_OPTS="..."
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@100.123.33.1 \
    "mkdir -p /tmp/www && cd /tmp/www && nohup python3 -m http.server 80 > /tmp/httpserver.log 2>&1 &"
# Open port in firewalld if not already open
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@100.123.33.1 \
    "firewall-cmd --add-port=80/tcp --zone=public --permanent --quiet && firewall-cmd --reload --quiet"
```

### Step 2: Open the IDP monitor (separate terminal)

```bash
bash /root/lab/idp-demo/monitor-idp.sh
```

Polls `show security idp attack table` on vSRX1 every 3 seconds. Leave this running
throughout the demo so the audience sees hit counters increment in real time.

---

## Demo Flow

### Phase 1: Show attacks succeed WITHOUT IDP

First demonstrate that attacks run freely with no protection.

```bash
# Remove IDP so there is no active policy
bash /root/lab/idp-demo/remove-idp.sh
```

Expected: `Policy Name:` is blank or absent.

```bash
# Run nikto — completes normally, many findings, zero IDP hits on monitor
bash /root/lab/idp-demo/attack-webscan.sh

# Run sqlmap — probes complete, no connection resets
bash /root/lab/idp-demo/attack-sqli.sh
```

**Talk track:** "Both tools run to completion. The monitor shows zero IDP hits. The firewall
sees valid TCP sessions to port 80 and passes them. There is no packet-header anomaly to catch."

---

### Phase 2: Enable IDP

```bash
bash /root/lab/idp-demo/configure-idp.sh
```

This pushes the `IDP-DEMO` policy to vSRX1 and waits ~20 seconds for the policy to compile
and load. Confirm with:

```bash
SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security idp status" 2>/dev/null | grep "Policy Name"
```

Expected: `Policy Name : IDP-DEMO`

---

### Phase 3: Scenario 1 — Web Scan Blocked (nikto)

```bash
# Clear counters so the monitor starts from zero
bash /root/lab/idp-demo/monitor-idp.sh clear

bash /root/lab/idp-demo/attack-webscan.sh
```

**What to observe:**
- The monitor shows hit counters climbing in real time
- nikto output ends with: `ERROR: Error limit (20) reached for host, giving up.`
- nikto aborts early — IDP drops connections the moment a signature fires

**Show the attack table:**
```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security idp attack table" 2>/dev/null
```

Example output:
```
IDP attack statistics:

  Attack name                                  #Hits
  HTTP:INVALID:CONTENT_UNEXPECTED              54
  HTTP:AUDIT:URL                               27
  HTTP:REMOTE-URL-IN-VAR                       27
  HTTP:DIR:PARAMETER-TRAVERSE-1                2
```

---

### Phase 4: Scenario 2 — SQL Injection Blocked (sqlmap)

```bash
bash /root/lab/idp-demo/monitor-idp.sh clear

bash /root/lab/idp-demo/attack-sqli.sh
```

**What to observe:**
- sqlmap immediately reports connection timeouts on every probe
- sqlmap warns: `there is a possibility that the target (or WAF/IPS) is dropping 'suspicious' requests`
- sqlmap gives up: `there seems to be a continuous problem with connection to the target`
- The attack table shows SQL-specific signatures on top of the general HTTP ones

**Show the attack table:**
```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security idp attack table" 2>/dev/null
```

Example output:
```
IDP attack statistics:

  Attack name                                  #Hits
  HTTP:INVALID:CONTENT_UNEXPECTED              69
  HTTP:AUDIT:URL                               42
  HTTP:REMOTE-URL-IN-VAR                       27
  HTTP:SQL:INJ:SQLMAP-ACTIVITY                 15
  HTTP:SQL:INJ:REQ-VAR-1                       10
  HTTP:SQL:INJ:GENERIC                         8
  HTTP:SQL:INJ:REQ-VAR-5                       8
  HTTP:DIR:PARAMETER-TRAVERSE-1                2
  HTTP:SQL:INJ:AND-NUMBER-EQUALS               2
```

**Talk track:** "`HTTP:SQL:INJ:SQLMAP-ACTIVITY` is a signature that specifically fingerprints
sqlmap's request pattern — IDP identified not just that SQL injection was attempted, but which
tool was used to attempt it."

---

### Verification Checklist

Use all three of these together to confirm IDP is working. Each proves a different layer —
policy loaded, signatures matched, attack actually stopped.

**1. Policy is loaded and active (firewall side)**
```bash
SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security idp status" 2>/dev/null | grep -E "Policy Name|State of IDP"
```
Expected:
```
State of IDP: Default,  Up since: ...
  Policy Name : IDP-DEMO
```

**2. Signatures fired (firewall side)**
```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security idp attack table" 2>/dev/null
```
Expected: one or more signature names with a non-zero hit count.
If the table is empty after running an attack, check `show log idpd_err` for
`no rules for IPv4` — this indicates a policy template or zone-name problem.

**3. Attack was stopped (attacker side)**

- **nikto:** output ends with `ERROR: Error limit (20) reached for host, giving up. Last error: error reading HTTP response`
- **sqlmap:** output shows repeated `[CRITICAL] connection timed out` and the warning `there is a possibility that the target (or WAF/IPS) is dropping 'suspicious' requests`

The connection reset/timeout errors confirm IDP is tearing down TCP sessions on signature match.

**Quick one-liner to check policy and hits:**
```bash
SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
echo "--- Active policy ---"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security idp status" 2>/dev/null | grep "Policy Name"
echo "--- Attack hits ---"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 "show security idp attack table" 2>/dev/null
```

---

### Phase 5: The Contrast (Powerful Closer)

Remove IDP and re-run to show the difference:

```bash
bash /root/lab/idp-demo/remove-idp.sh
bash /root/lab/idp-demo/attack-sqli.sh      # sqlmap runs freely, no drops
bash /root/lab/idp-demo/configure-idp.sh    # re-enable for reset
```

**Talk track:** "Same tool, same target, same firewall policy — the only difference is IDP.
Without it sqlmap enumerates the target freely. With it every probe gets a connection reset
before any data is exchanged."

---

## IDP Policy Configuration Reference

The policy applied by `configure-idp.sh`:

```
# IDP policy definition
set security idp idp-policy IDP-DEMO rulebase-ips rule BLOCK-HTTP-ATTACKS match from-zone untrust
set security idp idp-policy IDP-DEMO rulebase-ips rule BLOCK-HTTP-ATTACKS match to-zone trust
set security idp idp-policy IDP-DEMO rulebase-ips rule BLOCK-HTTP-ATTACKS match source-address any
set security idp idp-policy IDP-DEMO rulebase-ips rule BLOCK-HTTP-ATTACKS match destination-address any
set security idp idp-policy IDP-DEMO rulebase-ips rule BLOCK-HTTP-ATTACKS match attacks predefined-attack-groups "HTTP - All"
set security idp idp-policy IDP-DEMO rulebase-ips rule BLOCK-HTTP-ATTACKS then action drop-connection

# Activate policy and bind to security policy
set security idp active-policy IDP-DEMO
set security policies from-zone untrust to-zone trust policy permit-all then permit application-services idp
```

### Key design decisions

- **`from-zone untrust / to-zone trust`** — use real zone names, not `any`. Using `any` with
  this detector version can produce "no rules for IPv4" compilation errors.
- **`drop-connection`** — tears down the TCP session immediately on match, causing the attacker
  tool to see a connection reset rather than a timeout.
- **`HTTP - All`** — covers the full HTTP attack signature set including SQL injection,
  directory traversal, remote file inclusion, and tool fingerprints (nikto, sqlmap).
  On this vSRX, `SCAN - All` does not compile to IPv4 rules (static persistent context limitation).

---

## Reset Between Demos

```bash
# Clear attack counters only (policy stays active)
bash /root/lab/idp-demo/monitor-idp.sh clear

# Full reset — remove IDP policy
bash /root/lab/idp-demo/remove-idp.sh

# Re-apply when ready
bash /root/lab/idp-demo/configure-idp.sh
```

---

## Useful Show Commands

```
# Active policy and engine state
show security idp status

# Live attack hit table
show security idp attack table

# Clear attack hit counters
clear security idp attack table

# Signature database and template versions
show security idp security-package-version

# Download/install status
request security idp security-package download status
request security idp security-package install status

# IDP policy as configured
show configuration security idp

# Check IDP policy compilation errors
show log idpd_err
```

---

## Files in This Directory

| File | Purpose |
|---|---|
| `DEMO.md` | This guide |
| `vsrx1-config.txt` | Full vSRX1 config snapshot (set format) |
| `setup-target.sh` | Start HTTP server on Linux target |
| `configure-idp.sh` | Push IDP-DEMO policy to vSRX1 |
| `remove-idp.sh` | Remove IDP-DEMO policy from vSRX1 |
| `attack-webscan.sh` | Run nikto web scan from Kali |
| `attack-sqli.sh` | Run sqlmap SQL injection from Kali |
| `attack-httpbrute.sh` | Run hydra HTTP brute force from Kali |
| `monitor-idp.sh` | Poll IDP attack table on vSRX1 in real time |
