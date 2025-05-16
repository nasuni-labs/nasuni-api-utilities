#!/bin/bash
#Request a Nasuni Data API token and store the output in a variable. Also, get info for a file.

#populate Edge Appliance hostname
hostname=InsertHostname

#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\samaccountname formats.
username=InsertUsername
password=InsertPassword

#filepath - Specify the path for the item for GetInfo - format sharename/folder/filename
filepath=share/folder/filename

#get the token
token=$(curl -s -k -i -F username=$username -F password=$password -F device_id=linux001 -F device_type=linux https://${hostname}:443/mobileapi/1/auth/login | grep -i '^[xX]-[xS]ecret-[kK]ey:' | cut -d' ' -f2- | tr -d '\r')

#output the token to the console
echo "$token"

#get information for an item
get=$(curl -s -k -i -u "linux001:$token" https://${hostname}:443/mobileapi/1/fs/$filepath | sed -n '/ *[Xx]-[sS]ize: / {s///;p;}' )
echo "$get"
