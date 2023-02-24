#Create Nasuni NFS Exports from a CSV
#CSV column order - exportID(skipped for during share creation)Volume_GUID,filer_serial_number,export_name,path,comment,readonly,allowed_hosts,access_mode,perf_mode,sec_options,nfs_host_options(not implemented)

#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#provide the path to input CSV
$csvPath = 'c:\export\ExportedNFSExports.csv'

#end variables
#build credentials for later use
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

 
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

#Begin Export Creation
#read the contents of the CSV into variables
$exports = Get-Content $csvPath | Select-Object -Skip 1 | ConvertFrom-Csv -header "exportId","Volume_GUID","filer_serial_number","export_name","path","comment","readonly","allowed_hosts","access_mode","perf_mode","sec_options","nfs_host_options"
 
#Create the export


ForEach ($export in $exports) {
    $volume_guid = $($export.Volume_Guid)
    $filer_serial = $($export.filer_serial_number)
    $export_name = $($export.export_name)
    $path = $($export.path)
    $comment = $($export.comment)
    $readonly = $($export.readonly)
    $allowed_hosts = $($export.allowed_hosts)
    $access_mode = $($export.access_mode)
    $perf_mode = $($export.perf_mode)
    $sec_options = $($export.sec_options)
 
#body for export create
$body = @"
{
    "name": "$export_name",
    "path": "$path",
    "comment": "$comment",
    "readonly": "$readonly",
    "hostspec": "$allowed_hosts",
    "access_mode": "$access_mode",
    "perf_mode": "$perf_mode",
	"sec_options": [
        "$sec_options"
    ]
}
"@

    #set the create export URL
    $createExportUrl="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial + "/exports/"

    #create the export
    $response =Invoke-RestMethod -Uri $createExportUrl -Method Post -Headers $headers -Body $body

    #write the response of each export creation request to the console
    $output = "ExportName: " + $export_name + ", Path: " + $path + ", Volume GUID: " + $volume_guid + ", Message Status: " + $response.message.status + ", Message ID: " + $response.message.id
    write-output $output

    #sleep between creating exports to avoid NMC API throttling
    Start-Sleep -s 1.1
}