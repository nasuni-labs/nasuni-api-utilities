<# Ignore or Delete AV Violations. #>

#populate NMC hostname or IP address
$hostname = "InsertNMChostname"

<#Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#specify Nasuni volume guid and filer serial number
#Volume GUID
$volume_guid = 'InsertVolumeGuid'

#Filer Serial
$filer_serial = 'InsertFilerSerial'


#AV Violation ID - update with ID number for the target violation
#Use the list AV violation endpoints to get all AV violations
$antivirus_id = "AvViolationID"

<# Specify the action to perform (delete_file or ignore_violation).
"delete_file" deletes the associated file and the av violation. This is useful for confirmed AV violations.
"ignore_violation" tells Nasuni to ignore the violation and does not impact the associated file. This is useful for false positives. #>
$action = "delete_file" 

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

#Process the violation
$avProcessUrl = "https://"+$hostname+"/api/v1.2/volumes/$volume_guid/filers/$filer_serial/antivirus-violations/$antivirus_id/?action=$action"

#Send request
Invoke-RestMethod -Uri $avProcessUrl -Method Delete -Headers $headers -ContentType "application/json" -SkipCertificateCheck

