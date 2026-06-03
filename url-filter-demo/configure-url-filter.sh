#!/bin/bash
# Configure URL filtering on vSRX2 using Juniper Enhanced Web Filtering (EWF)
# Traffic path: Linux target → vSRX2 (URL filter) → vSRX1 → Kali (simulated web server)

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX2="100.123.12.1"
KALI="100.123.38.1"
TARGET="100.123.33.1"

echo "=== Step 1: Configure vSRX2 URL filtering ==="

printf 'configure

# Route Kali subnet directly via vSRX1 (trust→untrust path for URL filtering)
delete routing-options static route 192.168.10.0/30
set routing-options static route 192.168.10.0/30 next-hop 10.0.0.1

# Custom URL categories for blocked sites
set security utm custom-objects url-pattern SOCIAL-SITES value "*.facebook.com"
set security utm custom-objects url-pattern SOCIAL-SITES value "*.instagram.com"
set security utm custom-objects url-pattern SOCIAL-SITES value "*.twitter.com"
set security utm custom-objects url-pattern STREAM-SITES value "*.youtube.com"
set security utm custom-objects url-pattern STREAM-SITES value "*.netflix.com"
set security utm custom-objects custom-url-category BLOCKED-SOCIAL value SOCIAL-SITES
set security utm custom-objects custom-url-category BLOCKED-STREAMING value STREAM-SITES

# EWF profile: block social/streaming, permit everything else
set security utm feature-profile web-filtering type juniper-enhanced
set security utm feature-profile web-filtering juniper-enhanced profile EWF-BLOCK default permit
set security utm feature-profile web-filtering juniper-enhanced profile EWF-BLOCK category BLOCKED-SOCIAL action block
set security utm feature-profile web-filtering juniper-enhanced profile EWF-BLOCK category BLOCKED-STREAMING action block
set security utm feature-profile web-filtering juniper-enhanced profile EWF-BLOCK fallback-settings default log-and-permit
set security utm feature-profile web-filtering juniper-enhanced profile EWF-BLOCK fallback-settings server-connectivity log-and-permit
set security utm feature-profile web-filtering juniper-enhanced profile EWF-BLOCK fallback-settings timeout log-and-permit
set security utm feature-profile web-filtering juniper-enhanced profile EWF-BLOCK fallback-settings too-many-requests log-and-permit

# UTM policy referencing the EWF profile
set security utm utm-policy UTM-WEB web-filtering http-profile EWF-BLOCK

# Apply UTM to trust→untrust security policy (remove redundant permit-all first)
delete security policies from-zone trust to-zone untrust policy permit-all
set security policies from-zone trust to-zone untrust policy default-permit then permit application-services utm-policy UTM-WEB

commit
exit
' | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX2 2>/dev/null

echo ""
echo "=== Step 2: Start web server on Kali (simulated internet) ==="
mkdir -p /tmp/webroot 2>/dev/null
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$KALI "
  mkdir -p /tmp/webroot
  cat > /tmp/webroot/index.html << 'EOF'
<html><body><h1>URL Filter Demo Server</h1><p>This request passed vSRX2 URL filtering.</p></body></html>
EOF
  pkill -f 'http.server 80' 2>/dev/null; sleep 1
  echo 'Juniper!1' | sudo -S bash -c 'nohup python3 -m http.server 80 --directory /tmp/webroot > /tmp/webserver.log 2>&1 &'
  sleep 1
  echo 'Juniper!1' | sudo -S ss -tlnp | grep ':80'
" 2>/dev/null

echo ""
echo "=== Step 3: Configure Linux target hosts (demo domains → Kali) ==="
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@$TARGET "
  # Remove any existing demo entries
  sed -i '/URL filter demo/,/^$/d' /etc/hosts
  cat >> /etc/hosts << 'EOF'

# URL filter demo - all point to Kali web server (192.168.10.2)
192.168.10.2 www.facebook.com facebook.com
192.168.10.2 www.youtube.com youtube.com
192.168.10.2 www.instagram.com instagram.com
192.168.10.2 www.cnn.com cnn.com
192.168.10.2 www.google.com google.com
192.168.10.2 www.amazon.com amazon.com
EOF
  echo 'Hosts configured:'
  grep '192.168.10.2' /etc/hosts
" 2>/dev/null

echo ""
echo "=== URL filtering configured. Run ./run-demo.sh to test ==="
