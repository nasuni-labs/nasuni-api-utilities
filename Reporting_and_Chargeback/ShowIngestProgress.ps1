#Tracks data growth across multiple Edge Appliances and can be used to provide centralized ingest status reporting during a migration.

#populate NMC hostname and credentials
$hostname = "insertHostname"

#username format - Native account, use the account name. Domain account, use the UPN
$username = "username"
$password = 'password'

#path to CSV
$reportFile = "c:\export\IngestReport.csv"

#Number of Volumes and Edge Appliances to query
$limit = 200

#end variables
#build credentials
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

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

#construct Uri
$url="https://"+$hostname+"/api/v1.1/auth/login/"

#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)

#List up to the number of volumes set in the limit
$url="https://"+$hostname+"/api/v1.1/volumes/?limit="+$limit+"&offset=0"
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#initialize csv output file
$csvHeader = "volume_name,volume_guid,filer_description,filer_serial_number,accessible data,unprotected data,last_snapshot_time,last_snapshot_version"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8

write-host ("Exporting Volume Information to: " + $reportFile)

foreach($i in 0..($getinfo.items.Count-1)){

     #call the list filer specific settings for a volume endpoint
     $volumefilerurl = "https://"+$hostname+"/api/v1.1/volumes/" + $getinfo.items[$i].guid + "/filers/?limit="+$limit+"&offset=0/"
     $volumeinfo = Invoke-RestMethod -Uri $volumefilerurl -Method Get -Headers $headers
     #loop through each item in the volume results
        foreach($j in 0..($volumeinfo.items.Count-1)){
        #get filer info for the owner and each connected filer
        $filerurl = "https://"+$hostname+"/api/v1.1/filers/" + $($volumeinfo.items[$j].filer_serial_number) + "/"
        $filerinfo = Invoke-RestMethod -Uri $filerurl -Method Get -Headers $headers
        $datastring = "$($getinfo.items[$i].name),$($getinfo.items[$i].guid),$($filerinfo.description),$($filerinfo.serial_number),$($volumeinfo.items[$j].status.accessible_data),$($volumeinfo.items[$j].status.data_not_yet_protected),$($volumeinfo.items[$j].status.last_snapshot),$($volumeinfo.items[$j].status.last_snapshot_version)"
        Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
        $j++}
$i++
}
