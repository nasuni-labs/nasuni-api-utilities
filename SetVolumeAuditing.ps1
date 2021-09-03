#Enable Auditing and settings for the specified Volume and Filer

#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'
 
#specify Nasuni volume guid and filer serial number
$volume_guid = "InsertVolumeGuidHere"
$filer_serial = "InsertFilerSerialHere"

#Set Audit Parameters
#Enable Auditing - True/False
$AuditingEnabled = "False"
#audit create events - True/False
$EventsCreate = "False"
#audit delete events - True/False
$EventsDelete = "False"
#audit rename events - True/False
$EventsRename = "False"
#audit close events - True/False
$EventsClose = "False"
#audit security events - True/False
$EventsSecurity = "False"
#audit metadata events - True/False
$EventsMetadata = "False"
#audit write events - True/False
$EventsWrite = "False"
#audit read events - True/False
$EventsRead = "False"
#enable audit log pruning - True/False
$PruneAuditLogs = "False"
#days to keep before pruning - True/False
$DaysToKeep = "90"
#export audit events via Syslog - True/False
$SyslogExport = "False"

#end variables

#combine credentials for token request
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'
 
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
  
#construct Uri
$url="https://"+$hostname+"/api/v1.1/auth/login/"
   
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)
  
#Set the URL for Auditing NMC API Endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial + "/"
  
#body for auditing settings
$body = @"
{
    "auditing": {
        "enabled": "$AuditingEnabled",
        "events": { 
            "create": "$EventsCreate",
            "delete": "$EventsDelete",
            "rename": "$EventsRename",
            "close": "$EventsClose",
            "security": "$EventsSecurity",
            "metadata": "$EventsMetadata",
            "write": "$EventsWrite",
            "read": "$EventsRead"
            },
        "logs": {
            "prune_audit_logs": "$PruneAuditLogs",
            "days_to_keep": "$DaysToKeep"
            },
        "syslog_export": "$SyslogExport"
        }
 
}
"@

#Configure Auditing
try { $response=Invoke-RestMethod -Uri $url -Method Patch -Headers $headers -Body $body} catch {Failure}
write-output $response | ConvertTo-Json