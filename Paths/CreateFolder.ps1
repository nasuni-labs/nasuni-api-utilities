#Create a new folder within a Volume on the specified Edge Appliance
#Uses this NMC API endpoint: http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#try-to-make-the-given-directory-path
 
#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

#specify Edge Appliance and Volume
$volume_guid = "InsertVolumeGuidHere"
$filer_serial = "InsertFilerSerialHere"

#Create the given path as a directory under the volume on the given filer. The path should start with a "/"
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
 
#Set the URL for the folder creation NMC API endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial + "/make-dir-path/"

#build the body for folder creation
$body = @{
    path = $FolderPath
}

#create the folder
$response=Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $body)
write-output $response | ConvertTo-Json