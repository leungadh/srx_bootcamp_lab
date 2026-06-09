# Exercise 3: SRX IDP (Intrusion Detection and Prevention)

## Objective

Enable the SRX IDP engine on vSRX1 and observe it detecting and blocking three categories of application-layer attack — web vulnerability scanning, SQL injection, and SSH brute force — that pass through SCREEN completely undetected. By the end of this exercise, you will understand the distinction between packet-level and payload-level inspection and be able to read IDP attack tables.

## Background

**SCREEN vs IDP — the key distinction:**

| | SCREEN | IDP |
|--|--------|-----|
| Inspection layer | L3/L4 packet headers | L7 application payload |
| Session state | Stateless | Stateful — reassembles TCP streams |
| What it catches | Malformed packets, floods, spoofed headers | Attack tool signatures, injection payloads, brute force patterns |
| What it misses | Anything inside a valid TCP session | Packet-header anomalies |

A nikto web scan, sqlmap SQL injection probe, and hydra SSH brute force all arrive as perfectly normal TCP sessions to ports 80 and 22. SCREEN has nothing to act on. IDP reads the payload inside those sessions and matches Juniper's signature database.

**Traffic path and inspection point:**

```
Kali (192.168.10.2) → [ge-0/0/1 UNTRUST] vSRX1 [ge-0/0/0 TRUST] → vSRX2 → Linux (192.168.20.2)
                              ↑
                        IDP inspects payload here
```

**IDP-DEMO policy applied in this exercise:**

| Rule | Match | Action |
|------|-------|--------|
| `BLOCK-HTTP-ATTACKS` | untrust → trust, `HTTP - All` attack group | `recommended` (drop on attack signatures) |
| `BLOCK-SSH-BRUTE` | untrust → trust, `SSH:BRUTE-LOGIN` signature | `drop-connection` |

## Prerequisites

- Exercise 1 complete: all four devices configured, end-to-end ping working
- Exercise 2 complete (recommended): SCREEN profile applied to vSRX1
- `SSH_OPTS` exported in your shell (see Exercise 1)
- IDP signature database and policy templates installed on vSRX1 (Step 1 below — one-time setup)

---

## Step 1: Install IDP Policy Templates (One-Time Setup)

IDP predefined attack groups (`HTTP - All`, `SSH - All`) require policy templates to compile correctly. Without them the policy loads but generates no rules and blocks nothing. This step downloads and installs the templates from Juniper's cloud over the fxp0 management interface.

**Download templates:**

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "request security idp security-package download policy-templates"
```

**Poll until the download completes:**

```bash
until sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "request security idp security-package download status" 2>/dev/null | grep -q "Done"; do
  echo "Downloading..."; sleep 5
done
echo "Download complete."
```

**Install the templates:**

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "request security idp security-package install policy-templates"
```

**Poll until the install completes:**

```bash
until sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "request security idp security-package install status" 2>/dev/null | grep -q "Done"; do
  echo "Installing..."; sleep 5
done
echo "Install complete."
```

**Verify — all three fields must show a version number (not `N/A`):**

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security idp security-package-version"
```

Expected output:
```
Attack database version:3912(Minor, ...)
Detector version       :12.6.180250827
Policy template version:3912            ← must not be N/A
```

If `Policy template version` shows `N/A`, the templates did not install. Re-run the install step.

> **This step only needs to be done once.** If you have already installed templates in a previous session, skip to Step 2.

---

## Step 2: Start the Web Target on Linux

The IDP scenarios target an HTTP server running on the Linux target (192.168.20.2). Run the setup script to start it:

```bash
bash idp-demo/setup-target.sh
```

This kills any existing HTTP server process, opens port 80 in firewalld, creates three demo pages (`index.html`, `items.html`, `login.html`) under `/tmp/www/`, starts `python3 -m http.server 80`, and runs a connectivity check from Kali.

Expected output:
```
HTTP 200 from 192.168.20.2 in 0.012s
Target ready. Web server running on 192.168.20.2:80
```

If the connectivity check fails, verify Kali's eth1 is up and re-run Exercise 1 Step 5.

---

## Step 3: Open the IDP Monitor

Open a **second terminal** and start the monitor. It polls `show security idp attack table` on vSRX1 every 3 seconds, displaying the signature name and cumulative hit count. Leave it running for all scenarios.

```bash
bash idp-demo/monitor-idp.sh
```

To poll manually:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security idp attack table"
```

---

## Part A: Baseline — Attacks Without IDP

Before enabling IDP, demonstrate that attacks complete freely. This establishes the contrast for Part B.

**Ensure IDP is removed:**

```bash
bash idp-demo/remove-idp.sh
```

