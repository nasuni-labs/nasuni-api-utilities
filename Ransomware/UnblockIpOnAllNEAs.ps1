#Unblock a client IP address on all NEAs

#populate NMC hostname and credentials
$hostname = "host.domain.com"

<#Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#specify IP Address to unBlock
$ipAddress = 'insertIpAddress'

#end variables

#function for error
function Failure {
    if ( $PSVersionTable.PSVersion.Major -lt 6) { #PowerShell 5 and earlier
    $global:result = $_.Exception.Response.GetResponseStream()
    $global:reader = New-Object System.IO.StreamReader($global:result)
    $global:responseBody = $global:reader.ReadToEnd();
    Write-Host -BackgroundColor:Black -ForegroundColor:Red "Status: A system exception was caught."
    Write-Host -BackgroundColor:Black -ForegroundColor:Red $global:responsebody
    Write-Host -BackgroundColor:Black -ForegroundColor:Red "The request body has been saved to `$global:helpme"($result)
    } else { #PowerShell 6 or higher lack support for GetResponseStream
$Message =  $_.ErrorDetails.Message;
Write-Host ("Message: "+ $Message)
}
}
 
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

 
#List Blocked Clients
$blockedClientsUrl="https://"+$hostname+"/api/v1.2/filers/blocked-clients/"
$GetBlockedClients = Invoke-RestMethod -Uri $blockedClientsUrl -Method Get -Headers $headers

foreach($i in 0..($GetBlockedClients.items.Count-1)){
    #check to see if the specified ip address matches the list of blocked ip addresses and only unblock matches
    if ($GetBlockedClients.items[$i].ip_address -eq $ipAddress) {
        #get the filer serial number we can unblock it
        $filerSerial = $GetBlockedClients.items[$i].filer_serial_number
    
        #set the block client IP URL
        $unblockClientIpUrl="https://" +$hostname+ "/api/v1.2/filers/" + $filerSerial + "/blocked-clients/" + $ipAddress + "/"

        #unblock the client IP
        try { $response=Invoke-RestMethod -Uri $unblockClientIpUrl -Method Delete -Headers $headers} catch {Failure}
        write-output $response | ConvertTo-Json

        #sleep between requests to avoid throttling
        Start-Sleep -s 1.1
    }  
$i++
}
