# Data API Examples
Utilities and scripts that use the Nasuni API to perform operations and generate reports

# Support Statement

*   These scripts have been validated with the PowerShell and Nasuni versions documented in the README file.
    
*   Nasuni Support is limited to the underlying APIs used by the scripts.
    
*   Nasuni API and Protocol bugs or feature requests should be communicated to Nasuni Customer Success.
    
*   GitHub project to-do's, bugs, and feature requests should be submitted as “Issues” in GitHub under its repositories.

# Data API Overview

[Data API Technical Documentation](http://b.link/Nasuni_API_Documentation) is available from Nasuni's documentation site.

"Sync and Mobile Access" must be enabled for a share connected to an Edge Appliance to use the Nasuni Data API. The user-specified for authentication must also have the appropriate NTFS permissions to access the files and folders within the share. Active Directory accounts are supported for authentication. 

NFS-only volumes do not support the Nasuni Data API, and LDAP-bound Edge Appliances don't support mobile access or the Nasuni Data API.

Once a token is successfully requested using the Nasuni Data API, a license for the token will be listed on the "Mobile Licenses" page in the NMC under Filers: Filer Services: Mobile Licenses. Unlike the NMC API, Nasuni Data API licenses never expire, although they can be disabled or deleted using this page.

![MobileLicenses](/Data_API/images/MobileLicenses.png)

When referencing paths using the Nasuni Data API, the path begins with the CIFS share name followed by the path within the share. Unlike the NMC API, which interacts with volumes, the Nasuni Data API interacts with data through shares.

# Limits
The Nasuni Data API uses the httpd WSGI process on the filer. There are 4 WSGI processes allowed with 16 threads each for a total of 64 sessions that can be used for the Nasuni Data API. While there is a 64-session limit for the Nasuni Data API, we don't have a throttle for connections or a way for customers to observe the number of connections.

# Examples
PowerShell NMC API Scripts for working with access points. Access points include SMB (CIFS) Shares, NFS Exports, and FTP Directories.

## Request a Token (PowerShell)
Validates Nasuni Data API connectivity and obtains a token that can be used with other Nasuni Data API endpoints. The script writes the token to the console if execution is successful and writes the encoded token to the specified path.\
**Required Inputs**: Edge Appliance hostname, username, password, dataTokenFile, deviceID, deviceType\
**Name**: GetToken.ps1

## List Folder Contents (PowerShell)
This script loads the encoded credentials from the specified file path and then connects to the Get Items endpoint to return a listing of directory contents for the specified directory. The script writes the directory listing to the console.\
**Required Inputs**: Edge Appliance hostname, username, password, dataTokenFile, folderPath\
**Name**: ListFolderContents.ps1

## Request a Token and Get File Info (Bash)
Validates Nasuni Data API connectivity using curl and obtain a token that can be used with other Nasuni Data API endpoints. The script writes the token to the console if execution succeeds and gets info for the specified file.\
**Required Inputs**: Edge Appliance hostname, username, password, filepath\
**Name**: GetTokenAndFileInfo.sh
