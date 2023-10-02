#Export all CIFS Shares, NFS exports, FTP directories, Folder Quotas, Pinned Folders, Auto cache folders, Folder Quotas, Volume Audit Settings, Volume Snap/Sync schedules, and File Alert Service configuration to CSV

#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Path for CSV Exports. The path should end in slash or backslash depending on the platform
$reportDirectory = 'c:\export\ExportEaSettings\'

#API endpoint item limit
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
 
#Read the token from a file and add it to the headers for the request
$token = Get-Content $tokenFile
$headers.Add("Authorization","Token " + $token)

#Connect to the List all shares for Filer NMC API endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#initialize List All Shares Csv output file
$cifsCsvHeader = "shareid,Volume_GUID,filer_serial_number,share_name,path,comment,readonly,browseable,authAuthall,authRo_users,authRw_users,authDeny_users,authRo_groups,authRw_groups,authDeny_groups,hosts_allow,hide_unreadable,enable_previous_vers,case_sensitive,enable_snapshot_dirs,homedir_support,mobile,browser_access,aio_enabled,veto_files,fruit_enabled,smb_encrypt,shared_links_enabled,link_force_password,link_allow_rw,external_share_url,link_expire_limit,link_authAuthall,link_authAllow_groups_ro,link_authAllow_groups_rw,link_authDeny_groups,link_authAllow_users_ro,link_authAllow_users_rw,link_authDeny_users"
$cifsReportFile = $reportDirectory + 'CifsShares.csv'
Out-File -FilePath $cifsReportFile -InputObject $cifsCsvHeader -Encoding UTF8
write-host ("Exporting CIFS Shares Information to: " + $cifsReportFile)

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
	Out-File -FilePath $cifsReportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
} 

#Connect to the List all exports for filer NMC API endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/filers/exports/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#initialize NFS CSV output file
$nfsCsvHeader = "exportId,Volume_GUID,filer_serial_number,export_name,path,comment,readonly,allowed_hosts,access_mode,perf_mode,sec_options,nfs_host_options"
$nfsReportFile = $reportDirectory + 'NfsExports.csv'
Out-File -FilePath $nfsReportFile -InputObject $nfsCsvHeader -Encoding UTF8
write-host ("Exporting NFS Exports Information to: " + $nfsReportFile)

foreach($i in 0..($getinfo.items.Count-1)){
    clear-variable nhoOutput -erroraction 'silentlycontinue'
    $exportId = $getinfo.items[$i].id
    $Volume_GUID = $getinfo.items[$i].Volume_Guid
    $filer_serial_number = $getinfo.items[$i].Filer_Serial_Number
    $export_name = $getinfo.items[$i].name
    $path = $getinfo.items[$i].path
    $comment = $getinfo.items[$i].comment
    $readonly = $getinfo.items[$i].readonly
    $allowed_hosts = $getinfo.items[$i].hostspec -replace ",",";"
    $access_mode = $getinfo.items[$i].access_mode
    $perf_mode = $getinfo.items[$i].perf_mode
    $sec_options = $getinfo.items[$i].sec_options
    $nfs_host_options = $getinfo.items[$i].nfs_host_options
    #loop through host options since it can contain multiple values
    ForEach ($nho in $nfs_host_options) {
        $nhoOutput = $nhoOutput + "allowed_hosts: " + ($nho.hostspec -replace ",",";") + "; access_mode: " + $nho.access_mode + "; read_ondly: " + $nho.readonly + "; sec_options: " + $nho.sec_options + "; perf_mode: " + $nho.perf_mode + ";; "
    }

    $datastring = "$exportID,$Volume_Guid,$Filer_Serial_Number,$export_name,$path,$comment,$readonly,$allowed_hosts,$access_mode,$perf_mode,$sec_options,$nhoOutput"
	Out-File -FilePath $nfsReportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
}

#Connect to the List all FTP directories for filer NMC API endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/filers/ftp-directories/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#initialize FTP CSV output file
$ftpCsvHeader = "FtpId,Volume_GUID,filer_serial_number,ftp_name,path,comment,readonly,visibility,ip_restrictions,allowed_users,allowed_groups,allow_anonymous,anonymous_only,Permissions_on_new_files,hide_ownership,use_temporary_files_during_upload"
$ftpReportFile = $reportDirectory + 'FtpDirectories.csv'
Out-File -FilePath $ftpReportFile -InputObject $ftpCsvHeader -Encoding UTF8
write-host ("Exporting FTP Directory Information to: " + $ftpReportFile)

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
    Out-File -FilePath $ftpReportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
} 

