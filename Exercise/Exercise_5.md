# Exercise 5: URL Filtering with Juniper Enhanced Web Filtering (EWF)

## Objective

Configure vSRX2 to enforce web access policy for the Linux target using the Juniper Enhanced Web Filtering (EWF) UTM engine. By the end of this exercise, you will have observed social media and streaming sites blocked with immediate HTTP 403 responses while news and general sites are permitted, and be able to read UTM statistics to distinguish custom-category blocks from EWF cloud decisions.

## Background

URL filtering operates on vSRX2 in the **trust zone**, inspecting HTTP traffic from the Linux target before it exits to the untrust zone toward vSRX1 and Kali. Unlike SCREEN (packet headers) or IDP (attack signatures), EWF makes access policy decisions based on the **HTTP Host header** — the website the user is requesting.

**Two-tier categorization — how the decision is made:**

```
HTTP request arrives from Linux target
        │
        ▼
Does Host header match a custom URL category?
  YES → apply block or permit immediately (no cloud lookup, ~0.05s)
  NO  → query EWF cloud for category
          │
          ├─ Cloud reachable → use cloud category
          └─ Cloud unreachable (this lab) → fallback: log-and-permit (~6–10s timeout)
```

**Traffic path:**

```
Linux target (192.168.20.2)
    → vSRX2 ge-0/0/1 [trust zone]  ← URL filtering applied here
    → vSRX2 ge-0/0/0 [untrust zone]
    → vSRX1 ge-0/0/0 → ge-0/0/1
    → Kali (192.168.10.2) — running simulated web server
```

**The lab trick:** The EWF engine inspects the HTTP `Host:` header — not where the packet is actually routed. The Linux target's `/etc/hosts` file maps real domain names (`www.facebook.com`, `www.youtube.com`, etc.) to Kali's IP (192.168.10.2). Traffic physically goes to Kali's web server, but vSRX2 enforces policy based on the domain name in the request header.

**URL categories configured:**

| Category | Sites | Action |
|----------|-------|--------|
| `BLOCKED-SOCIAL` | `*.facebook.com`, `*.instagram.com`, `*.twitter.com` | Block (HTTP 403) |
| `BLOCKED-STREAMING` | `*.youtube.com`, `*.netflix.com` | Block (HTTP 403) |
| Everything else | `www.cnn.com`, `www.google.com`, `www.amazon.com` | Permit (via EWF cloud fallback) |

## Prerequisites

- Exercise 1 complete: all four devices configured, end-to-end connectivity working
- `SSH_OPTS` exported in your shell (see Exercise 1)
- VPN tunnel removed (VPN and URL filter demos conflict — they use different routing for the 10.0.0.0/30 link)
- EWF license installed on vSRX2 (pre-installed, valid until 2026-07-11)

**Ensure VPN is not active before starting:**

```bash
bash vpn-demo/remove-vpn.sh
```

---

## Part A: Baseline — Unfiltered HTTP Access

Before configuring URL filtering, confirm the Linux target can reach all demo sites freely. This establishes the contrast for Part B.

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@100.123.33.1 \
  "for site in www.facebook.com www.youtube.com www.instagram.com www.cnn.com www.google.com; do
     echo -n \"\$site: \"; curl -s -o /dev/null -w 'HTTP %{http_code}\n' --max-time 5 http://\$site || echo 'no route'
   done"
