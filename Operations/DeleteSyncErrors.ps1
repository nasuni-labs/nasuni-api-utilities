#Delete Sync Errors using the Messages NMC API endpoints to list and delete messages
#list messages - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#nasuni-management-console-api-messages
#delete message - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#delete-message
 
#populate NMC hostname and credentials
$hostname = "insertHostname"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#match by sync error type and status code
#example codes - set GFL for path (fsbrowser_globallock_edit); Refresh info for path (fsbrowser_stat_item); Create a Share (volumes_shares_add)

$StatusCode = "volumes_shares_add"
$StatusType = "failure"

#number of messages to return from the messages api endpoint
$limit = 1000

#end variables

#combine credentials for token request
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'
 
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
 
#Connect to the Messages endpoint and list messages
$MessagesUrl="https://"+$hostname+"/api/v1.1/messages/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$Messages = Invoke-RestMethod -Uri $MessagesUrl -Method Get -Headers $headers


#look for sync errors with a status that matches the specified status code and status type and clear them
foreach($i in 0..($Messages.items.Count-1)){
    If (($Messages.items[$i].code -eq $StatusCode) -and ($Messages.items[$i].status -eq $StatusType))
    {
    $DeleteURL = $Messages.items[$i].links.acknowledge.href
    write-output $Messages.items[$i].error.description
    $CleanSync = Invoke-RestMethod -Uri $DeleteURL -Method Delete -Headers $headers -Body $credentials
    start-sleep 1.1
    }
$i++
}

