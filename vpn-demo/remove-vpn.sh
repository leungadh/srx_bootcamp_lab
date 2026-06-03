#!/bin/bash
# Remove IPsec VPN config from vSRX1 and vSRX2 and restore direct routing

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX1="100.123.12.0"
SRX2="100.123.12.1"

echo "=== Removing VPN from vSRX1 ==="

printf 'configure
delete security ike
delete security ipsec
delete interfaces st0
delete security zones security-zone vpn
delete security zones security-zone trust host-inbound-traffic system-services ike
delete security policies from-zone untrust to-zone vpn
delete security policies from-zone vpn to-zone untrust
delete routing-options static route 192.168.20.0/30
set routing-options static route 192.168.20.0/30 next-hop 10.0.0.2
commit
exit
' | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 2>/dev/null

echo ""
echo "=== Removing VPN from vSRX2 ==="

printf 'configure
delete security ike
delete security ipsec
delete interfaces st0
delete security zones security-zone vpn
delete security zones security-zone untrust host-inbound-traffic system-services ike
delete security policies from-zone vpn to-zone trust
delete security policies from-zone trust to-zone vpn
delete routing-options static route 192.168.10.0/30
set routing-options static route 192.168.10.0/30 next-hop 10.0.0.1
commit
exit
' | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX2 2>/dev/null

echo ""
echo "=== VPN removed. Direct routing restored. ==="
echo "Verify: no IKE SAs should exist"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "show security ike security-associations" 2>/dev/null
