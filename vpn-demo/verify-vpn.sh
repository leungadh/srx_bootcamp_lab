#!/bin/bash
# Verify IPsec VPN tunnel status and end-to-end connectivity

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX1="100.123.12.0"
KALI="100.123.38.1"
TARGET="192.168.20.2"

echo "=== IKE Phase 1 Security Associations (vSRX1) ==="
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "show security ike security-associations" 2>/dev/null

echo ""
echo "=== IPsec Phase 2 Security Associations (vSRX1) ==="
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "show security ipsec security-associations" 2>/dev/null

echo ""
echo "=== IPsec Statistics (vSRX1) ==="
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "show security ipsec statistics" 2>/dev/null

echo ""
echo "=== Ping: Kali (192.168.10.2) → Linux target (${TARGET}) through tunnel ==="
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$KALI \
    "ping -c 5 ${TARGET}" 2>/dev/null

echo ""
echo "=== Route to ${TARGET} on vSRX1 (should show st0.0) ==="
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 \
    "show route 192.168.20.0/30" 2>/dev/null
