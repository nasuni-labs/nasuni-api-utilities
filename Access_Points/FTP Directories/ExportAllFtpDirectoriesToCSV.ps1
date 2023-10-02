#Export all FTP Directories and Settings to CSV

#populate NMC hostname and credentials
$hostname = "InsertNMChostname"
 
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Path for CSV Export
$reportFile = "c:\export\ExportFTPDirectories.csv"

#Number of FTP directories to return
$limit = 1000

#Permissions on new files - umask reference
#000 No Extra Restrictions (Default)
#002 Read-Only Others
#022 Read-Only Groups and Others
#006 Restrict Others
#066 Restrict Groups and Others
#026 Read-Only Groups, Restrict Others

#end variables

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

#Connect to the List all FTP directories for filer NMC API endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/filers/ftp-directories/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#initialize csv output file
$csvHeader = "FtpId,Volume_GUID,filer_serial_number,ftp_name,path,comment,readonly,visibility,ip_restrictions,allowed_users,allowed_groups,allow_anonymous,anonymous_only,Permissions_on_new_files,hide_ownership,use_temporary_files_during_upload"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting FTP Directory Information to: " + $reportFile)

foreach($i in 0..($getinfo.items.Count-1)){
    $FtpId = $getinfo.items[$i].id
    $Volume_GUID = $getinfo.items[$i].Volume_Guid
    $filer_serial_number = $getinfo.items[$i].Filer_Serial_Number
    $ftp_name = $getinfo.items[$i].name
    $path = $getinfo.items[$i].path
    $comment = $getinfo.items[$i].comment
    $readonly = $getinfo.items[$i].readonly
    $visibility = $getinfo.items[$i].visibility
    $ip_restrictions = $getinfo.items[$i].allow_from -replace ",",";"
    $allow_users = $getinfo.items[$i].allow_users -replace ", ",";"
    $allow_groups = $getinfo.items[$i].allow_groups -replace ", ",";"
    $allow_anonymous = $getinfo.items[$i].anonymous
    $anonymous_only = $getinfo.items[$i].anonymous_only
    $umask = $getinfo.items[$i].umask
    $hide_ownership = $getinfo.items[$i].hide_ownership
    $hidden_stores = $getinfo.items[$i].hidden_stores

    $datastring = "$FtpID,$Volume_Guid,$Filer_Serial_Number,$ftp_name,$path,$comment,$readonly,$visibility,$ip_restrictions,$allow_users,$allow_groups,$allow_anonymous,$anonymous_only,$umask,$hide_ownership,$hidden_stores"
    Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
} 
