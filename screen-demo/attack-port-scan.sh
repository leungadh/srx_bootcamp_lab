#!/bin/bash
# Port scan from Kali → Linux target
# Triggers: TCP port-scan SCREEN (threshold: 5000 microseconds between ports)

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
KALI="100.123.38.1"
TARGET="192.168.20.2"

echo "=== Port Scan Attack ==="
echo "Attacker : Kali (192.168.10.2)"
echo "Target   : Linux (${TARGET})"
echo "Triggers : TCP port-scan SCREEN (5000 usec threshold)"
echo ""
echo "Starting aggressive SYN scan..."

sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$KALI \
    "sudo nmap -sS --min-rate 1000 -p 1-1024 ${TARGET} 2>&1" 2>/dev/null

echo ""
echo "Scan complete. Check monitor.sh for port-scan SCREEN hit counters."
