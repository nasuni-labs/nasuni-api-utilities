#list cloud credentials and output them to the console

#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"

<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Number of Credentials to query
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

#List credentials
$CredURL="https://"+$hostname+"/api/v1.2/account/cloud-credentials/?limit="+$limit+"&offset=0"
$getCredInfo = Invoke-RestMethod -Uri $CredURL -Method Get -Headers $headers

#loop through results and output to the screen
$credHeader = "cred_uuid, name, filer_serial_number, cloud_provider, account, hostname, status, note, in_use"

write-output $credHeader

foreach($i in 0..($getCredInfo.items.Count-1)){
    $datastring = "$($getCredInfo.items[$i].cred_uuid),$($getCredInfo.items[$i].name),$($getCredinfo.items[$i].filer_serial_number),$($getCredInfo.items[$i].cloud_provider),$($getCredInfo.items[$i].account),$($getCredInfo.items[$i].hostname),$($getCredInfo.items[$i].status),$($getCredInfo.items[$i].note),$($getCredInfo.items[$i].in_use)"
    write-output $datastring
    $i++
}

