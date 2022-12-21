#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"

#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#enter the path for the CSV export file
$reportFile = "C:\path\to\folder\VolumeInfo.csv"

#Number of Volumes to query
$limit = 1000

#end variables

#combine credentials for token request
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

#List volumes
$url="https://"+$hostname+"/api/v1.1/volumes/?limit="+$limit+"&offset=0"
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#initialize csv output file
$csvHeader = "volume_name, volume_guid, filer_description, filer_serial_number, accessible data, provider"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8

write-host ("Exporting Volume Information to: " + $reportFile)

foreach($i in 0..($getinfo.items.Count-1)){
   $filerurl = "https://"+$hostname+"/api/v1.1/filers/" + $getinfo.items.filer_serial_number[$i] + "/"
   $filerinfo = Invoke-RestMethod -Uri $filerurl -Method Get -Headers $headers
   $volumefilerurl = "https://"+$hostname+"/api/v1.1/volumes/" + $getinfo.items.guid[$i] + "/filers/" + $getinfo.items.filer_serial_number[$i] + "/"

   $volumeinfo = Invoke-RestMethod -Uri $volumefilerurl -Method Get -Headers $headers
   $datastring = "$($getinfo.items.name[$i]),$($getinfo.items.guid[$i]),$($filerinfo.description),$($getinfo.items.filer_serial_number[$i]),$($volumeinfo.status.accessible_data),$($getinfo.items.provider[$i].name)"
   Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
   Start-Sleep -s 1.1
   $i++
}
