<# Prompts the user for username and password to request an NMC API token and stores the output in a Token file that subsequent scripts can use.
Tokens expire after 8 hours. Usernames for AD accounts support both UPN (user@domain.com) and DOMAIN\samaccountname formats.
Nasuni Native user accounts are also supported. #>

#populate NMC hostname or IP address
$hostname = "InsertNMChostname"

#Path to the token output file
$tokenFile = "c:\nasuni\token.txt"

#end variables

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

#get a credential for authentication
$cred = Get-Credential

#read the user and pass from the cred - replace single backslash in username with double for JSON
$username = $cred.UserName.replace('\','\\')
$password = $cred.GetNetworkCredential().Password

#combine credentials for token request
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

#clear temporary credential variables
Clear-Variable username
Clear-Variable password
 
#construct Uri
$url="https://"+$hostname+"/api/v1.1/auth/login/"

#build JSON headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", 'application/json')
$headers.Add("Content-Type", 'application/json')

#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)

#write the token to the console to verify the script output
write-output $token

#write the updated token to a file
Set-Content $tokenFile $token

