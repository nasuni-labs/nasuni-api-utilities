#Set all shares on the specified filer to read only
 
#populate NMC hostname and credentials
$hostname = "host.domain.com"
  
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Provide Filer Serial number to set to read only
$FilerSerial = "InsertFilerSerial"

#Number of shares to query
$limit = 1000

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

#Build json body for share update
$UpdateBody = @"
{
    "readonly": "True"
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

