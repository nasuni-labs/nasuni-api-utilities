#Replicates missing shares from one Edge Appliance to another by comparing share names, excluding shares for volumes that are not connected to the destination

#populate NMC hostname and credentials
$hostname = "InsertNMChostname"

<#Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#enter the source and destination Edge Appliance serial numbers
$SourceFilerSerialNumber = "insertSourceSerial"
$DestinationFilerSerialNumber = "insertDestinationSerial"

#Number of shares to return
$limit = 1000

#end variables

#Build connection headers
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

#Connect to the List Volume Connections endpoint and filter for volumes connected to the destination filer serial
$getVolumeConnectionsUrl="https://"+$hostname+"/api/v1.1/volumes/filer-connections/?limit=" + $limit + "&offset=0"
$getVolumeConnections = Invoke-RestMethod -Uri $getVolumeConnectionsUrl -Method Get -Headers $headers
$filteredVolumeConnections = $getVolumeConnections.items | Where-Object -FilterScript { ($_.filer_serial_number -like $DestinationFilerSerialNumber) -and ($_.connected -like "True") }
$filteredVolumeConnectionsVolumeGuids = @($filteredVolumeConnections.volume_guid)

#List Volumes to join the master filer serial number with list of connected serial numbers
$getVolumesUrl="https://"+$hostname+"/api/v1.1/volumes/?limit=" + $limit + "&offset=0"
$getVolumes = Invoke-RestMethod -Uri $getVolumesUrl -Method Get -Headers $headers

#Connect to the List all shares for filer NMC API endpoint
$getSharesUrl="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$getShares = Invoke-RestMethod -Uri $getSharesUrl -Method Get -Headers $headers
$getShareItems = $getShares.items
$sourceShares = $getShareItems | Where-Object -FilterScript { $_.filer_serial_number -like $sourceFilerSerialNumber }
$destinationShares = $getShareItems | Where-Object -FilterScript { $_.filer_serial_number -like $destinationFilerSerialNumber }
$missingOnDestination = Compare-Object -ReferenceObject $sourceShares.name -DifferenceObject $destinationShares.name