#initialize the Volume Auditing CSV output file
$auditCsvHeader = "VolumeName,FilerName,VolumeGuid,FilerSerialNumber,AuditingEnabled,Create,Delete,Rename,Close,Security,Metadata,Write,Read,PruneAuditLogs,DaysToKeep,ExcludeByDefault,IncludeTakesPriority,IncludePatterns,ExcludePatterns,SyslogExportEnabled"
$auditReportFile = $reportDirectory + 'VolumeAuditing.csv'
Out-File -FilePath $auditReportFile -InputObject $auditCsvHeader -Encoding UTF8
write-host ("Exporting Volume Auditing Information to: " + $auditReportFile)

#List filers
$FilersUrl="https://"+$hostname+"/api/v1.1/filers/?limit="+$limit+"&offset=0"
$GetFilerInfo = Invoke-RestMethod -Uri $FilersUrl -Method Get -Headers $headers
 
#List volumes
$url="https://"+$hostname+"/api/v1.1/volumes/?limit="+$limit+"&offset=0"
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
 
foreach($i in 0..($getinfo.items.Count-1)){

   #call the list filer specific settings for a volume endpoint
     $volumefilerurl = "https://"+$hostname+"/api/v1.1/volumes/" + $getinfo.items.guid[$i] + "/filers/?limit=' + $limit + '&offset=0/"
     $volumeinfo = Invoke-RestMethod -Uri $volumefilerurl -Method Get -Headers $headers

      #loop through each item in FilerSettingsInfo
        foreach($j in 0..($volumeinfo.items.Count-1)){
        $VolumeName = $volumeinfo.items[$j].name

        #loop through the filer info to get the filer description
            foreach($m in 0..($GetFilerInfo.items.Count-1)){
            $FilerSerial = $GetFilerInfo.items[$m].serial_number
            $FilerDescription = $GetFilerInfo.items[$m].description
            if ($FilerSerial -eq  $volumeinfo.items[$j].filer_serial_number) {$FilerName = $FilerDescription}
    $m++}
       $VolumeGuid = $volumeinfo.items[$j].guid
       $FilerSerial = $volumeinfo.items[$j].filer_serial_number
       $AuditingEnabled = $volumeinfo.items[$j].auditing.enabled
       $EventsCreate = $volumeinfo.items[$j].auditing.events.create
       $EventsDelete = $volumeinfo.items[$j].auditing.events.delete
       $EventsRename = $volumeinfo.items[$j].auditing.events.rename
       $EventsClose = $volumeinfo.items[$j].auditing.events.close
       $EventsSecurity = $volumeinfo.items[$j].auditing.events.security
       $EventsMetadata = $volumeinfo.items[$j].auditing.events.metadata
       $EventsWrite = $volumeinfo.items[$j].auditing.events.write
       $EventsRead = $volumeinfo.items[$j].auditing.events.read
       $PruneAuditLogs = $volumeinfo.items[$j].auditing.logs.prune_audit_logs
       $DaysToKeep = $volumeinfo.items[$j].auditing.logs.days_to_keep
       $ExcludeByDefault = $volumeinfo.items[$j].auditing.logs.exclude_by_default
       $IncludeTakesPriority = $volumeinfo.items[$j].auditing.logs.include_takes_priority
       $IncludePatterns = $volumeinfo.items[$j].auditing.logs.include_patterns
       $ExcludePatterns = $volumeinfo.items[$j].auditing.logs.exclude_patterns
       $SyslogExport = $volumeinfo.items[$j].auditing.logs.syslog_export
       $datastring = "$VolumeName,$FilerName,$VolumeGuid,$FilerSerial,$AuditingEnabled,$EventsCreate,$EventsDelete,$EventsRename,$EventsClose,$EventsSecurity,$EventsMetadata,$EventsWrite,$EventsRead,$PruneAuditLogs,$DaysToKeep,$ExcludeByDefault,$IncludeTakesPriority,$IncludePatterns,$ExcludePatterns,$SyslogExport"
       #write the results to the CSV
       Out-File -FilePath $auditReportFile -InputObject $datastring -Encoding UTF8 -append

        $j++}
        #sleep to avoid NMC API throttling
        Start-sleep 1.1

$i++
}

