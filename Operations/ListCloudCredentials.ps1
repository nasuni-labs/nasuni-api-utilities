#list cloud credentials and output them to the console

#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"

#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#Number of Credentials to query
$limit = 1000

#end variables

#combine credentails for authentication
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

#List credentials
$CredURL="https://"+$hostname+"/api/v1.1/account/cloud-credentials/?limit="+$limit+"&offset=0"
$getCredInfo = Invoke-RestMethod -Uri $CredURL -Method Get -Headers $headers

#loop through results and output to the screen
$credHeader = "cred_id, name, filer_serial_number, cloud_provider, account, hostname, status, note, in_use"

write-output $credHeader

foreach($i in 0..($getCredInfo.items.Count-1)){
    $datastring = "$($getCredInfo.items[$i].cred_id),$($getCredInfo.items[$i].name),$($getCredinfo.items[$i].filer_serial_number),$($getCredInfo.items[$i].cloud_provider),$($getCredInfo.items[$i].account),$($getCredInfo.items[$i].hostname),$($getCredInfo.items[$i].status),$($getCredInfo.items[$i].note),$($getCredInfo.items[$i].in_use)"
    write-output $datastring
    $i++
}
