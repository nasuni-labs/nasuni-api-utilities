#!/usr/bin/env python3
"""
Request an NMC API token and store the output in a token file
that can be used by subsequent scripts. Tokens expire after 8 hours.
"""

import requests
import urllib3

# Suppress InsecureRequestWarning when using verify=False
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# NMC hostname or IP address
hostname = "InsertNMChostname"

# Username for AD accounts supports both UPN (user@domain.com) and 
# DOMAIN\samaccountname formats. Nasuni Native user accounts are also supported.
username = "InsertUsername"
password = "InsertPassword"

# Path to token output file
token_file = "c:\nasuni\token.txt"

# End variables

# Build the request
url = f"https://{hostname}/api/v1.1/auth/login/"

headers = {
    "Accept": "application/json",
    "Content-Type": "application/json"
}

credentials = {
    "username": username,
    "password": password
}

# Request token from NMC (verify=False allows untrusted SSL certs)
response = requests.post(url, headers=headers, json=credentials, verify=False)
response.raise_for_status()

# Extract the token
token = response.json()["token"]

# Write the token to the console
print(token)

# Write the token to the file
with open(token_file, "w") as f:
    f.write(token)