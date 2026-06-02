#!/bin/bash
# Real-time SCREEN statistics monitor on vSRX1

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX1="100.123.12.0"
INTERVAL=${1:-3}

clear_stats() {
    sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "clear security screen statistics interface ge-0/0/1" 2>/dev/null
    echo ">>> SCREEN counters cleared on ge-0/0/1"
}

show_stats() {
    echo "=========================================="
    echo " vSRX1 SCREEN Stats — $(date '+%H:%M:%S')"
    echo "=========================================="
    sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "show security screen statistics interface ge-0/0/1" 2>/dev/null
    echo ""
}

if [[ "$1" == "clear" ]]; then
    clear_stats
    exit 0
fi

echo "Polling SCREEN stats every ${INTERVAL}s. Ctrl+C to stop."
echo ""
while true; do
    show_stats
    sleep "$INTERVAL"
done