ForEach ($share in $sourceShares) {
    #add the volume owner serial number to the list
    $filteredGetVolumes = $getVolumes.items | Where-Object -FilterScript { $_.guid -like $($share.Volume_Guid) }
    $filteredGetVolumeFilerSerial = @($filteredGetVolumes.filer_serial_number)
#check to see if the required variables are populated before proceeding
if ( ($null -eq $missingOnDestination) -or ( ($null -eq $filteredGetVolumes) -and ($null -eq $filteredGetVolumeFilerSerial) )) {} else {
    $inShare = $false

#loop through the list of missing shares to see if missing share name matches
ForEach ($missing in $missingOnDestination.InputObject) {
    if ($share.name -like $missing) {
        $inShare = $true
    }
}
    #next check to see if the share is missing and if the volume has been shared to the selected filer or if the filer serial is the master
if (($inShare -eq $true) -and ( ($FilteredVolumeConnectionsVolumeGuids.Contains($share.volume_guid)) -or (   ($inShare -eq $true) -and ($filteredGetVolumeFilerSerial.Contains($DestinationFilerSerialNumber)) ))) {
    $volume_guid = $($share.Volume_Guid)
    $filer_serial_number = $DestinationFilerSerialNumber
    $share_name = $($share.name)
    $path = $($share.path) -replace '\\','\\'
    $comment = $($share.comment)
    if ($share.readonly -eq $true) {$readonly = "true"} else {$readonly = "false"}
    if ($share.browseable -eq $true) {$browseable = "true"} else {$browseable = "false"}
    if ($share.auth.authall -eq $false) {$authAuthall = "false"} else {$authAuthall = "true"}
    if (!$share.auth.ro_users) {Clear-Variable authRo_users -ErrorAction SilentlyContinue} else {$authRo_users = "'"+$($share.auth.ro_users -join ";")+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.auth.rw_users) {Clear-Variable authRw_users -ErrorAction SilentlyContinue} else {$authRw_users = "'"+$($share.auth.rw_users -join ";")+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.auth.deny_users) {Clear-Variable authDeny_users -ErrorAction SilentlyContinue} else {$authDeny_users = "'"+$($share.auth.deny_users -join ";")+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.auth.ro_groups) {Clear-Variable authRo_groups -ErrorAction SilentlyContinue} else {$authRo_groups = "'"+$($share.auth.ro_groups -join ";")+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.auth.rw_groups) {Clear-Variable authRw_groups -ErrorAction SilentlyContinue} else {$authRw_groups = "'"+$($share.auth.rw_groups -join ";")+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.auth.deny_groups) {Clear-Variable authDeny_groups -ErrorAction SilentlyContinue} else {$authDeny_groups = "'"+$($share.auth.deny_groups -join ";")+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    $hosts_allow = $($share.hosts_allow)
    if ($share.hide_unreadable -eq $true) {$hide_unreadable = "true"} else {$hide_unreadable = "false"}
    if ($share.enable_previous_vers -eq $true) {$enable_previous_vers = "true"} else {$enable_previous_vers = "false"}
    if ($share.case_sensitive -eq $true) {$case_sensitive = "true"} else {$case_sensitive = "false"}
    if ($share.enable_snapshot_dirs -eq $true) {$enable_snapshot_dirs = "true"} else {$enable_snapshot_dirs = "false"}
    $homedir_support = $($share.homedir_support)
    if ($share.mobile -eq $true) {$mobile = "true"} else {$mobile = "false"}
    if ($share.browser_access -eq $true) {$browser_access = "true"} else {$browser_access = "false"}
    if ($share.aio_enabled -eq $true) {$aio_enabled = "true"} else {$aio_enabled = "false"}
    $veto_files = $share.veto_files -replace "`r`n","\r\n"
    if ($share.fruit_enabled -eq $true) {$fruit_enabled = "true"} else {$fruit_enabled = "false"}
    $smb_encrypt = $($share.smb_encrypt)
    if ($share.browser_access_settings.shared_links_enabled -eq $true) {$shared_links_enabled = "true"} else {$shared_links_enabled = "false"}
    if ($(!$share.browser_access_settings.link_force_password)) {$link_force_password = "false"} else {$link_force_password = "true"}
    if ($(!$share.browser_access_settings.link_allow_rw)) {$link_allow_rw = "false"} else {$link_allow_rw = "true"}
    $external_share_url = $($share.browser_access_settings.external_share_url)
    if (!$share.browser_access_settings.link_expire_limit) {$link_expire_limit = 30} else {$link_expire_limit = $($share.browser_access_settings.link_expire_limit)}
    if ($share.browser_access_settings.link_auth.authall -eq $false) {$link_authAuthall = "false"} else {$link_authAuthall = "true"}
    if (!$share.browser_access_settings.link_auth.allow_groups_ro) {Clear-Variable link_authAllow_groups_ro -ErrorAction SilentlyContinue} else {$link_authAllow_groups_ro = "'"+$($share.browser_access_settings.link_auth.allow_groups_ro -join ";")+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.browser_access_settings.link_auth.allow_groups_rw) {Clear-Variable link_authAllow_groups_rw -ErrorAction SilentlyContinue} else {$link_authAllow_groups_rw = "'"+$($share.browser_access_settings.link_auth.allow_groups_rw -join ";")+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.browser_access_settings.link_auth.deny_groups) {Clear-Variable link_authDeny_groups -ErrorAction SilentlyContinue} else {$link_authDeny_groups = "'"+$($share.browser_access_settings.link_auth.deny_groups -join ";")+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.browser_access_settings.link_auth.allow_users_ro) {Clear-Variable link_authAllow_users_ro -ErrorAction SilentlyContinue} else {$link_authAllow_users_ro = "'"+$($share.browser_access_settings.link_auth.allow_users_ro -join ";")+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.browser_access_settings.link_auth.allow_users_rw) {Clear-Variable link_authAllow_users_rw -ErrorAction SilentlyContinue} else {$link_authAllow_users_rw = "'"+$($share.browser_access_settings.link_auth.allow_users_rw -join ";")+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}
    if (!$share.browser_access_settings.link_auth.deny_users) {Clear-Variable link_authDeny_users -ErrorAction SilentlyContinue} else {$link_authDeny_users = "'"+$($share.browser_access_settings.link_auth.deny_users -join ";")+"'" -replace '\\','\\' -replace ';',''',''' -replace "'",'"'}

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
}}
