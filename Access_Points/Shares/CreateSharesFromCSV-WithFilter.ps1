#creates shares from a CSV with some hard-coded presets for shares
#CSV column order - shareid(skipped for during share creation),Volume_GUID,volume_name,filer_serial_number,filer_nameshare_name,path,comment,readonly,browseable,authAuthall,authRo_users,authRw_users,authDeny_users,authRo_groups,authRw_groups,authDeny_groups,hosts_allow,hide_unreadable,enable_previous_vers,case_sensitive,enable_snapshot_dirs,homedir_support,mobile,browser_access,aio_enabled,veto_files,fruit_enabled,smb_encrypt,shared_links_enabled,link_force_password,link_allow_rw,external_share_url,link_expire_limit,link_auth.authall,link_authAllow_groups_ro,link_auth.allow_groups_rw,link_auth.deny_groups,link_auth.allow_users_ro,link_auth.allow_users_rw,link_auth.deny_users

#The following variables are accepted on the commandline: matchFilerSN (mandatory), matchVolumeSN (optional)
#match shares based on the specified commandline parameters
param ([Parameter(Mandatory)]$matchFilerSN,$matchVolumeGuid)

#populate NMC hostname or IP address
$hostname = "InsertNMChostname"

<#Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#provide the path to input CSV
$csvPath = 'c:\import\AllShareProperties.csv'

#end variables

#convert volumeguid input to an array
#if no volume create a empty array
if ($null -eq $matchVolumeGuid) {$matchVolumeGuidArray = @()}
else { #split the volume to create an array
$matchVolumeGuidArray = $matchVolumeGuid.Split(",")
}

#set the filtering mode for shares
if ($matchVolumeGuidArray.count -eq 0) {$VolumeMatchMode = $false} else {$VolumeMatchMode = $true}

#Build connection headers
#Allow untrusted SSL certs
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

#Begin share creation
#read the contents of the CSV into variables
$shares = Get-Content $csvPath | Select-Object -Skip 1 | ConvertFrom-Csv -header "shareid","Volume_GUID","Volume_Name","filer_serial_number","filer_name","share_name","path","comment","readonly","browseable","authAuthall","authRo_users","authRw_users","authDeny_users","authRo_groups","authRw_groups","authDeny_groups","hosts_allow","hide_unreadable","enable_previous_vers","case_sensitive","enable_snapshot_dirs","homedir_support","mobile","browser_access","aio_enabled","veto_files","fruit_enabled","smb_encrypt","shared_links_enabled","link_force_password","link_allow_rw","external_share_url","link_expire_limit","link_authAuthall","link_authAllow_groups_ro","link_authAllow_groups_rw","link_authDeny_groups","link_authAllow_users_ro","link_authAllow_users_rw","link_authDeny_users"

