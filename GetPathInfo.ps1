#Get Path Info for a specificed path
  
#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
  
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ).
#Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'
 
#specify Edge Appliance and Volume
$volume_guid = "InsertVolumeGuid"
$filer_serial = "InsertFilerSerial"
 
#Set the path for GetPathInfo. The path should start with a "/" and is the path as displayed in the file browser
# and is not related to the share path.
$FolderPath = "/Insert/path/here"
  
#Request token and build connection headers
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
  
#construct Uri
$url="https://"+$hostname+"/api/v1.1/auth/login/"
  
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)
  
#Build the URL for the endpoints
$PathInfoURL="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + "$filer_serial" + "/path" + $FolderPath
 
#Refresh Stats on the supplied path
$Refresh=Invoke-RestMethod -Uri $PathInfoURL -Method POST -Headers $headers
 
#sleep to allow time for the refresh to complete
Start-Sleep -s 5
 
#Get Path Info
$getinfo = Invoke-RestMethod -Uri $PathInfoURL -Method Get -Headers $headers
 
write-host "Folder Path: " $FolderPath
write-output $getinfo | Format-List