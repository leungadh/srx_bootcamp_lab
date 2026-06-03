# URL Filtering Demo — vSRX2 EWF (Juniper Enhanced Web Filtering)

## Overview

Demonstrates vSRX2 intercepting HTTP traffic from the Linux target and blocking
specific website categories using the Juniper Enhanced Web Filtering (EWF) license.

**What you see:**
- Social media (Facebook, Instagram) → blocked with HTTP 403
- Streaming media (YouTube, Netflix) → blocked with HTTP 403
- News/general sites (CNN, Google, Amazon) → permitted through

## Topology

```
Linux target (192.168.20.2)
        |
   eth1 | 192.168.20.0/30
        |
  vSRX2 ge-0/0/1 [trust zone]
     ↓  URL filtering applied here (EWF UTM)
  vSRX2 ge-0/0/0 [untrust zone]  10.0.0.0/30
        |
  vSRX1 ge-0/0/0 [trust zone]
        |
  vSRX1 ge-0/0/1 [untrust zone]  192.168.10.0/30
        |
   Kali (192.168.10.2) — running web server (simulates internet)
```

Linux target's /etc/hosts resolves demo domains → Kali's IP (192.168.10.2).
vSRX2 inspects the HTTP Host header to apply URL category filtering.

## Prerequisites

- VPN demo must NOT be running (VPN tunnel removed — routing is direct)
- EWF license installed on vSRX2 (valid until 2026-07-11)

## Setup

```bash
chmod +x *.sh
./configure-url-filter.sh
```

This configures:
1. **vSRX2 routing**: 192.168.10.0/30 via 10.0.0.1 (direct through untrust zone)
2. **Custom URL categories**: BLOCKED-SOCIAL (Facebook, Instagram, Twitter),
   BLOCKED-STREAMING (YouTube, Netflix)
3. **EWF profile** (EWF-BLOCK): blocks the two categories, permits everything else;
   fallback = log-and-permit if EWF cloud is unreachable
4. **UTM policy** (UTM-WEB): applies EWF-BLOCK profile
5. **Security policy**: trust→untrust `default-permit` with UTM-WEB applied
6. **Kali web server**: python3 http.server on port 80 (simulates internet)
7. **Linux target /etc/hosts**: demo domains mapped to Kali's 192.168.10.2

## Run the Demo

```bash
./run-demo.sh
```

### Expected output

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

> **Note on timing**: Blocked sites respond instantly (custom URL category match —
> no cloud lookup needed). Allowed sites take ~10s because vSRX2 first queries the
> EWF cloud for categorization; when the cloud is unreachable (isolated lab), the
> fallback `log-and-permit` kicks in after the connectivity timeout.

## Live Monitoring

In a second terminal:
```bash
./monitor-utm.sh
```

Key counters to highlight during the demo:
- **Custom category block** — increments for each blocked site hit
- **Queries to server** — increments when EWF cloud is queried for uncategorized sites
- **Connectivity (log-and-permit)** — shows EWF cloud fallback for unreachable server

## Key Config on vSRX2

```
show configuration security utm
show security utm web-filtering statistics
show security policies from-zone trust to-zone untrust
```

## Cleanup

```bash
./remove-url-filter.sh
```

Removes all UTM config from vSRX2 and stops the Kali web server.