#initialize Volume Snapshot/Sync Schedule CSV output file
$snapSyncCsvHeader = "VolumeName,FilerName,VolumeGuid,FilerSerialNumber,SnapSchedMon,SnapSchedTue,SnapSchedWed,SnapSchedThu,SnapSchedFri,SnapSchedSat,SnapSchedSun,SnapSchedAllday,SnapSchedStart,SnapSchedStop,SnapSchedFrequency,SyncSchedMon,SyncSchedTue,SyncSchedWed,SyncSchedThu,SyncSchedFri,SyncSchedSat,SyncSchedSun,SyncSchedAllday,SyncSchedStart,SyncSchedStop,SyncSchedFrequency,SyncSchedAutocacheAllowed,SyncSchedAutocacheMinFileSize"
$snapSyncReportFile = $reportDirectory + 'SnapAndSyncSchedule.csv'
Out-File -FilePath $snapSyncreportFile -InputObject $snapSynccsvHeader -Encoding UTF8
write-host ("Exporting Volume Snapshot and Sync Schedule to: " + $snapSyncReportFile)

foreach($i in 0..($getinfo.items.Count-1)){

    #call the list filer specific settings for a volume endpoint
      $volumefilerurl = "https://"+$hostname+"/api/v1.1/volumes/" + $getinfo.items.guid[$i] + "/filers/?limit=' + $limit + '&offset=0/"
      $volumeinfo = Invoke-RestMethod -Uri $volumefilerurl -Method Get -Headers $headers
 
       #loop through each item in FilerSettingsInfo
         foreach($j in 0..($volumeinfo.items.Count-1)){
         $VolumeName = $volumeinfo.items[$j].name
 
         #loop through the filer info to get the filer description
             foreach($m in 0..($GetFilerInfo.items.Count-1)){
             $FilerSerial = $GetFilerInfo.items[$m].serial_number
             $FilerDescription = $GetFilerInfo.items[$m].description
             if ($FilerSerial -eq  $volumeinfo.items[$j].filer_serial_number) {$FilerName = $FilerDescription}
     $m++}
       $VolumeGuid = $volumeinfo.items[$j].guid  
       $FilerSerial = $volumeinfo.items[$j].filer_serial_number
       $SnapSchedMon = $volumeinfo.items[$j].snapshot_schedule.days.mon
       $SnapSchedTue = $volumeinfo.items[$j].snapshot_schedule.days.tue
       $SnapSchedWed = $volumeinfo.items[$j].snapshot_schedule.days.wed
       $SnapSchedThu = $volumeinfo.items[$j].snapshot_schedule.days.thu
       $SnapSchedFri = $volumeinfo.items[$j].snapshot_schedule.days.fri
       $SnapSchedSat = $volumeinfo.items[$j].snapshot_schedule.days.sat
       $SnapSchedSun = $volumeinfo.items[$j].snapshot_schedule.days.sun
       $SnapSchedAllday = $volumeinfo.items[$j].snapshot_schedule.allday
       $SnapSchedStart = $volumeinfo.items[$j].snapshot_schedule.start
       $SnapSchedStop = $volumeinfo.items[$j].snapshot_schedule.stop
       $SnapSchedFrequency = $volumeinfo.items[$j].snapshot_schedule.frequency
       $SyncSchedMon = $volumeinfo.items[$j].sync_schedule.days.mon
       $SyncSchedTue = $volumeinfo.items[$j].sync_schedule.days.tue
       $SyncSchedWed = $volumeinfo.items[$j].sync_schedule.days.wed
       $SyncSchedThu = $volumeinfo.items[$j].sync_schedule.days.thu
       $SyncSchedFri = $volumeinfo.items[$j].sync_schedule.days.fri
       $SyncSchedSat = $volumeinfo.items[$j].sync_schedule.days.sat
       $SyncSchedSun = $volumeinfo.items[$j].sync_schedule.days.sun
       $SyncSchedAllday = $volumeinfo.items[$j].sync_schedule.allday
       $SyncSchedStart = $volumeinfo.items[$j].sync_schedule.start
       $SyncSchedStop = $volumeinfo.items[$j].sync_schedule.stop
       $SyncSchedFrequency = $volumeinfo.items[$j].sync_schedule.frequency
       $SyncSchedAcAllowed = $volumeinfo.items[$j].sync_schedule.auto_cache_allowed
       $SyncSchedAcMinFileSize = $volumeinfo.items[$j].sync_schedule.auto_cache_min_file_size
 
        $datastring = "$VolumeName,$FilerName,$VolumeGuid,$FilerSerial,$SnapSchedMon,$SnapSchedTue,$SnapSchedWed,$SnapSchedThu,$SnapSchedFri,$SnapSchedSat,$SnapSchedSun,$SnapSchedAllday,$SnapSchedStart,$SnapSchedStop,$SnapSchedFrequency,$SyncSchedMon,$SyncSchedTue,$SyncSchedWed,$SyncSchedThu,$SyncSchedFri,$SyncSchedSat,$SyncSchedSun,$SyncSchedAllday,$SyncSchedStart,$SyncSchedStop,$SyncSchedFrequency,$SyncSchedAcAllowed,$SyncSchedAcMinFileSize"
        #write the results to the CSV
        Out-File -FilePath $snapSyncReportFile -InputObject $datastring -Encoding UTF8 -append
 
         $j++}
         #sleep to avoid NMC API throttling
         Start-sleep 1.1
 
 $i++
 }

