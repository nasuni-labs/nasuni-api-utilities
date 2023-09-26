#Export Pinned Folders to CSV

#populate NMC hostname and credentials
$hostname = "insertHostname"
 
<#Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Path for CSV Export
$reportFile = "c:\export\Pinnedfolders.csv"

#Number fo Pinned Folders to return
$limit = 1000

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

#List Pinned Folders NMC API endpoint
$PinnedFoldersUrl="https://"+$hostname+"/api/v1.1/volumes/filers/pinned-folders/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$GetPinnedFolders = Invoke-RestMethod -Uri $PinnedFoldersUrl -Method Get -Headers $headers

#initialize csv output file
$csvHeader = "volume_guid,filer_serial_number,path,pinning mode"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting Pinned Folder information to: " + $reportFile)

foreach($i in 0..($GetPinnedFolders.items.Count-1)){
	$VolumeGuid = $GetPinnedFolders.items[$i].volume_guid
	$FilerSerial = $GetPinnedFolders.items[$i].filer_serial_number
	$Path = $GetPinnedFolders.items[$i].path
	$Mode = $GetPinnedFolders.items[$i].mode
	$datastring = "$VolumeGuid,$FilerSerial,$Path,$Mode"
	Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
} 