```

> If the Linux target's `/etc/hosts` already has entries from a previous session, the requests will be routed to Kali. If Kali's web server is not running, you will see connection failures rather than HTTP 200 — both confirm no URL policy is in place yet.

---

## Step 1: Configure URL Filtering

Run the configure script from the repo root. It sets up all six components in sequence:

```bash
bash url-filter-demo/configure-url-filter.sh
```

**What the script configures:**

| Step | What it does |
|------|-------------|
| 1 | vSRX2 routing — sets `192.168.10.0/30 via 10.0.0.1` (direct, not via VPN tunnel) |
| 2 | Custom URL categories — `BLOCKED-SOCIAL` and `BLOCKED-STREAMING` URL patterns |
| 3 | EWF profile `EWF-BLOCK` — blocks both custom categories, permits all else, fallback = `log-and-permit` |
| 4 | UTM policy `UTM-WEB` — applies the `EWF-BLOCK` profile to HTTP |
| 5 | Security policy — attaches `UTM-WEB` to the `trust → untrust` `default-permit` rule |
| 6 | Kali web server — starts `python3 http.server 80` (restarts if already running) |
| 7 | Linux target `/etc/hosts` — maps all demo domains to `192.168.10.2` (Kali) |

---

## Step 2: Verify the Configuration on vSRX2

Confirm the UTM config, EWF profile, and security policy are all in place:

```bash
# Full UTM configuration
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.1 \
  "show configuration security utm"
```

Look for:
- `custom-objects` block with `BLOCKED-SOCIAL` and `BLOCKED-STREAMING` categories listing the URL patterns
- `feature-profile web-filtering juniper-enhanced profile EWF-BLOCK` with `action block` for both categories and `fallback-settings ... log-and-permit`
- `utm-policy UTM-WEB web-filtering http-profile EWF-BLOCK`

```bash
# Security policy showing UTM is applied
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.1 \
  "show security policies from-zone trust to-zone untrust"
```

Expected: the `default-permit` policy shows `application-services: UTM-WEB` in its `then` clause.

```bash
# Confirm EWF license is active
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.1 \
  "show security utm web-filtering status"
```

Expected: EWF server status and license expiry. The server may show unreachable — this is expected (isolated lab); custom categories still work without cloud connectivity.

---

## Step 3: Open the UTM Monitor

Open a **second terminal** and start the monitor. It polls `show security utm web-filtering statistics` on vSRX2 every 5 seconds.

```bash
bash url-filter-demo/monitor-utm.sh
```

Leave this running. You will watch specific counters increment as each HTTP request is processed. Key counters to watch:

| Counter | What it means |
|---------|--------------|
| `Total requests` | Every HTTP request vSRX2 evaluated |
| `Custom category block` | Requests blocked by a local custom category match |
| `Custom category permit` | Requests permitted by a local custom category match |
| `Queries to server` | Requests sent to the EWF cloud for categorization |
| `Connectivity (log-and-permit)` | Cloud was unreachable — fallback permit applied |
| `Timeout (log-and-permit)` | Cloud query timed out — fallback permit applied |

---

## Part B: Run the URL Filter Demo

Run the demo script. It makes HTTP requests from the Linux target to six sites and prints the result and response time for each:

```bash
bash url-filter-demo/run-demo.sh
```

**Expected output:**

```
--- BLOCKED: Social Networking (www.facebook.com) ---
HTTP 403 in 0.05s

--- BLOCKED: Streaming Media (www.youtube.com) ---
HTTP 403 in 0.05s

--- BLOCKED: Social Networking (www.instagram.com) ---
HTTP 403 in 0.05s

--- ALLOWED: News (www.cnn.com) ---
HTTP 200 in ~10s

--- ALLOWED: Search (www.google.com) ---
HTTP 200 in ~10s

--- ALLOWED: Shopping (www.amazon.com) ---
HTTP 200 in ~10s
```

**Why the timing differs:**

- **Blocked sites (~0.05s):** The `Host:` header matches a custom URL category. vSRX2 makes the block decision locally without any cloud query. The 403 is returned immediately.
- **Allowed sites (~10s):** These domains are not in any custom category. vSRX2 queries the EWF cloud for their category. In this isolated lab the cloud is unreachable, so the query times out (~6s) and the `server-connectivity log-and-permit` fallback kicks in. The request then completes normally. The ~10s delay includes the curl connection plus the EWF cloud timeout.

---

## Step 4: Examine UTM Statistics

After the demo script completes, check the statistics on vSRX2:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@100.123.12.1 \
  "show security utm web-filtering statistics"
```

**Expected counter pattern after `run-demo.sh`:**

