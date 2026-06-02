1. I am running claude on a linux host. IP 100.123.0.8/24
2. My login is root, my password is "Juniper!1"
3. There are 2 x vSRX machine in the network:
vSRX1, ip: 100.123.12.0
vSRX2, ip: 100.123.12.1
4. The login for vSRX are: "jcluser", Password: "Juniper!1"
5. There is Kali Linux on network. IP 100.123.38.1
6. There is another Linux on network. IP 100.123.33.1
The login for Linux is either "root" or "jcluser", password: "Juniper!1"
7. ON the claude host should be able to access all these networks.
8. Kali's eth1 connect to vSRX1's ge-0/0/1
9. another Linux's eth1 connect to vSRX2's ge-0/0/1
10. vSRX1's ge-0/0/0 connect to vSRX2's ge-0/0/0