#List Quota Folders NMC API endpoint
$QuotaFoldersUrl="https://"+$hostname+"/api/v1.1/volumes/folder-quotas/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$GetQuotaFolders = Invoke-RestMethod -Uri $QuotaFoldersUrl -Method Get -Headers $headers

#initialize Folder Quotas SCV output file
$folderQuotaCsvHeader = "Quota ID,VolumeGuid,FilerSerial,Path,Quota Type,Quota Limit,Quota Usage,Email"
$folderQuotaReportFile = $reportDirectory + 'FolderQuotas.csv'
Out-File -FilePath $folderQuotaReportFile -InputObject $folderQuotaCsvHeader -Encoding UTF8
write-host ("Exporting Folder Quota information to: " + $folderQuotaReportFile)

foreach($i in 0..($GetQuotaFolders.items.Count-1)){
    $QuotaID = $GetQuotaFolders.items[$i].id
	$VolumeGuid = $GetQuotaFolders.items[$i].volume_guid
	$FilerSerial = $GetQuotaFolders.items[$i].filer_serial_number
	$Path = $GetQuotaFolders.items[$i].path
	$Type = $GetQuotaFolders.items[$i].type
    $Email = $GetQuotaFolders.items[$i].email
    $QuotaLimit = $GetQuotaFolders.items[$i].limit
    $QuotaUsage = $GetQuotaFolders.items[$i].usage
	$datastring = "$QuotaID,$VolumeGuid,$FilerSerial,$Path,$Type,$QuotaLimit,$QuotaUsage,$Email"
	Out-File -FilePath $folderQuotaReportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
}

#List Pinned Folders NMC API endpoint
$PinnedFoldersUrl="https://"+$hostname+"/api/v1.1/volumes/filers/pinned-folders/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$GetPinnedFolders = Invoke-RestMethod -Uri $PinnedFoldersUrl -Method Get -Headers $headers

#initialize Pinned Folders CSV output file
$pinnedFoldersCsvHeader = "volume_guid,filer_serial_number,path,pinning mode"
$pinnedFoldersReportFile = $reportDirectory + 'PinnedFolders.csv'
Out-File -FilePath $pinnedFoldersReportFile -InputObject $pinnedFoldersCsvHeader -Encoding UTF8
write-host ("Exporting Pinned Folder information to: " + $pinnedFoldersReportFile)

foreach($i in 0..($GetPinnedFolders.items.Count-1)){
	$VolumeGuid = $GetPinnedFolders.items[$i].volume_guid
	$FilerSerial = $GetPinnedFolders.items[$i].filer_serial_number
	$Path = $GetPinnedFolders.items[$i].path
	$Mode = $GetPinnedFolders.items[$i].mode
	$datastring = "$VolumeGuid,$FilerSerial,$Path,$Mode"
	Out-File -FilePath $pinnedFoldersReportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
}

#List Auto Cache Folders NMC API endpoint
$ACFoldersUrl="https://"+$hostname+"/api/v1.1/volumes/filers/auto-cached-folders/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$GetACFolders = Invoke-RestMethod -Uri $ACFoldersUrl -Method Get -Headers $headers

#initialize Auto Cache CSV output file
$acFoldersCsvHeader = "volume_guid,filer_serial_number,path,auto cache mode"
$acFoldersReportFile = $reportDirectory + 'AutoCacheFolders.csv'
Out-File -FilePath $acFoldersReportFile -InputObject $acFoldersCsvHeader -Encoding UTF8
write-host ("Exporting Auto Cache Folder information to: " + $acFoldersReportFile)

