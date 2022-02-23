#uses the Get message endpoint to check on the status of a message
#http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#get-message

#populate NMC hostname or IP address
$hostname = "insertNMChostnameHere"

#Path to the NMC API authentication token input file
$tokenFile = "c:\nasuni\token.txt"

#Supply the message ID you want to check
$messageID = ''

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

#build JSON headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", 'application/json')
$headers.Add("Content-Type", 'application/json')

#construct Uri
$url="https://"+$hostname+"/api/v1.1/auth/login/"
 
#Read the token from a file and add it to the headers for the request
$token = Get-Content $tokenFile
$headers.Add("Authorization","Token " + $token)

#Build the URL for the Get Message Request
$GetMessageURL="https://"+$hostname+"/api/v1.1/messages/" + $messageID + "/"

#Get the message
$getMessageStatus = Invoke-RestMethod -Uri $GetMessageURL -Method Get -Headers $headers

#write the message to the console
write-output $getMessageStatus
