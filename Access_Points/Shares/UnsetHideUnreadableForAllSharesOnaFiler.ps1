#Set all shares on the specified filer to have the same settings for block files
 
#populate NMC hostname and credentials
$hostname = "host.domain.com"
  
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
#$username = Read-Host -prompt 'Input your username: '
#$Secpassword = Read-Host 'Input your password: ' -AsSecureString
#$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secpassword))

$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

#Provide Filer Serial number to update shares on
$FilerSerial = "0df8b476-40d0-4f44-b7cf-a907346d8290"

#Number of shares to query
$limit = 1000

#Allow untrusted SSL certs
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
    "hide_unreadable": "False"
}
"@

#Connect to the List all shares for filer NMC API endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit="+$limit+"&offset=0"
 
#List volumes
$FormatEnumerationLimit=-1
$GetShareInfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
 
foreach($i in 0..($GetShareInfo.items.Count-1)){
    if ($($GetShareInfo.items.filer_serial_number[$i]) -eq $FilerSerial) {
    #Build the URL for updating shares
    $UpdateShareURL="https://"+$hostname+"/api/v1.1/volumes/" + $($GetShareInfo.items.Volume_Guid[$i]) + "/filers/" + $($GetShareInfo.items.filer_serial_number[$i]) + "/shares/" + $($GetShareInfo.items.id[$i]) + "/"
    $response=Invoke-RestMethod -Uri $UpdateShareURL -Method Patch -Headers $headers -Body $UpdateBody
    write-output $response | ConvertTo-Json
    Start-Sleep 1.1
    }
}