Confirm with:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security idp status" 2>/dev/null | grep "Policy Name"
```

Expected: the `Policy Name` field is blank.

**Run nikto (web vulnerability scan) — no IDP:**

```bash
bash idp-demo/attack-webscan.sh
```

Nikto will complete normally and report findings. The monitor shows zero IDP hits. The SRX sees a valid TCP session to port 80 and passes it.

**Run sqlmap (SQL injection) — no IDP:**

```bash
bash idp-demo/attack-sqli.sh
```

sqlmap probes the `items.html?id=1` parameter freely. No connection resets. The monitor remains empty.

> **Key observation:** Both tools produce valid TCP sessions with legitimate source/destination ports. SCREEN has no anomaly to detect. IDP is the only layer that can stop them.

---

## Part B: Enable IDP

Push the `IDP-DEMO` policy to vSRX1. The script commits the config, then waits for the policy to compile and load into the IDP engine (approximately 20 seconds).

```bash
bash idp-demo/configure-idp.sh
```

Verify the policy is active before proceeding:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security idp status" 2>/dev/null | grep -E "Policy Name|State of IDP"
```

Expected:
```
State of IDP: Default,  Up since: ...
  Policy Name : IDP-DEMO
```

If `Policy Name` is still blank after the script completes, wait another 10 seconds and re-check. The policy compiler runs asynchronously.

**Review the policy that was applied:**

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show configuration security idp"
```

Confirm two rules are present: `BLOCK-HTTP-ATTACKS` (using `HTTP - All` predefined group) and `BLOCK-SSH-BRUTE` (using `SSH:BRUTE-LOGIN` signature).

---

## Scenario 1: Web Vulnerability Scan (nikto)

**What it is:** nikto rapidly probes hundreds of known web vulnerability paths — `../` traversal, CGI endpoints, `/etc/passwd`, bash injection strings — to identify exploitable weaknesses.

**How IDP stops it:** The `HTTP - All` attack group contains signatures for each probe pattern. As soon as a signature fires, IDP resets the TCP connection. After 20 consecutive connection errors, nikto aborts.

**Clear counters for a clean run:**

```bash
bash idp-demo/monitor-idp.sh clear
```

**Launch the scan:**

```bash
bash idp-demo/attack-webscan.sh
```

**What to observe:**

- The monitor shows multiple HTTP signatures accumulating hits in real time
- nikto output ends with: `ERROR: Error limit (20) reached for host, giving up.` — it never finishes the scan
- Check the attack table after the run:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security idp attack table"
```

Expected signatures (approximate hit counts):

```
Attack name                                  #Hits
HTTP:AUDIT:URL                               ~710
HTTP:INFO-LEAK:MISS-ETAG                     ~670
HTTP:STC:SRVRSP:404-NOT-FOUND                ~650
HTTP:EXPLOIT:BRUTE-SEARCH                    ~640
HTTP:CGI:BASH-CODE-INJECTION                 ~30
HTTP:AUDIT:HTTP-VER-1.0                      ~21
HTTP:DIR:PARAMETER-TRAVERSE                  ~7
HTTP:UNIX-FILE:ETC-PASSWD                    ~1
```

The `HTTP:UNIX-FILE:ETC-PASSWD` signature is a direct match for nikto's `/etc/passwd` probe — one connection was dropped the instant that URL appeared in the request.

---

## Scenario 2: SQL Injection (sqlmap)

**What it is:** sqlmap automates detection and exploitation of SQL injection vulnerabilities by injecting progressively more complex payloads into URL parameters.

**How IDP stops it:** The `HTTP - All` group includes both generic SQL injection signatures and a specific sqlmap tool fingerprint (`HTTP:SQL:INJ:SQLMAP-ACTIVITY`). Every probe gets a connection reset before the target processes it.

**Clear counters:**

```bash
bash idp-demo/monitor-idp.sh clear
```

**Launch the injection probe:**

```bash
bash idp-demo/attack-sqli.sh
```

**What to observe:**

