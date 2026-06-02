#!/bin/bash
# Start a web server on the Linux target (192.168.20.2)

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
TARGET_MGMT="100.123.33.1"
TARGET_DATA="192.168.20.2"
KALI="100.123.38.1"

echo "=== Setting up web target on Linux (${TARGET_DATA}) ==="

# Kill any existing server
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@$TARGET_MGMT \
    "pkill -f 'python3 -m http.server' 2>/dev/null; sleep 1" 2>/dev/null

# Open port 80 in firewalld (AlmaLinux 9 target)
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@$TARGET_MGMT \
    "firewall-cmd --add-port=80/tcp --zone=public --permanent --quiet; firewall-cmd --reload --quiet" 2>/dev/null

# Create a simple demo page
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@$TARGET_MGMT "cat > /tmp/index.html << 'HTML'
<html>
<body>
<h1>Demo Target Server</h1>
<p>User login: <a href=\"/login?user=admin&pass=secret\">/login</a></p>
<p>Items: <a href=\"/items?id=1\">/items?id=1</a></p>
</body>
</html>
HTML
mkdir -p /tmp/www && cp /tmp/index.html /tmp/www/
" 2>/dev/null

# Start web server in background
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@$TARGET_MGMT \
    "cd /tmp/www && nohup python3 -m http.server 80 > /tmp/httpserver.log 2>&1 & echo \$!" 2>/dev/null

sleep 2

# Verify from Kali side (data plane connectivity check)
echo ""
echo "=== Connectivity check: Kali → Linux target via data plane ==="
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$KALI \
    "curl -s -o /dev/null -w 'HTTP %{http_code} from ${TARGET_DATA} in %{time_total}s\n' --connect-timeout 5 http://${TARGET_DATA}/" 2>/dev/null

echo ""
echo "Target ready. Web server running on ${TARGET_DATA}:80"
echo "To verify manually: curl http://${TARGET_DATA}/ from Kali"
