#Export All Shares to CSV

#populate NMC hostname and credentials
$hostname = "InsertNMChostname"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required). Nasuni Native user accounts are also supported.
$username = "InsertUsername"
$password = 'InsertPassword'

#Path for CSV Export
$reportFile = "c:\export\ExportShares.csv"

#Number of shares, volumes, and filers to return
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

#List filers to get the a list of filer serial numbers along with names
$filersUrl="https://"+$hostname+"/api/v1.1/filers/?limit=" + $limit + "&offset=0"
$GetFilerInfo = Invoke-RestMethod -Uri $filersUrl -Method Get -Headers $headers 
  
#List volumes to get a list of volume guids and names
$volumeUrl="https://"+$hostname+"/api/v1.1/volumes/?limit=" + $limit + "&offset=0"
$getVolumeInfo = Invoke-RestMethod -Uri $volumeUrl -Method Get -Headers $headers 

#Connect to the List all shares for filer NMC API endpoint
$sharesUrl="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$getShareInfo = Invoke-RestMethod -Uri $sharesUrl -Method Get -Headers $headers

#initialize csv output file
$csvHeader = "shareid,volume_guid,volume_name,filer_serial_number,filer_name,share_name,path,comment,readonly,browseable,authAuthall,authRo_users,authRw_users,authDeny_users,authRo_groups,authRw_groups,authDeny_groups,hosts_allow,hide_unreadable,enable_previous_vers,case_sensitive,enable_snapshot_dirs,homedir_support,mobile,browser_access,aio_enabled,veto_files,fruit_enabled,smb_encrypt,shared_links_enabled,link_force_password,link_allow_rw,external_share_url,link_expire_limit,link_authAuthall,link_authAllow_groups_ro,link_authAllow_groups_rw,link_authDeny_groups,link_authAllow_users_ro,link_authAllow_users_rw,link_authDeny_users"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting Volume Information to: " + $reportFile)

foreach($i in 0..($getShareInfo.items.Count-1)){
    $shareid = $getShareInfo.items[$i].id
    $volume_guid = $getShareInfo.items[$i].Volume_Guid
    $filer_serial_number = $getShareInfo.items[$i].Filer_Serial_Number
    $share_name = $getShareInfo.items[$i].name
    $path = $getShareInfo.items[$i].path
    $comment = $getShareInfo.items[$i].comment
    $readonly = $getShareInfo.items[$i].readonly
    $browseable = $getShareInfo.items[$i].browseable
    $authAuthall = $getShareInfo.items[$i].auth.authall
    $authRo_users = $getShareInfo.items[$i].auth.ro_users -join ";"
    $authRw_users = $getShareInfo.items[$i].auth.rw_users -join ";"
    $authDeny_users = $getShareInfo.items[$i].auth.deny_users -join ";"
    $authRo_groups = $getShareInfo.items[$i].auth.ro_groups -join ";"
    $authRw_groups = $getShareInfo.items[$i].auth.rw_groups -join ";"
    $authDeny_groups = $getShareInfo.items[$i].auth.deny_groups -join ";"
    $hosts_allow = $getShareInfo.items[$i].hosts_allow -replace " ",";"
    $hide_unreadable = $getShareInfo.items[$i].hide_unreadable
    $enable_previous_vers = $getShareInfo.items[$i].enable_previous_vers
    $case_sensitive = $getShareInfo.items[$i].case_sensitive
    $enable_snapshot_dirs = $getShareInfo.items[$i].enable_snapshot_dirs
    $homedir_support = $getShareInfo.items[$i].homedir_support
    $mobile = $getShareInfo.items[$i].mobile
    $browser_access = $getShareInfo.items[$i].browser_access
    $aio_enabled = $getShareInfo.items[$i].aio_enabled
    $veto_files = $getShareInfo.items[$i].veto_files -replace "`r`n",";"
    $fruit_enabled = $getShareInfo.items[$i].fruit_enabled
    $smb_encrypt = $getShareInfo.items[$i].smb_encrypt
    $shared_links_enabled = $getShareInfo.items[$i].browser_access_settings.shared_links_enabled
    $link_force_password = $getShareInfo.items[$i].browser_access_settings.link_force_password
    $link_allow_rw = $getShareInfo.items[$i].browser_access_settings.link_allow_rw
    $external_share_url = $getShareInfo.items[$i].browser_access_settings.external_share_url
    $link_expire_limit = $getShareInfo.items[$i].browser_access_settings.link_expire_limit
    $link_authAuthall = $getShareInfo.items[$i].browser_access_settings.link_auth.authall
    $link_authAllow_groups_ro = $getShareInfo.items[$i].browser_access_settings.link_auth.allow_groups_ro -join ";"
    $link_authAllow_groups_rw = $getShareInfo.items[$i].browser_access_settings.link_auth.allow_groups_rw -join ";"
    $link_authDeny_groups = $getShareInfo.items[$i].browser_access_settings.link_auth.deny_groups -join ";"
    $link_authAllow_users_ro = $getShareInfo.items[$i].browser_access_settings.link_auth.allow_users_ro -join ";"
    $link_authAllow_users_rw = $getShareInfo.items[$i].browser_access_settings.link_auth.allow_users_rw -join ";"
    $link_authDeny_users = $getShareInfo.items[$i].browser_access_settings.link_auth.deny_users -join ";"
        
        #Loop through the list of filers to get the filer names
        foreach($m in 0..($getFilerInfo.items.Count-1)){
            $getFilerSerial = $getFilerInfo.items[$m].serial_number
            $getFilerDescription = $getFilerInfo.items[$m].description
            if ($getFilerSerial -eq  $filer_serial_number) {$filerName = $getFilerDescription}
        $m++}

        #Loop through the list of volumes to get the volume names
        foreach($n in 0..($getVolumeInfo.items.Count-1)){
            $getVolumeGuid = $GetVolumeInfo.items[$n].guid
            $getVolumeDescription = $getVolumeInfo.items[$n].name
            if ($getVolumeGuid -eq  $volume_guid) {$volumeName = $getVolumeDescription}
        $n++}

    $datastring = "$shareid,$volume_guid,$volumeName,$filer_serial_number,$filerName,$share_name,$path,$comment,$readonly,$browseable,$AuthAuthall,$AuthRo_users,$AuthRw_users,$authDeny_users,$authRo_groups,$authRw_groups,$authDeny_groups,$hosts_allow,$hide_unreadable,$enable_previous_vers,$case_sensitive,$enable_snapshot_dirs,$homedir_support,$mobile,$browser_access,$aio_enabled,$veto_files,$fruit_enabled,$smb_encrypt,$shared_links_enabled,$link_force_password,$link_allow_rw,$external_share_url,$link_expire_limit,$link_authAuthall,$link_authAllow_groups_ro,$link_authAllow_groups_rw,$link_authDeny_groups,$link_authAllow_users_ro,$link_authAllow_users_rw,$link_authDeny_users"
	Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
} 
