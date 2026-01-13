#!/usr/bin/env python3
"""
List cloud credentials and output them to the console.
"""

import requests
import urllib3

# Suppress InsecureRequestWarning when using verify=False
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# NMC hostname
hostname = "insertNMChostname"

# Path to the NMC API authentication token file--use get_nmc_token.py to get a token.
# Tokens expire after 8 hours
token_file = "c:\nasuni\token.txt"

# Number of credentials to query
limit = 1000

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

# List credentials
url = f"https://{hostname}/api/v1.2/account/cloud-credentials/?limit={limit}&offset=0"
response = requests.get(url, headers=headers, verify=False)
response.raise_for_status()

cred_info = response.json()

# Output header
print("cred_uuid,name,filer_serial_number,cloud_provider,account,hostname,status,note,in_use")

# Loop through results and output to screen
for item in cred_info["items"]:
    print(
        f"{item['cred_uuid']},"
        f"{item['name']},"
        f"{item['filer_serial_number']},"
        f"{item['cloud_provider']},"
        f"{item['account']},"
        f"{item['hostname']},"
        f"{item['status']},"
        f"{item['note']},"
        f"{item['in_use']}"
    )