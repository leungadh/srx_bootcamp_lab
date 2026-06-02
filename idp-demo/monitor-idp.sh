#!/bin/bash
# Real-time IDP attack table monitor on vSRX1

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX1="100.123.12.0"
INTERVAL=${1:-3}

clear_stats() {
    sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "clear security idp attack table" 2>/dev/null
    echo ">>> IDP attack table cleared"
}

show_stats() {
    echo "=========================================="
    echo " vSRX1 IDP Attack Table — $(date '+%H:%M:%S')"
    echo "=========================================="
    sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "show security idp attack table" 2>/dev/null
    echo ""
    echo "--- IDP Statistics ---"
    sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "show security idp statistics" 2>/dev/null | grep -E "Packet|Attack|Drop|TCP|UDP"
    echo ""
}

if [[ "$1" == "clear" ]]; then
    clear_stats
    exit 0
fi

echo "Polling IDP stats every ${INTERVAL}s. Ctrl+C to stop."
echo "Run with 'clear' argument to reset counters: ./monitor-idp.sh clear"
echo ""
while true; do
    show_stats
    sleep "$INTERVAL"
done
