#!/bin/bash
# Build IPsec VPN tunnel between vSRX1 and vSRX2

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX1="100.123.12.0"
SRX2="100.123.12.1"

echo "=== Configuring VPN on vSRX1 (10.0.0.1) ==="

printf 'configure
set security ike proposal IKE-PROP authentication-method pre-shared-keys
set security ike proposal IKE-PROP dh-group group14
set security ike proposal IKE-PROP authentication-algorithm sha-256
set security ike proposal IKE-PROP encryption-algorithm aes-256-cbc
set security ike proposal IKE-PROP lifetime-seconds 86400
set security ike policy IKE-POL mode main
set security ike policy IKE-POL proposals IKE-PROP
set security ike policy IKE-POL pre-shared-key ascii-text "Juniper!1"
set security ike gateway IKE-GW ike-policy IKE-POL
set security ike gateway IKE-GW address 10.0.0.2
set security ike gateway IKE-GW external-interface ge-0/0/0.0
set security ike gateway IKE-GW version v2-only
set security ipsec proposal IPSEC-PROP protocol esp
set security ipsec proposal IPSEC-PROP authentication-algorithm hmac-sha-256-128
set security ipsec proposal IPSEC-PROP encryption-algorithm aes-256-cbc
set security ipsec proposal IPSEC-PROP lifetime-seconds 3600
set security ipsec policy IPSEC-POL proposals IPSEC-PROP
set security ipsec vpn VPN-DEMO bind-interface st0.0
set security ipsec vpn VPN-DEMO ike gateway IKE-GW
set security ipsec vpn VPN-DEMO ike ipsec-policy IPSEC-POL
set security ipsec vpn VPN-DEMO establish-tunnels immediately
set interfaces st0 unit 0 family inet address 172.16.0.1/30
set security zones security-zone vpn interfaces st0.0
set security zones security-zone trust host-inbound-traffic system-services ike
set security policies from-zone untrust to-zone vpn policy VPN-PERMIT match source-address any
set security policies from-zone untrust to-zone vpn policy VPN-PERMIT match destination-address any
set security policies from-zone untrust to-zone vpn policy VPN-PERMIT match application any
set security policies from-zone untrust to-zone vpn policy VPN-PERMIT then permit
set security policies from-zone vpn to-zone untrust policy VPN-RETURN match source-address any
set security policies from-zone vpn to-zone untrust policy VPN-RETURN match destination-address any
set security policies from-zone vpn to-zone untrust policy VPN-RETURN match application any
set security policies from-zone vpn to-zone untrust policy VPN-RETURN then permit
delete routing-options static route 192.168.20.0/30
set routing-options static route 192.168.20.0/30 next-hop st0.0
commit
exit
' | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 2>/dev/null

echo ""
echo "=== Configuring VPN on vSRX2 (10.0.0.2) ==="

printf 'configure
set security ike proposal IKE-PROP authentication-method pre-shared-keys
set security ike proposal IKE-PROP dh-group group14
set security ike proposal IKE-PROP authentication-algorithm sha-256
set security ike proposal IKE-PROP encryption-algorithm aes-256-cbc
set security ike proposal IKE-PROP lifetime-seconds 86400
set security ike policy IKE-POL mode main
set security ike policy IKE-POL proposals IKE-PROP
set security ike policy IKE-POL pre-shared-key ascii-text "Juniper!1"
set security ike gateway IKE-GW ike-policy IKE-POL
set security ike gateway IKE-GW address 10.0.0.1
set security ike gateway IKE-GW external-interface ge-0/0/0.0
set security ike gateway IKE-GW version v2-only
set security ipsec proposal IPSEC-PROP protocol esp
set security ipsec proposal IPSEC-PROP authentication-algorithm hmac-sha-256-128
set security ipsec proposal IPSEC-PROP encryption-algorithm aes-256-cbc
set security ipsec proposal IPSEC-PROP lifetime-seconds 3600
set security ipsec policy IPSEC-POL proposals IPSEC-PROP
set security ipsec vpn VPN-DEMO bind-interface st0.0
set security ipsec vpn VPN-DEMO ike gateway IKE-GW
set security ipsec vpn VPN-DEMO ike ipsec-policy IPSEC-POL
set security ipsec vpn VPN-DEMO establish-tunnels immediately
set interfaces st0 unit 0 family inet address 172.16.0.2/30
set security zones security-zone vpn interfaces st0.0
set security zones security-zone untrust host-inbound-traffic system-services ike
set security policies from-zone vpn to-zone trust policy VPN-PERMIT match source-address any
set security policies from-zone vpn to-zone trust policy VPN-PERMIT match destination-address any
set security policies from-zone vpn to-zone trust policy VPN-PERMIT match application any
set security policies from-zone vpn to-zone trust policy VPN-PERMIT then permit
set security policies from-zone trust to-zone vpn policy VPN-RETURN match source-address any
set security policies from-zone trust to-zone vpn policy VPN-RETURN match destination-address any
set security policies from-zone trust to-zone vpn policy VPN-RETURN match application any
set security policies from-zone trust to-zone vpn policy VPN-RETURN then permit
delete routing-options static route 192.168.10.0/30
set routing-options static route 192.168.10.0/30 next-hop st0.0
commit
exit
' | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX2 2>/dev/null

echo ""
echo "=== Waiting for IKE Phase 1 to establish... ==="
for i in $(seq 1 12); do
  result=$(sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "show security ike security-associations" 2>/dev/null)
  if echo "$result" | grep -q "UP"; then
    echo "IKE SA is UP"
    break
  fi
  echo "  attempt $i/12 — waiting 5s..."
  sleep 5
done

echo ""
echo "=== VPN Status ==="
echo "--- IKE Phase 1 (vSRX1) ---"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "show security ike security-associations" 2>/dev/null
echo ""
echo "--- IPsec Phase 2 (vSRX1) ---"
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "show security ipsec security-associations" 2>/dev/null
