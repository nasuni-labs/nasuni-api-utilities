# Set Auto Cache for the specified volume path and Edge Appliance
# Uses Set Auto Caching Mode Endpoint - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#set-auto-caching-mode
# NOTE: The volume must have Remote Access enabled before enabling Auto Cache
  
# populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
  
# username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ).
# Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'
 
# specify Volume GUID and Edge Appliance Serial Number
$volume_guid = "InsertVolumeGuid"
$filer_serial = "InsertFilerSerial"
 
# Set the path on which to enable Auto Cache. The path should start with a "\" and is the case sensitive path as displayed in the file browser
# and is not related to the share path. If you want to enable Auto Cache of metadata for the entire volume, set this to "\".
$FolderPath = "\Folder1"

# Set the mode for Auto Cache - valid options: metadata_and_data, metadata
$Mode = "metadata_and_data"

#end variables

#change the direction of slashes in folder path for use with the NMC API
$FolderPath = $FolderPath -replace '\\', '/'

# Allow untrusted SSL certs
if ($PSVersionTable.PSEdition -eq 'Core') #PowerShell Core
{
	if ($PSDefaultParameterValues.Contains('Invoke-RestMethod:SkipCertificateCheck')) {}
	else {
		$PSDefaultParameterValues.Add('Invoke-RestMethod:SkipCertificateCheck', $true)
	}
}
else #other versions of PowerShell
{if ("TrustAllCertsPolicy" -as [type]) {} else {		
	
Add-Type -TypeDefinition @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
	public bool CheckValidationResult(
		ServicePoint srvPoint, X509Certificate certificate,
		WebRequest request, int certificateProblem) {
		return true;
	}
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName TrustAllCertsPolicy

#set the correct TLS Type
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 } }
  
# build JSON headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", 'application/json')
$headers.Add("Content-Type", 'application/json')
  
# construct Uri
$url="https://"+$hostname+"/api/v1.1/auth/login/"
  
# Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)
 
# Set the URL for the folder update NMC API endpoint
$CacheUrl="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial + "/auto-cached-folders/"
 
# build the body for the folder update
$body = @{
    path = $FolderPath
    mode = $Mode
}
 
# set folder properties
$response=Invoke-RestMethod -Uri $CacheUrl -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $body)
write-output $response | ConvertTo-Json