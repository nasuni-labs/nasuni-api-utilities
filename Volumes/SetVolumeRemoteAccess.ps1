#Configure Remote Access for the Specified Volume

#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
 
#Path to the NMC API authentication token input file
$tokenFile = "c:\nasuni\token.txt"
 
#specify Nasuni volume guid
$volume_guid = "insertVolumeGuid"

#Remote Access settings
#Enable Remote Access - True/False
$remoteAccessEnabled = "True"
#Remote Access Permissions: readwrite (all have RW access), readonly (all have R access), custom (requires per Edge Appliance settings and further script development)
$remoteAccessPermissions = "readwrite"

#end variables
 
#function for error handling
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
}}
  
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
  
#Set the URL for the Update Volume NMC API Endpoint
$volumeUpdateUrl="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/"
  
#body for remote access settings
$body = @"
{
    "remote_access": {
        "enabled": "$remoteAccessEnabled",
        "access_permissions": "$remoteAccessPermissions"
        }
 
}
"@

#Configure Remote Access
try { $response=Invoke-RestMethod -Uri $volumeUpdateUrl -Method Patch -Headers $headers -Body $body} catch {Failure}
write-output $response | ConvertTo-Json
