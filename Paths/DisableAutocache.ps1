# Disables autocache for the specified volume path and Edge Appliance.
# Uses the Disable Auto Cache Mode Endpoint - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#disable-auto-cache-mode-on-a-folder
   
# populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
   
<#Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"
  
# specify Edge Appliance and Volume
$volume_guid = "InsertVolumeGuid"
$filer_serial = "InsertFilerSerial"
  
<# Set the path on which to disable Auto Cache. The path should start with a "\" and is the case-sensitive path as displayed in the file browser
and is not related to the share path. #>
$FolderPath = "\Folder1"

#end variables

#change the direction of slashes in folder path for use with the NMC API
$FolderPath = $FolderPath -replace '\\', '/'

#begin code

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
   
#build JSON headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", 'application/json')
$headers.Add("Content-Type", 'application/json')
 
#Read the token from a file and add it to the headers for the request
$token = Get-Content $tokenFile
$headers.Add("Authorization","Token " + $token)
  
# Set the URL for the disable auto cache folders NMC API endpoint
$CacheUrl="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial + "/auto-cached-folder" + $FolderPath

#disable Auto Cache for the specified path and Edge Appliance
$response=Invoke-RestMethod -Uri $CacheUrl -Method Delete -Headers $headers
write-output $response | ConvertTo-Json
