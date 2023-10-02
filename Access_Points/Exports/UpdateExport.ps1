#Update Existing NFS Export
 
#populate NMC hostname and credentials
$hostname = "nmc.coan.com"
  
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#specify Nasuni volume guid and filer serial number
$filer_serial = "InsertFilerSerial"
$volume_guid = "InsertVolumeGuid"

#export id - obtain using the list exports API endpoint or the ExportAllNFSExportsToCSV script
$export_id = "InsertExportID"
#export comment
$comment = "InsertComment"
#enable read only access for the export: true/false - default value is "false"
$readonly = "false"
#define the default hostspec for the export, the same as allowed hosts in the UI
$hostspec = "*"
#access mode: root_squash (default), no_root_squash (All Users Permitted),all_squash (Anonymize All Users)
$accessMode = "root_squash"
#set the perf mode: sync (default), async (Asynchronous Replies), no_wdelay (No Write Delay) 
$perfMode = "sync"
#configure security options: sys (default), krb5 (Authentication), krb5i (Integrity Protection), krb5p (Privacy Protection)
$secOptions = "sys"


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

#Build json body for export update
$updateBody = @"
{
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
 
#Update the export
$UpdateExportURL="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial + "/exports/" + $export_id + "/"
$response=Invoke-RestMethod -Uri $UpdateExportURL -Headers $headers -Method Patch  -Body $UpdateBody
write-output $response | ConvertTo-Json

	


