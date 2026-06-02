#!/bin/bash
# Web vulnerability scan from Kali using nikto
# Triggers: HTTP:INVALID:*, HTTP:AUDIT:*, HTTP:REMOTE-URL-IN-VAR, HTTP:DIR:* IDP signatures

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
KALI="100.123.38.1"
TARGET="192.168.20.2"

echo "=== Web Vulnerability Scan — nikto ==="
echo "Attacker : Kali (192.168.10.2)"
echo "Target   : Linux (${TARGET}:80)"
echo "Tool     : nikto"
echo ""
echo "WITHOUT IDP: scan completes, findings reported"
echo "WITH IDP:    connections dropped after signature match — nikto hits error limit and aborts"
echo ""
echo "Starting scan..."
echo ""

sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$KALI \
    "nikto -h http://${TARGET} -nointeractive 2>&1" 2>/dev/null

echo ""
echo "Scan complete. Check IDP hit counters:"
echo "  bash /root/lab/idp-demo/monitor-idp.sh"
