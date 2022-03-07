#Export Cifs clients to CSV
#Uses the v1 version of the CIFSclients API: http://docs.api.nasuni.com/nmc/api/1.0.0/index.html#retrieve-a-list-of-all-filers--each-with-a-list-of-cifs-clients-connected-to-it-

#populate NMC hostname and credentials
$hostname = "insertNMChostname"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#Path for CSV Export
$reportFile = "c:\export\CIFSClients.csv"

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

#List CIFS clients NMC API endpoint
$CifsClientsUrl="https://"+$hostname+"/api/v1/filers/cifsclients/"
$FormatEnumerationLimit=-1
$GetCifsClients = Invoke-RestMethod -Uri $CifsClientsUrl -Method Get -Headers $headers

#initialize csv output file
$csvHeader = "serial_number,description,client_name,clientIP,shareName"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting CIFS Clients information to: " + $reportFile)

foreach($i in 0..($GetCifsClients.items.Count-1)){
	#check to see if no clients are connected
	if ($GetCifsClients.items[$i].cifs_clients.Count -eq 0){
    $datastring =  "$($GetCifsClients.items[$i].serial_number),$($GetCifsClients.items[$i].description),noclients,noClients,noClients"
	}
	else { #if clients are connected write a line for each connected client
		foreach($c in 0..($GetCifsClients.items[$i].cifs_clients.Count-1)){
		$datastring =  "$($GetCifsClients.items[$i].serial_number),$($GetCifsClients.items[$i].description),$($GetCifsClients.items[$i].cifs_clients[$c].client_name),$($GetCifsClients.items[$i].cifs_clients[$c].client),$($GetCifsClients.items[$i].cifs_clients[$c].share)"
		Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
		$c++
		}
	}
	Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
} 