ForEach ($share in $shares) {
    $volume_guid = $($share.Volume_Guid)
    $filer_serial_number = $($share.filer_serial_number)
    #check to see if the filer SN for the share matches the specified SN
    $isFiler = $matchFilerSN.Contains($filer_serial_number)
    #match against input for shares to match before entering the rest of the loop
    #if a volume guid has been entered, check for the volume GUID and filer serial and skip no match
    if ($VolumeMatchMode -eq $true) {
        $isVolume = $matchVolumeGuidArray.Contains($volume_guid)
        if (($isVolume -eq $false) -or ($isFiler -eq $false)) {continue}
        }
    else { #only check for the filer serial and skip if no match
        if ($isFiler -eq $false) {continue}
        }
    #get the rest of the share properties
    $share_name = $($share.share_name)
    $path = $($share.path) -replace '\\','\\'
    $comment = $($share.comment)
    $readonly = $($share.readonly).ToLower()
    $browseable = $($share.browseable).ToLower()
    if (!$share.authAuthall) {$authAuthall = "true"} else {$authAuthall = $($share.authAuthall).ToLower()}
    if (!$share.authRo_users) {Clear-Variable authRo_users -ErrorAction SilentlyContinue} else {$authRo_users = "'"+$($share.authRo_users)+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.authRw_users) {Clear-Variable authRw_users -ErrorAction SilentlyContinue} else {$authRw_users = "'"+$($share.authRw_users)+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.authDeny_users) {Clear-Variable authDeny_users -ErrorAction SilentlyContinue} else {$authDeny_users = "'"+$($share.authDeny_users)+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.authRo_groups) {Clear-Variable authRo_groups -ErrorAction SilentlyContinue} else {$authRo_groups = "'"+$($share.authRo_groups)+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.authRw_groups) {Clear-Variable authRw_groups -ErrorAction SilentlyContinue} else {$authRw_groups = "'"+$($share.authRw_groups)+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.authDeny_groups) {Clear-Variable authDeny_groups -ErrorAction SilentlyContinue} else {$authDeny_groups = "'"+$($share.authDeny_groups)+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    $hosts_allow = $($share.hosts_allow) -replace ";"," "
    if (!$share.hide_unreadable){$hide_unreadable = "true"} else {$hide_unreadable = $($share.hide_unreadable).ToLower()}
    if (!$share.enable_previous_vers){$enable_previous_vers = "false"} else {$enable_previous_vers = $($share.enable_previous_vers).ToLower()}
    if (!$share.case_sensitive){$case_sensitive = "false"} else {$case_sensitive = $($share.case_sensitive).ToLower()}
    if (!$share.enable_snapshot_dirs){$enable_snapshot_dirs = "false"} else {$enable_snapshot_dirs = $($share.enable_snapshot_dirs).ToLower()}
    if (!$share.homedir_support){$homedir_support = "0"} else {$homedir_support = $($share.homedir_support)}
    if (!$share.mobile){$mobile = "false"} else {$mobile = $($share.mobile).ToLower()}
    if (!$share.browser_access) {$browser_access = "false"} else {$browser_access = $($share.browser_access).ToLower()}
    if (!$share.aio_enabled) {$aio_enabled = "true"} else {$aio_enabled = $($share.aio_enabled).ToLower()}
    $veto_files = $($share.veto_files) -replace ";", "\r\n"
    if (!$share.fruit_enabled){$fruit_enabled = "false"} else {$fruit_enabled = $($share.fruit_enabled).ToLower()}
    if (!$share.smb_encrypt){$smb_encrypt = ""} else {$smb_encrypt = $($share.smb_encrypt)}
    if (!$share.shared_links_enabled) {$shared_links_enabled = "false"} else {$shared_links_enabled = $($share.shared_links_enabled).ToLower()}
    if (!$share.link_force_password) {$link_force_password = "true"} else {$link_force_password = $($share.link_force_password).ToLower()}
    if (!$share.link_allow_rw) {$link_allow_rw = "false"} else {$link_allow_rw = $($share.link_allow_rw).ToLower()}
    $external_share_url = $($share.external_share_url)
    if (!$share.link_expire_limit) {$link_expire_limit = 30} else {$link_expire_limit = $($share.link_expire_limit)}
    if (!$share.link_authAuthall) {$link_authAuthall = "true"} else {$link_authAuthall = $($share.link_authAuthall).ToLower()}
    if (!$share.link_authAllow_groups_ro) {Clear-Variable link_authAllow_groups_ro -ErrorAction SilentlyContinue} else {$link_authAllow_groups_ro = "'"+$($share.link_authAllow_groups_ro)+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.link_authAllow_groups_rw) {Clear-Variable link_authAllow_groups_rw -ErrorAction SilentlyContinue} else {$link_authAllow_groups_rw = "'"+$($share.link_authAllow_groups_rw)+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.link_authDeny_groups) {Clear-Variable link_authDeny_groups -ErrorAction SilentlyContinue} else {$link_authDeny_groups = "'"+$($share.link_authDeny_groups)+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.link_authAllow_users_ro) {Clear-Variable link_authAllow_users_ro -ErrorAction SilentlyContinue} else {$link_authAllow_users_ro = "'"+$($share.link_authAllow_users_ro)+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.link_authAllow_users_rw) {Clear-Variable link_authAllow_users_rw -ErrorAction SilentlyContinue} else {$link_authAllow_users_rw = "'"+$($share.link_authAllow_users_rw)+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.link_authDeny_users) {Clear-Variable link_authDeny_users -ErrorAction SilentlyContinue } else {$link_authDeny_users = "'"+$($share.link_authDeny_users)+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}

    #set up the URL for the create share NMC endpoint
    $url="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial_number + "/shares/"

    #body for share create
    $body = @"
    {
    "name": "$share_name",
    "path": "$path",
    "comment": "$comment",
    "readonly": $readonly,
    "browseable": $browseable,
    "hosts_allow": "$hosts_allow",
    "hide_unreadable": $hide_unreadable,
    "enable_previous_vers": $enable_previous_vers,
    "case_sensitive": $case_sensitive,
    "enable_snapshot_dirs": $enable_snapshot_dirs,
    "homedir_support": $homedir_support,
    "mobile": $mobile,
    "browser_access": $browser_access,
    "browser_access_settings": {
        "shared_links_enabled": $shared_links_enabled,
        "link_force_password": $link_force_password,
        "link_allow_rw": $link_allow_rw,
        "external_share_url": "$external_share_url",
        "link_expire_limit": $link_expire_limit,
        "link_auth": {
            "authall": $link_authAuthall,
            "allow_groups_ro": [$link_authAllow_groups_ro],
            "allow_groups_rw": [$link_authAllow_groups_rw],
            "deny_groups": [$link_authDeny_groups],
            "allow_users_ro": [$link_authAllow_users_ro],
            "allow_users_rw": [$link_authAllow_users_rw],
            "deny_users": [$link_authDeny_users]
        }
    },
    "aio_enabled": $aio_enabled,
    "veto_files": "$veto_files",
    "fruit_enabled": $fruit_enabled,
    "smb_encrypt": "$smb_encrypt",
    "auth": {
        "authall": $authAuthall,
        "rw_groups": [$authRw_groups],
        "ro_groups": [$authRo_groups],
        "deny_groups": [$authDeny_groups],
        "rw_users": [$authRw_users],
        "ro_users": [$authRo_users],
        "deny_users": [$authDeny_users]
    }}
"@

    $jsonBody = $body | ConvertTo-Json -Depth 3 | ConvertFrom-Json -Depth 3
    
    #create the share
    $response=Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $jsonBody

    #write the response of each share creation request to the console
    $output = "ShareName: " + $share_name + ", Path: " + $path + ", Volume GUID: " + $volume_guid + ", Message Status: " + $response.message.status + ", Message ID: " + $response.message.id
    write-output $output

    #sleep between creating shares to avoid NMC API throttling
    Start-Sleep -s 1.1
}
