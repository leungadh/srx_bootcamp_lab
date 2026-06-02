#!/bin/bash
# Push IDP policy to vSRX1 and activate it

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX1="100.123.12.0"

echo "=== Configuring IDP on vSRX1 ==="

printf 'configure
set security idp idp-policy IDP-DEMO rulebase-ips rule BLOCK-HTTP-ATTACKS match from-zone untrust
set security idp idp-policy IDP-DEMO rulebase-ips rule BLOCK-HTTP-ATTACKS match to-zone trust
set security idp idp-policy IDP-DEMO rulebase-ips rule BLOCK-HTTP-ATTACKS match source-address any
set security idp idp-policy IDP-DEMO rulebase-ips rule BLOCK-HTTP-ATTACKS match destination-address any
set security idp idp-policy IDP-DEMO rulebase-ips rule BLOCK-HTTP-ATTACKS match attacks predefined-attack-groups "HTTP - All"
set security idp idp-policy IDP-DEMO rulebase-ips rule BLOCK-HTTP-ATTACKS then action drop-connection
set security idp active-policy IDP-DEMO
set security policies from-zone untrust to-zone trust policy permit-all then permit application-services idp
commit
exit
' | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 2>/dev/null

echo ""
echo "=== Waiting for IDP policy to load (~20s) ==="
sleep 20

echo ""
echo "=== IDP status ==="
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "show security idp status" 2>/dev/null | grep -E "Policy Name|State of IDP"
