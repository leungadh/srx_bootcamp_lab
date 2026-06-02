#!/bin/bash
# Push enhanced SCREEN config to vSRX1

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX1="100.123.12.0"

echo "=== Pushing enhanced SCREEN config to vSRX1 ==="

sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 << 'JUNOS'
configure
set security screen ids-option untrust-screen icmp flood threshold 1000
set security screen ids-option untrust-screen icmp fragment
set security screen ids-option untrust-screen icmp large
set security screen ids-option untrust-screen tcp port-scan threshold 5000
set security screen ids-option untrust-screen tcp syn-fin
set security screen ids-option untrust-screen tcp fin-no-ack
set security screen ids-option untrust-screen tcp tcp-no-flag
set security screen ids-option untrust-screen tcp winnuke
set security screen ids-option untrust-screen udp flood threshold 1000
set security screen ids-option untrust-screen udp port-scan threshold 5000
set security screen ids-option untrust-screen ip block-frag
set security screen ids-option untrust-screen ip loose-source-route-option
set security screen ids-option untrust-screen ip strict-source-route-option
set security screen ids-option untrust-screen ip unknown-protocol
commit and-quit
JUNOS

echo ""
echo "=== Verifying SCREEN profile ==="
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "show security screen ids-option untrust-screen" 2>/dev/null
