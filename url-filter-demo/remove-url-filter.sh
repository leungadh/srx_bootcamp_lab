#!/bin/bash
# Remove URL filtering config from vSRX2 and restore clean state

SSH_OPTS="-o StrictHostKeyChecking=no -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes256-cbc,aes128-cbc"
SRX2="100.123.12.1"
KALI="100.123.38.1"
TARGET="100.123.33.1"

echo "=== Removing URL filtering from vSRX2 ==="

printf 'configure
delete security utm
delete security nat source rule-set UNTRUST-NAT
delete routing-options static route 192.168.10.0/30
set security policies from-zone trust to-zone untrust policy default-permit then permit
commit
exit
' | sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$SRX2 2>/dev/null

echo ""
echo "=== Stopping Kali web server ==="
sshpass -p 'Juniper!1' ssh $SSH_OPTS jcluser@$KALI \
  "echo 'Juniper!1' | sudo -S pkill -f 'http.server 80' 2>/dev/null; echo 'Web server stopped'" 2>/dev/null

echo ""
echo "=== Cleaning Linux target hosts file ==="
sshpass -p 'Juniper!1' ssh $SSH_OPTS root@$TARGET \
  "sed -i '/URL filter demo/,/^$/d' /etc/hosts && echo 'Hosts cleaned'" 2>/dev/null

echo ""
echo "=== URL filtering removed ==="
