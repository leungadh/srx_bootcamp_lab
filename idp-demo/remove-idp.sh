#!/bin/bash
# Remove IDP policy from vSRX1 (reset to pre-demo state)

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX1="100.123.12.0"

echo "=== Removing IDP policy from vSRX1 ==="

printf 'configure
delete security idp
delete security policies from-zone untrust to-zone trust policy permit-all then permit application-services idp
commit
exit
' | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 2>/dev/null

echo ""
echo "=== IDP policy removed ==="
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 "show security idp status" 2>/dev/null | grep "Policy Name"
