#Delete Sync Errors using the Messages NMC API endpoints to list and delete messages
#list messages - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#nasuni-management-console-api-messages
#delete message - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#delete-message
 
#populate NMC hostname and credentials
$hostname = "insertHostname"

<#Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

<#match by sync error type and status code
example status codes - set GFL for path (fsbrowser_globallock_edit); Refresh info for path (fsbrowser_stat_item); Create a Share (volumes_shares_add)
example status types - failure (because of error); the API does not allow you to delete pending messages #>
$StatusCode = "volumes_shares_add"
$StatusType = "failure"

#number of messages to return from the messages api endpoint
$limit = 1000

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

#Read the token from a file and add it to the headers for the request
$token = Get-Content $tokenFile
$headers.Add("Authorization","Token " + $token)
 
#Connect to the Messages endpoint and list messages
$MessagesUrl="https://"+$hostname+"/api/v1.1/messages/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$Messages = Invoke-RestMethod -Uri $MessagesUrl -Method Get -Headers $headers

#look for sync errors with a status that matches the specified status code and status type and clear them
foreach($i in 0..($Messages.items.Count-1)){
    If (($Messages.items[$i].code -eq $StatusCode) -and ($Messages.items[$i].status -eq $StatusType))
    {
    $DeleteURL = $Messages.items[$i].links.self.href
    $CleanSync = Invoke-RestMethod -Uri $DeleteURL -Method Delete -Headers $headers -Body $credentials
    start-sleep 1.1
    }
$i++
}

