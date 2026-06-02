#!/bin/bash
# Push custom AppID signatures + AppFW ruleset to vSRX1
# Detects and blocks attack tools (sqlmap, nikto) by HTTP User-Agent

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX1="100.123.12.0"

echo "=== Configuring AppSecure AppFW on vSRX1 ==="

sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 << 'JUNOS'
configure

# Custom AppID signature: sqlmap (matches HTTP User-Agent header containing "sqlmap")
set services application-identification application ATTACK-TOOL-SQLMAP description "sqlmap SQL injection scanner"
set services application-identification application ATTACK-TOOL-SQLMAP signature SQLMAP-UA order 1
set services application-identification application ATTACK-TOOL-SQLMAP signature SQLMAP-UA protocol tcp
set services application-identification application ATTACK-TOOL-SQLMAP signature SQLMAP-UA member m01 context http-header-user-agent
set services application-identification application ATTACK-TOOL-SQLMAP signature SQLMAP-UA member m01 pattern "sqlmap"
set services application-identification application ATTACK-TOOL-SQLMAP signature SQLMAP-UA member m01 direction client-to-server

# Custom AppID signature: nikto (matches HTTP User-Agent header containing "Nikto")
set services application-identification application ATTACK-TOOL-NIKTO description "Nikto web vulnerability scanner"
set services application-identification application ATTACK-TOOL-NIKTO signature NIKTO-UA order 1
set services application-identification application ATTACK-TOOL-NIKTO signature NIKTO-UA protocol tcp
set services application-identification application ATTACK-TOOL-NIKTO signature NIKTO-UA member m01 context http-header-user-agent
set services application-identification application ATTACK-TOOL-NIKTO signature NIKTO-UA member m01 pattern "Nikto"
set services application-identification application ATTACK-TOOL-NIKTO signature NIKTO-UA member m01 direction client-to-server

# AppFW ruleset: block identified attack tools, permit everything else
set security application-firewall rule-sets BLOCK-ATTACK-TOOLS rule BLOCK-SQLMAP match dynamic-application ATTACK-TOOL-SQLMAP
set security application-firewall rule-sets BLOCK-ATTACK-TOOLS rule BLOCK-SQLMAP then reject
set security application-firewall rule-sets BLOCK-ATTACK-TOOLS rule BLOCK-NIKTO match dynamic-application ATTACK-TOOL-NIKTO
set security application-firewall rule-sets BLOCK-ATTACK-TOOLS rule BLOCK-NIKTO then reject
set security application-firewall rule-sets BLOCK-ATTACK-TOOLS default-rule permit

# Bind AppFW to the untrust→trust security policy
set security policies from-zone untrust to-zone trust policy permit-all then permit application-services application-firewall rule-set BLOCK-ATTACK-TOOLS

commit and-quit
JUNOS

echo ""
echo "=== Verifying AppFW configuration ==="
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX1 \
    "show configuration security application-firewall" 2>/dev/null
