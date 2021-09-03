#Enable enhanced support for Mac clients (vfs_fruit) to all shares
 
#populate NMC hostname and credentials
$hostname = "host.domain.com"
  
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'passwords'

#Enable Mac Support - set to True to enable Mac Support; False to disable
$FruitEnabled = "True"

#Number of Shares to query - edit if more are needed
$limit = 1000

#end variables

#build credentials
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

#Connect to the List all shares for filer NMC API endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit="+$limit+"&offset=0"

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

#Build json body for share update
$UpdateBody = @"
{
    "fruit_enabled": "$FruitEnabled"
}
"@
 
#List volumes
$FormatEnumerationLimit=-1
$GetShareInfoUrl="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit="+$limit+"&offset=0"
$GetShareInfo = Invoke-RestMethod -Uri $GetShareInfoUrl -Method Get -Headers $headers
 
foreach($i in 0..($GetShareInfo.items.Count-1)){
    #loop through shares to find shares without fruit enabled and set fruit enabled to true
    #Build the URL for updating shares
    if ($GetShareInfo.items[$i].fruit_enabled -eq $false){
    $UpdateShareURL="https://"+$hostname+"/api/v1.1/volumes/" + $($GetShareInfo.items[$i].Volume_Guid) + "/filers/" + $($GetShareInfo.items[$i].filer_serial_number) + "/shares/" + $($GetShareInfo.items[$i].id) + "/"
    $response=Invoke-RestMethod -Uri $UpdateShareURL -Method Patch -Headers $headers -Body $UpdateBody
    write-output $response | ConvertTo-Json
    Start-Sleep 1.1
    }

$i++}

