#Export Cifs locks for the specified filer to CSV

#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Path for CSV Export
$reportFile = "c:\export\CIFSLocks.csv"

#Filer Serial
$filer_serial = 'InsertFilerSerialHere'

#Number of CIFS locks to return
$limit = 10000

#NMC API version - supported values: v1.1 (22.1 NMC and older), v1.2 (22.2 NMC and higher)
#do not use v1 with this script--v1 has a different URL/schema for cifslocks
$nmcApiVersion = "v1.2"

#end variables

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
 
#Read the token from a file and add it to the headers for the request
$token = Get-Content $tokenFile
$headers.Add("Authorization","Token " + $token)

#List CIFS locks for filer NMC API endpoint
$CifsLocksUrl="https://"+$hostname+"/api/" + $nmcApiVersion + "/filers/" + $filer_serial +"/cifsclients/locks/?limit=" + $limit+ "&offset=0"
$FormatEnumerationLimit=-1
$GetCifsLocks = Invoke-RestMethod -Uri $CifsLocksUrl -Method Get -Headers $headers

#initialize csv output file
$csvHeader = "type,ip_address,hostname,share_id,path,user"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting CIFS Locks information to: " + $reportFile)

foreach($i in 0..($GetCifsLocks.total-1)){
    $datastring =  "$($GetCifsLocks.items[$i].type),$($GetCifsLocks.items[$i].client),$($GetCifsLocks.items[$i].client_name),$($GetCifsLocks.items[$i].share_id),$($GetCifsLocks.items[$i].path),$($GetCifsLocks.items[$i].user)"
    Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
} 