foreach($i in 0..($GetACFolders.items.Count-1)){
	$VolumeGuid = $GetACFolders.items[$i].volume_guid
	$FilerSerial = $GetACFolders.items[$i].filer_serial_number
	$Path = $GetACFolders.items[$i].path
	$Mode = $GetACFolders.items[$i].mode
	$datastring = "$VolumeGuid,$FilerSerial,$Path,$Mode"
	Out-File -FilePath $acFoldersReportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
}

#initialize Volume File Alert Service CSV output file
$faCsvHeader = "VolumeName,FilerName,Volume GUID,FilerSerialNumber,File Alerts Enabled,File Alert Patterns"
$faReportFile = $reportDirectory + 'FileAlertService.csv'
Out-File -FilePath $faReportFile -InputObject $faCsvHeader -Encoding UTF8
write-host ("Exporting File Alert Service information to: " + $faReportFile)
 
foreach($i in 0..($getinfo.items.Count-1)){

   #call the list filer specific settings for a volume endpoint
     $volumefilerurl = "https://"+$hostname+"/api/v1.1/volumes/" + $getinfo.items.guid[$i] + "/filers/?limit=" + $limit + "&offset=0/"
     $volumeinfo = Invoke-RestMethod -Uri $volumefilerurl -Method Get -Headers $headers

      #loop through each item in FilerSettingsInfo
        foreach($j in 0..($volumeinfo.items.Count-1)){
        $VolumeName = $volumeinfo.items[$j].name

        #loop through the filer info to get the filer description
            foreach($m in 0..($GetFilerInfo.items.Count-1)){
            $FilerSerial = $GetFilerInfo.items[$m].serial_number
            $FilerDescription = $GetFilerInfo.items[$m].description
            if ($FilerSerial -eq  $volumeinfo.items[$j].filer_serial_number) {$FilerName = $FilerDescription}
    $m++}
       $FilerSerial = $volumeinfo.items[$j].filer_serial_number
       $VolumeGuid = $volumeinfo.items[$j].guid
       $faEnabled = $volumeinfo.items[$j].file_alerts_service.enabled
       $faPatterns = $volumeinfo.items[$j].file_alerts_service.patterns
       $datastring = "$VolumeName,$FilerName,$VolumeGuid,$FilerSerial,$faEnabled,$faPatterns"
       #write the results to the CSV
       Out-File -FilePath $faReportFile -InputObject $datastring -Encoding UTF8 -append

        $j++}
        #sleep to avoid NMC API throttling
        Start-sleep 1.1

$i++
}

#initialize Volume Snapshot Access CSV output file
$snapshotAccessCsvHeader = "VolumeName,FilerName,Volume GUID,FilerSerialNumber,Snapshot Access Enabled"
$snapshotAccessReportFile = $reportDirectory + 'SnapshotDirAccess.csv'
Out-File -FilePath $snapshotAccessReportFile -InputObject $snapshotAccessCsvHeader -Encoding UTF8
write-host ("Exporting Snapshot Directory Access information to: " + $snapshotAccessReportFile)
 
foreach($i in 0..($getinfo.items.Count-1)){

   #call the list filer specific settings for a volume endpoint
     $volumefilerurl = "https://"+$hostname+"/api/v1.1/volumes/" + $getinfo.items.guid[$i] + "/filers/?limit=" + $limit + "&offset=0/"
     $volumeinfo = Invoke-RestMethod -Uri $volumefilerurl -Method Get -Headers $headers

      #loop through each item in FilerSettingsInfo
        foreach($j in 0..($volumeinfo.items.Count-1)){
        $VolumeName = $volumeinfo.items[$j].name

        #loop through the filer info to get the filer description
            foreach($m in 0..($GetFilerInfo.items.Count-1)){
            $FilerSerial = $GetFilerInfo.items[$m].serial_number
            $FilerDescription = $GetFilerInfo.items[$m].description
            if ($FilerSerial -eq  $volumeinfo.items[$j].filer_serial_number) {$FilerName = $FilerDescription}
    $m++}
       $FilerSerial = $volumeinfo.items[$j].filer_serial_number
       $VolumeGuid = $volumeinfo.items[$j].guid
       $snapshotAccess = $volumeinfo.items[$j].snapshot_access
       $datastring = "$VolumeName,$FilerName,$VolumeGuid,$FilerSerial,$snapshotAccess"
       #write the results to the CSV
       Out-File -FilePath $snapshotAccessReportFile -InputObject $datastring -Encoding UTF8 -append

        $j++}
        #sleep to avoid NMC API throttling
        Start-sleep 1.1

$i++
}
