#Export All Shares for a given Volume and Edge Appliance to CSV

#populate NMC hostname or IP address
$hostname = "InsertNMChostname"

#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "InsertUsername"
$password = 'InsertPassword'

#Path for CSV Export
$reportFile = "c:\export\ShareInfo.csv"

#specify the Volume and Edge Appliance information
$filer_serial = "InsertFilerSerialHere"
$volume_guid = "InsertVolumeGuidHere"

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

#Connect to the List all shares for filer NMC API endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial + "/shares/"

#List volumes
$FormatEnumerationLimit=-1
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#initialize csv output file
$csvHeader = "shareid,Volume_GUID,filer_serial,share_name,path,comment,block_files,fruit_enabled,authall,ro_users,ro_groups,rw_users,rw_groups"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting Volume Information to: " + $reportFile)

foreach($i in 0..($getinfo.items.Count-1)){

	$ROUsers = $($getinfo.items[$i].auth.ro_users) -replace '\\', '\'
	$ROGroups = $($getinfo.items[$i].auth.ro_groups) -replace '\\', '\'
	$RWUsers = $($getinfo.items[$i].auth.rw_users) -replace '\\', '\'
	$RWGroups = $($getinfo.items[$i].auth.rw_groups) -replace '\\', '\'
    $datastring =  "$($getinfo.items[$i].id),$($Volume_Guid),$($Filer_Serial),$($getinfo.items[$i].name),$($getinfo.items[$i].path),$($getinfo.items[$i].comment),$($getinfo.items[$i].veto_files),$($getinfo.items[$i].fruit_enabled),$($getinfo.items[$i].auth.authall),$($ROUsers),$($ROGroups),$($RWUsers),$($RWGroups)"
	Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
} 
