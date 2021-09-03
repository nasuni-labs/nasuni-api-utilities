#Create a new Nasuni SMB share using the specified parameters

#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'
 
#specify Nasuni volume guid and filer serial number
$filer_serial = "InsertFilerSerialHere"
$volume_guid = "InsertVolumeGuidHere"
 
#specify share information
#share name
$ShareName = "InsertShareName"
#share path - path to folder within the volume. Use two "\\" rather than one.
$path = "\\folder\\path"
#share comment
$comment = "InsertShareComment"
#enable read only access for the share: true/false - default value is "false"
$readonly = "false"
#should the share be browsable/visible? true/false - default value is "true"
$browseable = "true"
#whether to allow authenticated users full share access. Should be set to "false" if specificying ROUsers, ROGroups, RWUsers, or RWGroups. default is "true"
$authall = "true"
#list of read only user(s) separated by commas if more than one entry applies. Format: '"DOMAIN\\sAMAccountName","DOMAIN\\sAMAccountName2"'
$ROUsers = ''
#list of read only group(s) separated by commas. 
$ROGroups = ''
#list of read write user(s) separated by commas. 
$RWUsers = ''
#list of read write groups(s) separated by commas.
$RWGroups = ''
#specify lists of allowed hosts. Null value for no restrictions. default is none
$hosts_allow = ""
#hide unreadable folders and files - default is "true"
$hide_unreadable = "true"
#enable previous versions windows integration for the share: true/false - default is "faulse"
$enable_previous_vers = "false"
#enable case sensitivity for the share: true/false - default is "false"
$case_sensitive = "false"
#enable snapshot directories for the share: true/false - default is "false"
$enable_snapshot_dirs = "false"
#enable home directory access for the share: 0/1 - default is "0"
$homedir_support = "0"
#enable mobile access for the share: true/false - default is "false"
$mobile = "false"
#enable browser access for the share: true/false - default is "false"
$browser_access = "false"
#enable Asynchronous I/O - default is "true"
$aio_enabled = "true"
#pattern of files to block - default is none
$veto_files = ""
#Enable Enhanced Support for Mac OS X Clients - default is "false"
$fruit_enabled = "false"
#Require SMB encryption - options are blank which corresponds to "optional", "desired" or "required" can also be specified.
$smb_encrypt = ""

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
 
#construct Uri
$url="https://"+$hostname+"/api/v1.1/auth/login/"
  
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)
 
#Create the share
$url="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial + "/shares/"
 
 
#body for share create
$body = @"
{
    "name": "$ShareName",
    "path": "$path",
    "comment": "$comment",
    "readonly": "$readonly",
    "browseable": "$browseable",
	"auth": {
		"authall": "$authall",
        "ro_users": [$ROUsers],
        "rw_users": [$RWUsers],
        "ro_groups": [$ROGroups],
        "rw_groups": [$RWGroups]
        },
    "hosts_allow": "$hosts_allow",
    "hide_unreadable": "$hide_unreadable",
    "enable_previous_vers": "$enable_previous_vers",
    "case_sensitive": "$case_sensitive",
    "enable_snapshot_dirs": "$enable_snapshot_dirs",
    "homedir_support": "$homedir_support",
    "mobile": "$mobile",
    "browser_access": "$browser_access",
    "aio_enabled": "$aio_enabled",
    "veto_files": "$veto_files",
    "fruit_enabled": "$fruit_enabled",
    "smb_encrypt": "$smb_encrypt"

}
"@

#create the share
try { $response=Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body} catch {Failure}
write-output $response | ConvertTo-Json