#Export Cifs clients to CSV

#populate NMC hostname and credentials
$hostname = "insertNMChostname"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#Path for CSV Export
$reportFile = "c:\export\CIFSClients.csv"

#Number of clients to return
$limit = 10000

#NMC API version - supported values: v1.1 (22.1 NMC and older), v1.2 (22.2 NMC and higher)
#do not use v1 with this script--v1 has a different URL/schema for cifs clients
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

#List CIFS clients NMC API endpoint
$CifsClientsUrl="https://"+$hostname+"/api/" + $nmcApiVersion + "/filers/cifsclients/?limit=" + $limit+ "&offset=0"
$FormatEnumerationLimit=-1
$GetCifsClients = Invoke-RestMethod -Uri $CifsClientsUrl -Method Get -Headers $headers

#initialize csv output file
$csvHeader = "filer_serial_number,user,client_name,clientIP,shareID"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting CIFS Clients information to: " + $reportFile)

if ($GetCifsClients.total -eq 0){
    $datastring =  "noClients,noClients,noClients,noClients,noClients"
    Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
    write-output "no clients connected"
 } else {


#if clients are connected write a line for each connected client
		foreach($i in 0..($GetCifsClients.total.Count)){
		$datastring =  "$($GetCifsClients.items[$i].filer_serial_number),$($GetCifsClients.items[$i].user),$($GetCifsClients.items[$i].client_name),$($GetCifsClients.items[$i].client),$($GetCifsClients.items[$i].share_id)"
		Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
		$i++
		}
	}
