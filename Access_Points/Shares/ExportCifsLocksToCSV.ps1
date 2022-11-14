#Export Cifs locks for the specified filer to CSV

#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#Path for CSV Export
$reportFile = "c:\export\CIFSLocks.csv"

#Filer Serial
$filer_serial = 'InsertFilerSerialHere'

#Number of cifs locks to return
$limit = 10000

#NMC API version - supported values: v1.1 (22.1 NMC and older), v1.2 (22.2 NMC and higher)
#do not use v1 with this script--v1 has a different URL/schema for cifslocks
$nmcApiVersion = "v1.2"

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
$url="https://"+$hostname+"/api/" + $nmcApiVersion + "/auth/login/"
 
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)

#List CIFS locks for filer NMC API endpoint
$CifsLocksUrl="https://"+$hostname+"/api/" + $nmcApiVersion + "/filers/" + $filer_serial +"/cifsclients/locks/?limit=" + $limit+ "&offset=0"
$FormatEnumerationLimit=-1
$GetCifsLocks = Invoke-RestMethod -Uri $CifsLocksUrl -Method Get -Headers $headers

#initialize csv output file
$csvHeader = "type,client,share,file_path,user"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting CIFS Locks information to: " + $reportFile)

foreach($i in 0..($GetCifsLocks.total-1)){
    $datastring =  "$($GetCifsLocks.items[$i].type),$($GetCifsLocks.items[$i].client),$($GetCifsLocks.items[$i].share),$($GetCifsLocks.items[$i].file_path),$($GetCifsLocks.items[$i].user)"
    Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
} 
