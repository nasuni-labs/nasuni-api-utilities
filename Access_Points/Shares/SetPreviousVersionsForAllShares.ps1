#Set Previous Versions Support for All Shares
 
#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
  
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Enable Previous Versions - set to True to enable Previous Versions; False to disable
$PreviousVersions = "True"

#Number of Shares to query - edit if more are needed
$limit = 1000

#end variables

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
 
#Read the token from a file and add it to the headers for the request
$token = Get-Content $tokenFile
$headers.Add("Authorization","Token " + $token)

#Build json body for share update
$UpdateBody = @"
{
    "enable_previous_vers": "$PreviousVersions"
}
"@
 
#List volumes
$FormatEnumerationLimit=-1
$GetShareInfoUrl="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit="+$limit+"&offset=0"
$GetShareInfo = Invoke-RestMethod -Uri $GetShareInfoUrl -Method Get -Headers $headers
 
foreach($i in 0..($GetShareInfo.items.Count-1)){
	#loop through shares to find shares without previous versions enabled and set previous versions to true
	if ($GetShareInfo.items[$i].enable_previous_vers -eq $false){
    #Build the URL for updating shares
    $UpdateShareURL="https://"+$hostname+"/api/v1.1/volumes/" + $($GetShareInfo.items[$i].Volume_Guid) + "/filers/" + $($GetShareInfo.items[$i].filer_serial_number) + "/shares/" + $($GetShareInfo.items[$i].id) + "/"
    $response=Invoke-RestMethod -Uri $UpdateShareURL -Method Patch -Headers $headers -Body $UpdateBody
    write-output $response | ConvertTo-Json
    Start-Sleep 1.1
	}

$i++}

