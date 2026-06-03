#!/bin/bash
# Monitor vSRX2 UTM web filtering statistics in real-time

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX2="100.123.12.1"

echo "Monitoring vSRX2 UTM statistics (Ctrl-C to stop)..."
echo ""

while true; do
    clear
    echo "=== vSRX2 UTM Web Filtering Statistics === $(date)"
    echo ""
    sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX2 \
      "show security utm web-filtering statistics" 2>/dev/null
    sleep 5
done
