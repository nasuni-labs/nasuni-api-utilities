#list all volumes and settings and export them to CSV

#populate NMC hostname and credentials
$hostname = "insertHostname"

<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Path for CSV Export
$reportFile = "c:\export\ExportVolumesAndSettings.csv"

#Number of volumes to query
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

#initialize csv output file
$csvHeader = "name,guid,filer_serial_number,case sensitive,permissions policy,protocols,remote access,remote access permissions,snapshot retention,quota,compression,chunk_size,authenticated access,auth policy,auth policy label,provider name,provider shortname,provider location,provider storage class,bucket name, AV enabled,AV days,AV check immediately,AV allday,AV start,AV stop,AV frequency"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting volume information to: " + $reportFile)

foreach($i in 0..($getVolumesInfo.items.Count-1)){
    if ($getVolumesInfo.items[$i].antivirus_service.enabled -eq $True) {
    $avDays = "sun:" + $getVolumesInfo.items[$i].antivirus_service.days.sun + "; mon:" + $getVolumesInfo.items[$i].antivirus_service.days.mon + "; tue:" + $getVolumesInfo.items[$i].antivirus_service.days.tue + "; wed:" + $getVolumesInfo.items[$i].antivirus_service.days.wed + "; thu:" + $getVolumesInfo.items[$i].antivirus_service.days.thu + "; fri:" + $getVolumesInfo.items[$i].antivirus_service.days.fri + "; sat:" + $getVolumesInfo.items[$i].antivirus_service.days.sat
} else {clear-variable avDays}
    $datastring = "$($getVolumesInfo.items[$i].name),$($getVolumesInfo.items[$i].guid),$($getVolumesInfo.items[$i].filer_serial_number),$($getVolumesInfo.items[$i].case_sensitive),$($getVolumesInfo.items[$i].protocols.permissions_policy),$($getVolumesInfo.items[$i].protocols.protocols),$($getVolumesInfo.items[$i].remote_access.enabled),$($getVolumesInfo.items[$i].remote_access.access_permissions),$($getVolumesInfo.items[$i].snapshot_retention.retain),$($getVolumesInfo.items[$i].quota),$($getVolumesInfo.items[$i].cloud_io.compression),$($getVolumesInfo.items[$i].cloud_io.chunk_size),$($getVolumesInfo.items[$i].auth.authenticated_access),$($getVolumesInfo.items[$i].auth.policy),$($getVolumesInfo.items[$i].auth.policy_label),$($getVolumesInfo.items[$i].provider.name),$($getVolumesInfo.items[$i].provider.shortname),$($getVolumesInfo.items[$i].provider.location),$($getVolumesInfo.items[$i].provider.storage_class),$($getVolumesInfo.items[$i].bucket),$($getVolumesInfo.items[$i].antivirus_service.enabled),$avDays,$($getVolumesInfo.items[$i].antivirus_service.check_files_immediately),$($getVolumesInfo.items[$i].antivirus_service.allday),$($getVolumesInfo.items[$i].antivirus_service.start),$($getVolumesInfo.items[$i].antivirus_service.stop),$($getVolumesInfo.items[$i].antivirus_service.frequency)"
    Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
    $i++
}
