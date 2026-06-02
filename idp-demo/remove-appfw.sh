#!/bin/bash
# Remove AppFW and custom AppID signatures from vSRX1

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX1="100.123.12.0"

echo "=== Removing AppFW from vSRX1 ==="

sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 << 'JUNOS'
configure
delete security policies from-zone untrust to-zone trust policy permit-all then permit application-services application-firewall
delete security application-firewall rule-sets BLOCK-ATTACK-TOOLS
delete services application-identification application ATTACK-TOOL-SQLMAP
delete services application-identification application ATTACK-TOOL-NIKTO
commit and-quit
JUNOS

echo ""
echo "=== AppFW removed. Traffic now flows without application inspection ==="
