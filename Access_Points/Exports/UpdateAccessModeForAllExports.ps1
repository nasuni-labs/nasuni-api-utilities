#Update Access Mode for all NFS Exports
 
#populate NMC hostname and credentials
$hostname = "host.domain.com"
  
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#access mode: root_squash (default), no_root_squash (All Users Permitted), all_squash (Anonymize All Users)
$accessMode = "no_root_squash"

#Number of Exports to query - edit if more are needed
$limit = 1000

#end variables

#Connect to the List all exports NMC API endpoint
#$url="https://"+$hostname+"api/v1.2/volumes/filers/exports//?limit="+$limit+"&offset=0"

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

#Build json body for export update
$UpdateBody = @"
{
    "access_mode": "$accessMode"
}
"@
 
#List volumes
$FormatEnumerationLimit=-1
$GetExportInfoUrl="https://"+$hostname+"/api/v1.2/volumes/filers/exports/?limit="+$limit+"&offset=0"
$GetExportInfo = Invoke-RestMethod -Uri $GetExportInfoUrl -Method Get -Headers $headers

foreach($i in 0..($GetExportInfo.items.Count-1)){
    #Build the URL for updating exports
    $UpdateExportURL="https://"+$hostname+"/api/v1.2/volumes/" + $($GetExportInfo.items[$i].volume_guid) + "/filers/" + $($GetExportInfo.items[$i].filer_serial_number) + "/exports/" + $($GetExportInfo.items[$i].id) + "/"
    $response=Invoke-RestMethod -Uri $UpdateExportURL -Headers $headers -Method Patch  -Body $UpdateBody
    write-output $response | ConvertTo-Json
    Start-Sleep 1.1

$i++}
