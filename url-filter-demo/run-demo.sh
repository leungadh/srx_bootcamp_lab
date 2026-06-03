#!/bin/bash
# URL Filtering Demo: show vSRX2 blocking social media and streaming sites
# while allowing news/general sites through

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
TARGET="100.123.33.1"
SRX2="100.123.12.1"

echo "============================================================"
echo "  URL Filtering Demo — vSRX2 EWF (Juniper Enhanced)"
echo "============================================================"
echo ""
echo "Traffic path: Linux target → vSRX2 (URL filter) → vSRX1 → Kali"
echo ""

# --- BLOCKED sites ---
echo "--- BLOCKED: Social Networking (www.facebook.com) ---"
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@$TARGET \
  "curl -s -o /dev/null -w 'HTTP %{http_code} in %{time_total}s\n' --max-time 15 http://www.facebook.com"

echo ""
echo "--- BLOCKED: Streaming Media (www.youtube.com) ---"
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@$TARGET \
  "curl -s -o /dev/null -w 'HTTP %{http_code} in %{time_total}s\n' --max-time 15 http://www.youtube.com"

echo ""
echo "--- BLOCKED: Social Networking (www.instagram.com) ---"
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@$TARGET \
  "curl -s -o /dev/null -w 'HTTP %{http_code} in %{time_total}s\n' --max-time 15 http://www.instagram.com"

echo ""

# --- ALLOWED sites ---
echo "--- ALLOWED: News (www.cnn.com) ---"
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@$TARGET \
  "curl -s -o /dev/null -w 'HTTP %{http_code} in %{time_total}s\n' --max-time 15 http://www.cnn.com"

echo ""
echo "--- ALLOWED: Search (www.google.com) ---"
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@$TARGET \
  "curl -s -o /dev/null -w 'HTTP %{http_code} in %{time_total}s\n' --max-time 15 http://www.google.com"

echo ""
echo "--- ALLOWED: Shopping (www.amazon.com) ---"
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@$TARGET \
  "curl -s -o /dev/null -w 'HTTP %{http_code} in %{time_total}s\n' --max-time 15 http://www.amazon.com"

echo ""
echo "============================================================"
echo "  vSRX2 UTM Statistics"
echo "============================================================"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX2 \
  "show security utm web-filtering statistics" 2>/dev/null | \
  grep -E 'Total requests|Custom category block|Custom category permit|Queries to server|Server reply|Connectivity|Timeout|Fallback'
