#Tracks data growth across multiple Edge Appliances and can be used to provide centralized ingest status reporting during a migration.

#populate NMC hostname and credentials
$hostname = "insertHostname"

<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#path to CSV
$reportFile = "c:\export\IngestReport.csv"

#Number of Volumes and Edge Appliances to query
$limit = 200

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

#List up to the number of volumes set in the limit
$url="https://"+$hostname+"/api/v1.2/volumes/?limit="+$limit+"&offset=0"
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#Initialize CSV output file
$csvHeader = "volume_name,volume_guid,filer_description,filer_serial_number,accessible data,unprotected data,last_snapshot_time,last_snapshot_version,snapshot_status,snapshot_percent"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8

write-host ("Exporting Volume Information to: " + $reportFile)

foreach($i in 0..($getinfo.items.Count-1)){

     #call the list filer specific settings for a volume endpoint
     $volumefilerurl = "https://"+$hostname+"/api/v1.2/volumes/" + $getinfo.items[$i].guid + "/filers/?limit="+$limit+"&offset=0/"

     $volumeinfo = Invoke-RestMethod -Uri $volumefilerurl -Method Get -Headers $headers
     #loop through each item in the volume results
        foreach($j in 0..($volumeinfo.items.Count-1)){
        #get filer info for the owner and each connected filer
        $filerurl = "https://"+$hostname+"/api/v1.2/filers/" + $($volumeinfo.items[$j].filer_serial_number) + "/"
        $filerinfo = Invoke-RestMethod -Uri $filerurl -Method Get -Headers $headers
        #get snapshot status
        $volumeFilerStatusUrl = "https://"+$hostname+"/api/v1.2/volumes/" + $getinfo.items[$i].guid + "/filers/" + $($volumeinfo.items[$j].filer_serial_number) + "/"
        $volumeFilerStatus = Invoke-RestMethod -Uri $volumeFilerStatusUrl -Method Get -Headers $headers
        #build and output results
        $datastring = "$($getinfo.items[$i].name),$($getinfo.items[$i].guid),$($filerinfo.description),$($filerinfo.serial_number),$($volumeinfo.items[$j].status.accessible_data),$($volumeinfo.items[$j].status.data_not_yet_protected),$($volumeinfo.items[$j].status.last_snapshot),$($volumeinfo.items[$j].status.last_snapshot_version),$($volumeFilerStatus.status.snapshot_status),$($volumeFilerStatus.status.snapshot_percent)"
        Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
        $j++}
$i++
}
