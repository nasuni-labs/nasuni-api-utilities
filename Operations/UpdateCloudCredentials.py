#!/usr/bin/env python3
"""
Update Cloud Credentials for a given CRED_UUID.
Available for NMC API v1.2 and onward.

The script updates one credential at a time and updates all online Filers
using the credential. CRED UUID is used to identify cloud credentials.
To find the CRED UUID, use the list cloud credential NMC API or the
list_cloud_credentials.py script.
"""

import requests
import urllib3
import time

# Suppress InsecureRequestWarning when using verify=False
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# NMC hostname
hostname = "insertHostname"

# Path to the NMC API authentication token file
token_file = "c:\nasuni\token.txt"

# Number of credentials to query
limit = 1000

# Number of retries to recheck pending update status
retry_counter = 2

# Credential UUID - identifies the set of edge appliances that share credentials
cred_uuid = "CredUUID"

# New credentials
cred_access_key = "accesskey"
cred_secret = "secret"
cred_hostname = "hostname"
cred_name = "name"
cred_note = "notes"


# End variables

# Read the token from the file
with open(token_file, "r") as f:
    token = f.read().strip()

# Build headers with authentication
headers = {
    "Accept": "application/json",
    "Content-Type": "application/json",
    "Authorization": f"Token {token}"
}

# Body for updating the cloud credentials
body = {
    "name": cred_name,
    "account": cred_access_key,
    "hostname": cred_hostname,
    "secret": cred_secret,
    "note": cred_note
}

# Validate cred_uuid
if not cred_uuid or cred_uuid == "CredUUID":
    print("\nCred UUID cannot be empty or default value\n")
    exit(1)

print(f"\nUpdating credentials for Cred_UUID: {cred_uuid}\n")

# Get credential info for the specified cred_uuid
cred_url = f"https://{hostname}/api/v1.2/account/cloud-credentials/{cred_uuid}/?limit={limit}&offset=0"
response = requests.get(cred_url, headers=headers, verify=False)
response.raise_for_status()
cred_info = response.json()

print(f"Number of Filers associated with Cred_UUID: {len(cred_info['items'])}\n")

# Get all filers to check online/offline status
filer_url = f"https://{hostname}/api/v1.2/filers/?limit={limit}&offset=0"
response = requests.get(filer_url, headers=headers, verify=False)
response.raise_for_status()
filer_info = response.json()

# Check for offline filers
offline_filers = {}
for cred_item in cred_info["items"]:
    for filer_item in filer_info["items"]:
        if cred_item["filer_serial_number"] == filer_item["serial_number"]:
            if filer_item["status"]["offline"]:
                offline_filers[cred_item["filer_serial_number"]] = True

# Confirm before continuing if there are offline filers
continue_update = True
if offline_filers:
    continue_update = False
    print("The following filers are offline:")
    for serial in offline_filers.keys():
        print(f"  {serial}")
    print("\nUpdates to the cloud credentials for these offline filers may not take effect")
    response = input("Do you wish to continue (Y/N): ")
    if response.upper() == "Y":
        continue_update = True

if not continue_update:
    print("Update cancelled.")
    exit(0)

# Track pending updates and throttling
update_pending = {}
throttle_control = 1

print("Filer Serial Number: Update Status")

# Send PATCH requests to update credentials for each filer
for cred_item in cred_info["items"]:
    filer_serial_number = cred_item["filer_serial_number"]
    
    patch_url = f"https://{hostname}/api/v1.2/account/cloud-credentials/{cred_uuid}/filers/{filer_serial_number}/?limit={limit}&offset=0"
    response = requests.patch(patch_url, headers=headers, json=body, verify=False)
    response.raise_for_status()
    patch_result = response.json()
    
    # Get the message status
    message_url = patch_result["message"]["links"]["self"]["href"]
    response = requests.get(message_url, headers=headers, verify=False)
    response.raise_for_status()
    message = response.json()
    
    print(f"{message['filer_serial_number']}: {message['status']}")
    
    # Track pending filers and report failures
    if message["status"] == "pending":
        update_pending[message["filer_serial_number"]] = message_url
    elif message["status"] == "failure":
        print(f"  {message['error']['code']}: {message['error']['description']}")
    
    # Wait to respect NMC API throttling (PATCH request)
    time.sleep(1.1)

# Retry loop for pending updates
while update_pending and retry_counter >= 0:
    print("\nChecking for pending updates\n")
    
    # Clone the dict to iterate safely while modifying
    retry_update = dict(update_pending)
    
    for filer_serial, message_url in retry_update.items():
        # Throttle control for GET requests (5 per second)
        throttle_control += 1
        if throttle_control % 5 == 0:
            time.sleep(1.1)
        
        response = requests.get(message_url, headers=headers, verify=False)
        response.raise_for_status()
        message = response.json()
        
        print(f"{message['filer_serial_number']}: {message['status']}")
        
        # Remove synced or failed filers from pending list
        if message["status"] == "synced":
            del update_pending[message["filer_serial_number"]]
        elif message["status"] == "failure":
            del update_pending[message["filer_serial_number"]]
            print(f"  {message['error']['code']}: {message['error']['description']}\n")
    
    retry_counter -= 1
    time.sleep(1.1)

# Final advisory for any remaining pending filers
if update_pending:
    print("\nSome filers haven't synced yet. Please check NMC to track changes")