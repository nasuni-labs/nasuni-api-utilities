#Create a new Nasuni NFS Export using the specified parameters

#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#specify Nasuni volume guid and filer serial number
$filer_serial = "InsertFilerSerial"
$volume_guid = "InsertVolumeGuid"

#specify export information
#export name
$exportName = "InsertExportName"
#export path - path to a folder within the volume.
$path = "/"
#export comment
$comment = "InsertExportComments"
#enable read only access for the export: true/false - default value is "false"
$readonly = "false"
#define the default hostspec for the export, the same as allowed hosts in the UI
$hostspec = "*"
#access mode: root_squash (default), no_root_squash (All Users Permitted),all_squash (Anonymize All Users)
$accessMode = "root_squash"
#set the perf mode: sync (default), async (Asynchronous Replies), no_wdelay (No Write Delay) 
$perfMode = "no_wdelay"
#configure security options: sys (default), krb5 (Authentication), krb5i (Integrity Protection), krb5p (Privacy Protection)
$secOptions = "sys"

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
 
#Create the export
#set the create export URL
$createExportUrl="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial + "/exports/"
 
#body for export create
$body = @"
{
    "name": "$ExportName",
    "path": "$path",
    "comment": "$comment",
    "readonly": "$readonly",
    "hostspec": "$hostspec",
    "access_mode": "$accessMode",
    "perf_mode": "$perfMode",
	"sec_options": [
        "$secOptions"
    ]
}
"@

#create the export
try { $response=Invoke-RestMethod -Uri $createExportUrl -Method Post -Headers $headers -Body $body} catch {Failure}
write-output $response | ConvertTo-Json
