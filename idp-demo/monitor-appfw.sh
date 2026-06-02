#!/bin/bash
# Real-time AppFW and AppID statistics monitor on vSRX1

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX1="100.123.12.0"
INTERVAL=${1:-3}

show_stats() {
    echo "=========================================="
    echo " vSRX1 AppFW Stats — $(date '+%H:%M:%S')"
    echo "=========================================="
    echo "--- Application Firewall ---"
    sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 \
        "show security application-firewall statistics" 2>/dev/null
    echo ""
    echo "--- AppID: Custom Attack Tools Detected ---"
    sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 \
        "show services application-identification statistics application-name ATTACK-TOOL-SQLMAP" 2>/dev/null
    sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 \
        "show services application-identification statistics application-name ATTACK-TOOL-NIKTO" 2>/dev/null
    echo ""
}

if [[ "$1" == "clear" ]]; then
    sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 \
        "clear services application-identification statistics" 2>/dev/null
    echo ">>> AppID statistics cleared"
    exit 0
fi

echo "Polling AppFW stats every ${INTERVAL}s. Ctrl+C to stop."
echo "Run with 'clear' to reset counters: ./monitor-appfw.sh clear"
echo ""
while true; do
    show_stats
    sleep "$INTERVAL"
done
