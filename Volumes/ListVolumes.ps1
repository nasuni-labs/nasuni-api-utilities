#List volumes and output results to the console

#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"

<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Number of Volumes to query
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

#List Volumes
$VolumesURL="https://"+$hostname+"/api/v1.1/volumes/?limit="+$limit+"&offset=0"
$getVolumesInfo = Invoke-RestMethod -Uri $VolumesURL -Method Get -Headers $headers

#loop through results and output to the screen
$VolumesHeader = "name, guid, filer_serial_number, case sensitive, permissions policy, protocols, remote access, remote access permissions,provider name, provider shortname, provider location"

write-output $VolumesHeader

foreach($i in 0..($getVolumesInfo.items.Count-1)){
    $datastring = "$($getVolumesInfo.items[$i].name),$($getVolumesInfo.items[$i].guid),$($getVolumesInfo.items[$i].filer_serial_number),$($getVolumesInfo.items[$i].case_sensitive),$($getVolumesInfo.items[$i].protocols.permissions_policy),$($getVolumesInfo.items[$i].protocols.protocols),$($getVolumesInfo.items[$i].remote_access.enabled),$($getVolumesInfo.items[$i].remote_access.access_permissions),$($getVolumesInfo.items[$i].provider.name),$($getVolumesInfo.items[$i].provider.shortname),$($getVolumesInfo.items[$i].provider.location)"
    write-output $datastring
    $i++
}