- sqlmap immediately reports connection timeouts on every probe attempt
- sqlmap warns: `there is a possibility that the target (or WAF/IPS) is dropping 'suspicious' requests`
- sqlmap ultimately gives up: `there seems to be a continuous problem with connection to the target`
- Check the attack table:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security idp attack table"
```

Expected signatures:

```
Attack name                                  #Hits
HTTP:AUDIT:URL                               ~15
HTTP:INVALID:CONTENT_UNEXPECTED              ~15
HTTP:SQL:INJ:SQLMAP-ACTIVITY                 ~15
HTTP:SQL:INJ:REQ-VAR-1                       ~10
HTTP:SQL:INJ:GENERIC                         ~8
HTTP:SQL:INJ:REQ-VAR-5                       ~8
HTTP:SQL:INJ:AND-NUMBER-EQUALS               ~2
```

> `HTTP:SQL:INJ:SQLMAP-ACTIVITY` is a signature that fingerprints sqlmap's specific request pattern — IDP identified not just that SQL injection was attempted, but which tool was used to attempt it.

---

## Scenario 3: SSH Brute Force (hydra)

**What it is:** hydra tries passwords from a wordlist (222 entries from `fasttrack.txt`) against SSH on the Linux target, aiming to find a valid root credential.

**How IDP stops it:** The `SSH:BRUTE-LOGIN` signature detects multiple failed login attempts from a single source. On each match, `drop-connection` immediately resets the session. hydra must re-establish a new connection for every retry, and the overhead of reconnecting after each drop collapses the attempt rate.

**Clear counters:**

```bash
bash idp-demo/monitor-idp.sh clear
```

**Launch the brute force (you can Ctrl+C early — the rate collapse is the demo):**

```bash
bash idp-demo/attack-httpbrute.sh
```

**What to observe:**

- hydra STATUS lines showing the attempt rate collapsing over time:
  ```
  [STATUS] 27.00 tries/min, 27 tries in 00:01h ...
  [STATUS] 10.67 tries/min, 32 tries in 00:03h ...
  [STATUS]  6.71 tries/min, 47 tries in 00:07h ...
  ```
- The monitor shows `SSH:BRUTE-LOGIN` hit count climbing as each brute force pattern is detected
- Check the attack table:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security idp attack table"
```

Expected:
```
Attack name                                  #Hits
SSH:BRUTE-LOGIN                              50+
```

> **Why `SSH:BRUTE-LOGIN` and not `SSH - All`:** The full `SSH - All` group includes `SSH:AUDIT:UNEXPECTED-HEADER`, which fingerprints hydra's SSH client banner and blocks the initial handshake — the attack never even starts. `SSH:BRUTE-LOGIN` is the right signature because it lets the handshake complete, then detects and throttles the credential flooding pattern.

---

## Part C: The Contrast

Remove IDP and re-run sqlmap to show the difference side-by-side:

```bash
bash idp-demo/remove-idp.sh
bash idp-demo/attack-sqli.sh      # runs freely — no drops, no IDP hits
```

Re-enable IDP:

```bash
bash idp-demo/configure-idp.sh
bash idp-demo/attack-sqli.sh      # every probe gets a connection reset
```

Same tool, same target, same firewall security policy — the only variable is IDP.

---

## Step 4: Final Verification

Confirm all three layers of evidence after the scenarios:

**1. Policy is loaded (firewall side):**

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security idp status" 2>/dev/null | grep -E "Policy Name|State of IDP"
```

**2. Signatures fired (firewall side):**

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.0 \
  "show security idp attack table"
```

**3. Legitimate traffic still works (connectivity unaffected):**

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.38.1 \
  "curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://192.168.20.2/"
```

Expected: `HTTP 200` — IDP drops attack signatures while passing normal requests.

---

## Key Show Commands Reference

| Command | Purpose |
|---------|---------|
| `show security idp status` | Engine state and active policy name |
| `show security idp attack table` | Cumulative hits per signature |
| `show security idp statistics` | Packet and session counters |
| `show security idp security-package-version` | DB, detector, and template versions |
| `show configuration security idp` | Policy rules as configured |
| `clear security idp attack table` | Reset hit counters |
| `show log idpd_err` | IDP engine errors (check if attack table is empty after attacks) |

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Attack table empty after attacks with IDP active | Policy templates not installed — "no rules for IPv4" | Run Step 1; check `show log idpd_err` for confirmation |
| `configure-idp.sh` completes but `Policy Name` stays blank | Policy still compiling | Wait 30s and re-check `show security idp status` |
| nikto completes without hitting error limit | IDP not active or wrong zone names in policy | Verify `show security idp status`; check policy uses `from-zone untrust to-zone trust` not `any` |
| sqlmap probes succeed (no timeouts) | Web server not running on target | Re-run `bash idp-demo/setup-target.sh` |
| hydra rate does not collapse | SSH:BRUTE-LOGIN not matching | Confirm `show security idp attack table` shows the signature; check `show log idpd_err` |

---

## Summary

In this exercise you:

1. Installed IDP policy templates — the one-time prerequisite for predefined attack groups to compile
2. Demonstrated that nikto, sqlmap, and hydra all pass through SCREEN undetected (normal TCP sessions)
3. Applied the `IDP-DEMO` policy with `HTTP - All` and `SSH:BRUTE-LOGIN` rules
4. Observed three distinct attack patterns each blocked with signature-specific evidence in the attack table:
   - nikto aborted after 20 connection resets
   - sqlmap gave up after repeated timeouts, naming the IDP as the likely cause
   - hydra's attempt rate collapsed from ~40 tries/min to under 7 tries/min
5. Confirmed that legitimate HTTP traffic continued working throughout

The next exercise (VPN) shifts from attack detection to encrypted tunnel configuration, demonstrating how the same vSRX devices secure site-to-site connectivity.
