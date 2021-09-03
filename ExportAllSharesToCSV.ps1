#Export All Shares and Settings for a Volumed to a CSV

#populate NMC hostname and credentials
$hostname = "InsertNMChostname"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required). Nasuni Native user accounts are also supported.
$username = "InsertUsername"
$password = "InsertPassword"

#Path for CSV Export
$reportFile = "c:\export\ExportShares.csv"

#Number of shares to return
$limit = 1000

#end variables

#combine credentials for token request
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

#Connect to the List all shares for filer NMC API endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#initialize csv output file
$csvHeader = "shareid,Volume_GUID,filer_serial_number,share_name,path,comment,readonly,browseable,authAuthall,authRo_users,authRw_users,authDeny_users,authRo_groups,authRw_groups,authDeny_groups,hosts_allow,hide_unreadable,enable_previous_vers,case_sensitive,enable_snapshot_dirs,homedir_support,mobile,browser_access,aio_enabled,veto_files,fruit_enabled,smb_encrypt,shared_links_enabled,link_force_password,link_allow_rw,external_share_url,link_expire_limit,link_authAuthall,link_authAllow_groups_ro,link_authAllow_groups_rw,link_authDeny_groups,link_authAllow_users_ro,link_authAllow_users_rw,link_authDeny_users"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting Volume Information to: " + $reportFile)

foreach($i in 0..($getinfo.items.Count-1)){
    $shareid = $getinfo.items[$i].id
    $Volume_GUID = $getinfo.items[$i].Volume_Guid
    $filer_serial_number = $getinfo.items[$i].Filer_Serial_Number
    $share_name = $getinfo.items[$i].name
    $path = $getinfo.items[$i].path
    $comment = $getinfo.items[$i].comment
    $readonly = $getinfo.items[$i].readonly
    $browseable = $getinfo.items[$i].browseable
    $authAuthall = $getinfo.items[$i].auth.authall
    $authRo_users = $getinfo.items[$i].auth.ro_users -join ";"
    $authRw_users = $getinfo.items[$i].auth.rw_users -join ";"
    $authDeny_users = $getinfo.items[$i].auth.deny_users -join ";"
    $authRo_groups = $getinfo.items[$i].auth.ro_groups -join ";"
    $authRw_groups = $getinfo.items[$i].auth.rw_groups -join ";"
    $authDeny_groups = $getinfo.items[$i].auth.deny_groups -join ";"
    $hosts_allow = $getinfo.items[$i].hosts_allow -replace " ",";"
    $hide_unreadable = $getinfo.items[$i].hide_unreadable
    $enable_previous_vers = $getinfo.items[$i].enable_previous_vers
    $case_sensitive = $getinfo.items[$i].case_sensitive
    $enable_snapshot_dirs = $getinfo.items[$i].enable_snapshot_dirs
    $homedir_support = $getinfo.items[$i].homedir_support
    $mobile = $getinfo.items[$i].mobile
    $browser_access = $getinfo.items[$i].browser_access
    $aio_enabled = $getinfo.items[$i].aio_enabled
    $veto_files = $getinfo.items[$i].veto_files -replace "`r`n",";"
    $fruit_enabled = $getinfo.items[$i].fruit_enabled
    $smb_encrypt = $getinfo.items[$i].smb_encrypt
    $shared_links_enabled = $getinfo.items[$i].browser_access_settings.shared_links_enabled
    $link_force_password = $getinfo.items[$i].browser_access_settings.link_force_password
    $link_allow_rw = $getinfo.items[$i].browser_access_settings.link_allow_rw
    $external_share_url = $getinfo.items[$i].browser_access_settings.external_share_url
    $link_expire_limit = $getinfo.items[$i].browser_access_settings.link_expire_limit
    $link_authAuthall = $getinfo.items[$i].browser_access_settings.link_auth.authall
    $link_authAllow_groups_ro = $getinfo.items[$i].browser_access_settings.link_auth.allow_groups_ro -join ";"
    $link_authAllow_groups_rw = $getinfo.items[$i].browser_access_settings.link_auth.allow_groups_rw -join ";"
    $link_authDeny_groups = $getinfo.items[$i].browser_access_settings.link_auth.deny_groups -join ";"
    $link_authAllow_users_ro = $getinfo.items[$i].browser_access_settings.link_auth.allow_users_ro -join ";"
    $link_authAllow_users_rw = $getinfo.items[$i].browser_access_settings.link_auth.allow_users_rw -join ";"
    $link_authDeny_users = $getinfo.items[$i].browser_access_settings.link_auth.deny_users -join ";"

    $datastring = "$shareid,$Volume_Guid,$Filer_Serial_Number,$share_name,$path,$comment,$readonly,$browseable,$AuthAuthall,$AuthRo_users,$AuthRw_users,$authDeny_users,$authRo_groups,$authRw_groups,$authDeny_groups,$hosts_allow,$hide_unreadable,$enable_previous_vers,$case_sensitive,$enable_snapshot_dirs,$homedir_support,$mobile,$browser_access,$aio_enabled,$veto_files,$fruit_enabled,$smb_encrypt,$shared_links_enabled,$link_force_password,$link_allow_rw,$external_share_url,$link_expire_limit,$link_authAuthall,$link_authAllow_groups_ro,$link_authAllow_groups_rw,$link_authDeny_groups,$link_authAllow_users_ro,$link_authAllow_users_rw,$link_authDeny_users"
	Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
} 