| Counter | Expected value | Explanation |
|---------|---------------|-------------|
| `Total requests` | 6 | One per site tested |
| `Custom category block` | 3 | facebook, youtube, instagram — all matched local categories |
| `Queries to server` | 3 | cnn, google, amazon — not in custom categories, sent to EWF cloud |
| `Connectivity (log-and-permit)` | 3 | EWF cloud unreachable — fallback applied for all three |

The split between `Custom category block` and `Queries to server` proves two different code paths were exercised: instant local match for blocked sites, cloud query for everything else.

---

## Step 5: Test Individual Sites Manually

You can test sites directly from the Linux target to see the raw response headers:

```bash
# Blocked site — should return 403 immediately
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@100.123.33.1 \
  "curl -v http://www.facebook.com 2>&1 | grep -E 'HTTP|< |Location'"

# Allowed site — should return 200 after EWF cloud timeout
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@100.123.33.1 \
  "curl -v http://www.cnn.com 2>&1 | grep -E 'HTTP|< '"
```

The 403 for blocked sites comes from vSRX2's UTM engine, not from Kali's web server.

Add a custom test — try a domain not in any category:

```bash
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@100.123.33.1 \
  "curl -s -o /dev/null -w 'HTTP %{http_code} in %{time_total}s\n' --max-time 20 http://www.example.com"
```

Expected: `HTTP 200` after ~10s — the EWF cloud timeout + fallback log-and-permit path.

---

## Key Show Commands Reference

| Command (on vSRX2) | Purpose |
|--------------------|---------|
| `show security utm web-filtering statistics` | Full counter breakdown by decision type |
| `show security utm web-filtering status` | EWF engine state and license |
| `show configuration security utm` | Full UTM config — categories, profile, policy |
| `show security policies from-zone trust to-zone untrust` | Confirm UTM policy is attached |
| `clear security utm web-filtering statistics` | Reset counters for a clean run |

---

## Cleanup

To remove URL filtering from vSRX2 and restore the base config:

```bash
bash url-filter-demo/remove-url-filter.sh
```

This deletes all UTM config from vSRX2, stops the Kali web server, and cleans the demo entries from the Linux target's `/etc/hosts`.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| All sites return connection errors (no HTTP code) | VPN tunnel still active — routing conflict | Run `bash vpn-demo/remove-vpn.sh` then re-run configure |
| Blocked sites return HTTP 200 instead of 403 | UTM policy not attached to security policy | Check `show security policies` — confirm `application-services utm-policy UTM-WEB` is present; re-run configure |
| All sites take ~10s (none block instantly) | Custom URL categories not loading | Run `show configuration security utm custom-objects` — if empty, re-run `configure-url-filter.sh` |
| Blocked sites take ~10s instead of 0.05s | Host header not matching pattern | Confirm `/etc/hosts` on Linux target has entries; verify request uses `http://www.facebook.com` (not bare `facebook.com`) |
| `configure-url-filter.sh` shows commit error | Stale UTM config from previous run | Run `remove-url-filter.sh` first to clean state |
| Monitor shows zero `Total requests` | Traffic not traversing vSRX2 | Verify Linux target's default route exits through vSRX2's ge-0/0/1 (`ip route show` on target) |

---

## Summary

In this exercise you:

1. Observed the Linux target accessing all demo sites freely before URL filtering was applied
2. Configured vSRX2's EWF UTM engine with two custom URL categories (`BLOCKED-SOCIAL`, `BLOCKED-STREAMING`), an EWF profile, a UTM policy, and attachment to the trust→untrust security policy
3. Ran `run-demo.sh` and observed the two distinct behaviors — instant 403 for custom-category matches and ~10s permit for EWF cloud fallback
4. Read the UTM statistics and matched counter increments to specific decision paths
5. Understood the `/etc/hosts` + HTTP Host header technique that makes real domain names testable in an isolated lab

This completes the five-exercise series covering the core Juniper SRX security features: base network configuration, SCREEN (L3/L4 packet inspection), IDP (L7 payload inspection), site-to-site IPsec VPN, and URL filtering with EWF.
