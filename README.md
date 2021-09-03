# nmc-api-powershell-utilities
Utlilities and scripts that use the NMC API to perform operations and generate reports

# PowerShell REST API Basics
These NMC API PowerShell scripts provide the building blocks for interacting with the NMC API.

## Request a Token
This is a simple script to validate NMC API connectivity and obtain a token that can be used with other NMC API endpoints. The script writes the token to the console if execution is successful. Be sure to use single rather than double quotes when entering the password since passwords may contain special characters that need to be treated literally by PowerShell.\
**Required Inputs**: NMC hostname, username, password\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: GetToken.ps1\

## Better Error Handling
PowerShell's Invoke-RestMethod cmdlet only includes basic error handling by default, returning messages such as "400 Error Bad Request", while suppressing the full error message from the API endpoint. Fortunately, there is a way to get verbose error messages by using try/catch with Invoke-RestMethod and calling a function in case of error. PowerShell 6 and PowerShell core support a newer method for error handling while older versions of PowerShell require the use of GetResponseStream to capture errors. This script checks the PowerShell version to determine which method to use.

The code snippet below can be used as an example for modifying the PowerShell code examples in Confluence. Add the function (lines 1-13) to your script before referencing it, since functions must be defined before calling them in PowerShell. Line 15 of this script is an example of using try/catch with a command and should not be directly copied to your script since the variable names will not match. Instead, modify the Invoke-RestMethod line of the script that you would like to get better errors for by adding "try" and the matching open and close curly braces along followed by the "catch" command and "Failure" within curly braces.\
**Name**: BetterErrorHandling.ps1

## Allow Untrusted SSL Certificates
Having a valid SSL certificate for the NMC is a best practice, but test/dev or new environments may not yet have a valid SSL certificate. Fortunately, there's a way to skip SSL certificate checks and this is included in most of the PowerShell examples we provide. If you have a valid SSL certificate for your NMC, you can remove this code block from the provided examples.

If you are using PowerShell 6 or higher, the Invoke-RestMethod cmdlet natively includes a “-SkipCertificateCheck” option and this script changes the default for the Invoke-RestMethod cmdlet to skip certificate checks. Versions of PowerShell before version 6 and PowerShell core do not support a “-SkipCertificateCheck” option and must rely on the .Net subsystem to disable certificate checks.\
**Name**: AllowUntrustedSSLCerts.ps1

## Avoid NMC API Throttling
Beginning with version 8.5, NMC API endpoints are now throttled to preserve NMC performance and stability. NMC API endpoints are generally limited to 5 requests/second for "Get" actions and 1 request per second for "Post", "Update", or "Delete" actions. Nasuni recommends adding "sleep" or "wait" steps to existing API integrations to avoid exceeding the throttling defaults. The PowerShell Start-Sleep cmdlet can be used inside of your scripts to limit the speed of PowerShell Execution and to avoid throttling limits. For example, this command will pause execution for 1.1 seconds:

Start-Sleep -s 1.1

## PowerShell Tools
Windows includes built-in tools for PowerShell editing and testing and there is also a good cross-platform, Microsoft-provided option for code editing that has native support for PowerShell. 

PowerShell ISE is part of the Windows server and client. 

Visual Studio Code (Windows, macOS, Linux) has native support for PowerShell editing and is both free and built on open source.

## Version Troubleshooting
Some NMC API endpoints require a specific NMC or Edge Appliance version, and if the request is made to the NMC the NMC API endpoint will return a message such as:

"Current filer version does not support this type of request. Please update your Edge Appliance to use this feature."

If the Edge Appliance version and NMC do in fact match what is documented for the NMC API endpoint and the error is still returned, it's possible that Edge Appliances were updated prior to upgrading the NMC. If this were to occur, the fulldumps that the Edge Appliances sent to the NMC would have contained information that the NMC couldn't process, causing the NMC to think the Edge Appliance doesn't meet the version criteria for the particular NMC API endpoint. The fix for this is to have the Edge Appliances resend their fulldumps once the NMC is running the current version–the "Refresh Managed Filers" button on the NMC overview page will do this.

# Shares
PowerShell NMC API Scripts for working with shares.

## Create a Share
Uses PowerShell to create a share by referencing an existing Volume, Edge Appliance, and Path. Useful as an example of how shares can be created using PowerShell.\
**Required Inputs**: NMC hostname, username, password, filer_serial, volume_guid, ShareName, Path\
**Compatibility**: Nasuni 8.0 or higher required\
**Optional Inputs**: comment, readonly, browseable (visible), auth, ro_users, ro_groups, rw_users, rw_groups, hosts_allow, hide_unreadable (access based enumeration, enable_previous_vers, case_sensitive, enable_snapshot_dirs, homedir_support, mobile, browser_access, aio_enabled, veto_files, fruit_enabled, smb_encrypt\
**Name**: CreateShare.ps1

## Export or Import All Shares and Settings to CSV
Uses PowerShell to export a list of all shares and configured share settings to a CSV.\
**Required Inputs**: NMC hostname, username, password, reportFile, limit (preset to 1000 shares, but can be increased)\
**Compatibility**: Nasuni 7.10 or higher required; Required PowerShell Version: 7.0 or higher.\
**Output CSV content**: shareid,Volume_GUID,filer_serial_number,share_name,path,comment,readonly,browseable,authAuthall,authRo_users,authRw_users,authDeny_users,authRo_groups,authRw_groups,authDeny_groups,hosts_allow,hide_unreadable,enable_previous_vers,case_sensitive,enable_snapshot_dirs,homedir_support,mobile,browser_access,aio_enabled,veto_files,fruit_enabled,smb_encrypt,shared_links_enabled,link_force_password,link_allow_rw,external_share_url,link_expire_limit,link_authAuthall,link_authAllow_groups_ro,link_authAllow_groups_rw,link_authDeny_groups,link_authAllow_users_ro,link_authAllow_users_rw,link_authDeny_users\
**Name**: ExportAllSharesToCSV.ps1

## Bulk Share Creation
These scripts demonstrate how shares can be created, exported, and subsequently updated. The scripts use CSV files for Input and output.\
**Compatibility**: Nasuni 8.0 or higher required

## Set All Shares on an Edge Appliance to Read Only
This script uses the NMC API to list all shares for an Edge Appliance and update the share properties for each share so that the shares are set to Read Only. This was originally developed to assist with quiescing all shares on a specific Edge Appliance to assist with data migration. \
**Required Inputs**: NMC hostname, username, password, Filer Serial\
**Compatibility**: Nasuni 8.0 or higher required\
**Known Issues**: none\
**Name**: SetFilerSharesToReadOnly.ps1

## Enable Previous Versions for all Shares
This script uses the NMC API to list all shares, check to see if previous versions is enabled, and update the share properties for each share without previous versions support so that previous versions support is enabled. It can also be used to disable previous versions support for all shares. There is a 1.1 second pause after updating each share in order to avoid NMC throttling. Based on the pause, the script could take 1110 seconds to complete for 1000 shares this list by default. Also, 1100 seconds only reflects the time the script will take to execute--the NMC could take considerably longer to contact each Edge Appliance and update share properties.\
**Required Inputs**: NMC hostname, username, password, PreviousVersions (True/False)\
**Compatibility**: Nasuni 8.0 or higher required\
**Known Issues**: none\
**Name**: EnablePreviousVersionsForAllShares.ps1

## Set block files for all shares on an Edge Appliance
This script uses the NMC API to list all shares for an Edge Appliance and update the share properties for each share to match the supplied value for block files. The list of blocked files should be comma-separated.\
**Required Inputs**: NMC hostname, username, password, FilerSerial, BlockFiles\
**Compatibility**: Nasuni 8.0 or higher required\
**Known Issues**: none\
**Name**: SetBlockFilesForAllSharesOnaFiler.ps1

## Delete a Share
Deletes the specified share. Share must be referenced by share_id. Share_id can be obtained by using the list shares NMC API endpoint: http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#list-shares \
**NMC API Endpoint Used**: Delete a share: http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#delete-a-share \
**Required Inputs**: NMC hostname, username, password, filer_serial, volume_guid, share_id\
**Compatibility**: Nasuni 8.0 or higher required\
**Name**: DeleteShare.ps1

## List Shares
Lists shares for an account and exports results to the PowerShell console.\
**NMC API Endpoint Used**: list shares: http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#list-shares \
**Required Inputs**: NMC hostname, username, password, limit (number of shares to list)\
**Output**: shareid, Volume_GUID,filer_serial_number, share_name, path, comment, readonly, browseable, authall, ro_users, rw_users, ro_groups, rw_groups, hosts_allow, hide_unreadable, enable_previous_vers, case_sensitive, enable_snapshot_dirs, homedir_support, mobile, browser_access, aio_enabled, veto_files, fruit_enabled, smb_encrypt
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ListShares.ps1

## Export CIFS Locks to CSV
Uses PowerShell to list CIFS locks for the specified Edge Appliance and exports the results to CSV . This uses the v1 NMC API endpoint for CIFS LOCKs which returns all cifslocks rather than paging the output.\
**Required Inputs**: NMC hostname, username, password, filer_serial, reportFile\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ExportCifsLocksToCSV.ps1

## Enable Mac Support for all Shares
This script uses the NMC API to list all shares, check for shares without Mac support and update those shares to enable Mac support. There is a 1.1 second pause after updating each share in order to avoid NMC throttling. Based on the pause, the script could take 1110 seconds to complete for 1000 shares this list by default. Also, 1100 seconds only reflects the time the script will take to execute--the NMC could take considerably longer to contact each Edge Appliance and update share properties.\
**Required Inputs**: NMC hostname, username, password, FruitEnabled (True/False)\
**Compatibility**: Nasuni 8.0 or higher required\
**Name**: EnableMacSupportForAllShares.ps1

## Export CIFS Clients to CSV
Uses PowerShell to list CIFS clients for all Edge Appliance and exports the results to CSV . This uses the v1 NMC API endpoint for CIFS Clients which returns all cifsclients rather than paging the output.\
**Required Inputs**: NMC hostname, username, password, reportFile\
**Compatibility**: Nasuni 7.10 or higher required\
**Output**: Edge Appliance Serial Number, Edge Appliance Description, List of connected clients and connected shares (one line for each connected client)\
**Name**: ExportCifsClientsToCSV.ps1

## Replicate Shares from Source to Destination Edge Appliance
This script uses the NMC API to list all shares for source Edge Appliance, compare a listing of those shares on the destination Edge Appliance, and create the missing shares on the destination. Shares for volumes that are not owned or connected to the destination Edge Appliance are skipped. All share settings are copied from the source to the destination. Shares that are already present on the destination are not changed.\
**Required Inputs**: NMC hostname, username, password, SourceFilerSerialNumber, DestinationFilerSerialNumber\
**Compatibility**: Nasuni 8.0 or higher required\
**Known Issues**: none\
**Name**: ReplicateMissingShares.ps1

## Export All NFS Exports and Settings to CSV
Uses PowerShell to export all NFS exports and configurable settings to CSV.\
**Required Inputs**: NMC hostname, username, password, reportFile, limit (preset to 1000 exports, but can be increased)\
**Compatibility**: Nasuni 7.10 or higher required; Requires PowerShell Version: 7.0 or higher.\
**Output CSV content**: exportId,Volume_GUID,filer_serial_number,export_name,path,comment,readonly,allowed_hosts,access_mode,perf_mode,sec_options,nfs_host_options\
**Name**: ExportAllNFSExportsToCSV.ps1

## Export All FTP Directories and Settings to CSV
Uses PowerShell to export all FTP directories and configurable settings to CSV.\
**Required Inputs**: NMC hostname, username, password, reportFile, limit (preset to 1000 FTP directories, but can be increased)\
**Compatibility**: Nasuni 7.10 or higher required; Requirs PowerShell Version: 7.0 or higher.\
**Output CSV content**: FtpId,Volume_GUID,filer_serial_number,ftp_name,path,comment,readonly,visibility,ip_restrictions,allowed_users,allowed_groups,allow_anonymous,anonymous_only,Permissions_on_new_files,hide_ownership,use_temporary_files_during_upload\
**Name**: ExportAllFtpDirectoriesToCSV.ps1

# Quotas
PowerShell NMC API scripts to work with quotas.

## Create Folder Quota
This script uses the NMC API to set a quota for the given path on the specified volume.\
**Required Inputs**: NMC hostname, username, password, volume_guid, path, quota amount, email\
**Compatibility**: Nasuni 8.0 or higher required\
**Known Issues**: Quotas cannot be configured for a path that already has a quota configured at a lower level.\
**Name**: SetQuota.ps1

## Update Folder Quota
This script uses the NMC API to update an existing folder quota. The script lists all existing quotas to find the corresponding Quota ID and references it to update the existing quota.\
**Required Inputs**: NMC hostname, username, password, path, quota amount\
**Compatibility**: Nasuni 8.0 or higher required\
**Name**: UpdateQuota.ps1

## Export Folder Quotas to CSV
Exports folder quotas and rule to CSV\
**Required Inputs**: NMC hostname, username, password, limit\
**Output**: Quota ID, VolumeGuid, FilerSerial, Path, Quota Type, Quota Limit, Quota Usage, Email\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ExportFolderQuotasToCSV.ps1

# Paths
## Working With Paths
Scripts that use the NMC API to list and control settings for paths. Nasuni provides two primary NMC API endpoints to deal with paths and path status:

Refresh info about a given path: http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#refresh-info-about-a-given-path. Posting to this endpoint causes the NMC to request current information from the associated Edge Appliance for the path (statting it). Once this is done, the path is considered to be a "known path" for the Get info on a specific path endpoint. Known paths are only cached for 10 minutes before expiring.

## Get Path Info
This script uses the NMC API to get info for specified path. It first calls the "refresh info" endpoint to update stats for the path and then calls the "get info" endpoint.\
**Required Inputs**: NMC hostname, username, password, volume_guid, filer_serial, path - The path should start with a "/" and is the path as displayed in the volume file browser and is not related to the share path--it should start at the volume root. Path is case sensitive.\
**Compatibility**: Nasuni 8.5 or higher required\
**Name**: GetPathInfo.ps1


## Bring Path into Cache
This script uses the NMC API to bring the specified path into cache. By default, both the metadata and data for the specified path are brought into cache. Bringing only the metadata into cache is an option if $MetadataOnly is set to "true".\
**Required Inputs**: NMC hostname, username, password, volume_guid, filer_serial, path, metadata only, force\
**Compatibility**: Nasuni 8.5 or higher required\
**Name**: BringPathIntoCache.ps1

## Set Pinning for a Path
This script uses the NMC API to configure pinning for the specified volume path and Edge Appliance. Can be used to configure the pinning of metadata and data or metadata only.\
**NMC API Endpoint Used**: Set Pinning Mode - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#set-pinning-mode \
**Required Inputs**: NMC hostname, username, password, volume_guid, filer_serial, path, mode (metadata_and_data, metadata)\
**Compatibility**: Nasuni 8.5 or higher required\
**Name**: SetPinning.ps1

## Set Auto Cache for a Path
This script uses the NMC API to configure Auto Cache for the specified volume path and Edge Appliance. Can be used to configure the Auto Cahe of metadata and data or metadata only.\
**NMC API Endpoints Used**: Set Auto Caching Mode - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#set-auto-caching-mode \
**Required Inputs**: NMC hostname, username, password, volume_guid, filer_serial, path, mode (metadata_and_data, metadata)\
**Compatibility**: Nasuni 8.5 or higher required\
**Name**: SetAutoCache.ps1

## Set Global File Lock and Mode for a Path
This script uses the NMC API to set Global File Lock and mode for the specified mode for the given path. The script checks the Volumes snapshot status for all Edge Appliances and waits using the specified retry delay and retry limit until snapshots are idle before executing the command to configure GFL. When configuring GFL, the script first confirms that the path is valid before setting Global File Lock and mode.\
**Required Inputs**: NMC hostname, username, password, volume_guid, path, mode, RetryLimit, RetryDelay.\
**Compatibility**: Nasuni 8.5 or higher required\
**Known Issues**: Global File Lock must be enabled in the customer's license, and Remote Access must be enabled for the volume. GFL can only be set when the volume snapshot status is idle, meaning that it is not allowed to be set if any Edge Appliance is running a snapshot for the volume. Disabling GFL is not currently supported via NMC API.\
**Name**: SetGFLandMode.ps1

## Set Global File Lock and Mode for Multiple Paths
This script uses the NMC API to enable Global File Lock with the specified paths.\
**Required Inputs**: NMC hostname, username, password, volume_guid, base path, sub paths, mode\
**Compatibility**: Nasuni 8.5 or higher required\
**Known Issues**: GFL must be enabled in the customer's license\
**Name**: SetGFLandModeForMultiplePaths.ps1

## Create Folder
This script uses the NMC API to create a folder within the given path on the specified volume and connected Edge Appliance.

**NMC API Endpoint Used**: Create Folder - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#try-to-make-the-given-directory-path \
**Required Inputs**: NMC hostname, username, password, volume_guid, filer_serial, path\
**Compatibility**: Nasuni 8.5 or higher required\
**Known Issues**: Folders are owned by the root POSIX user. This could create issues for NTFS exclusive volumes.\
**Name**: CreateFolder.ps1

## Disable Pinning for a Path
This script uses the NMC API to disable pinning for the specified volume path and Edge Appliance.\
**Required Inputs**: NMC hostname, username, password, volume_guid, filer_serial, path\
**Compatibility**: Nasuni 8.5 or higher required\
**Name**: DisablePinning.ps1

## Disable Auto Cache for a Path
This script uses the NMC API to disable Auto Cache for the specified volume path and Edge Appliance.\
**NMC API Endpoint Used**: Disable Auto Cache Mode - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#disable-auto-cache-mode-on-a-folder \
**Required Inputs**: NMC hostname, username, password, volume_guid, filer_serial, path \
**Compatibility**: Nasuni 8.5 or higher required\
**Name**: DisableAutocache.ps1\

## Export Auto Cache Folders to CSV
Exports a list of Auto Cache enabled folders to CSV.\
**Required Inputs**: NMC hostname, username, password, limit\
**Output**: volume_guid, filer_serial_number, path, autocache mode\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ExportAutoCacheFoldersToCSV.ps1\

## Export Pinned Folders to CSV
Exports a list of pinned folders to CSV.\
**Required Inputs**: NMC hostname, username, password, limit\
**Output**: volume_guid, filer_serial_number, path, pinning mode\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ExportPinnedFoldersToCSV.ps1

# Reporting and Chargeback
Use these NMC API scripts to help with reporting and chargeback.\

## Recharge tracking/Volume Details
This script can be used as a starting point for billing and recharge reporting. This script example provides a report of all volumes in an account.\
**Required Inputs**: NMC hostname, username, password, reportfile (path to the CSV output file)\
**Compatibility**: Nasuni 7.10 or higher required\
**Output CSV content**: volume_name, volume_guid, filer_description, filer_serial_number, accessible data, provider\
**Known Issues**: Does not work correctly if there is a disconnected volume in the account.\
**Name**: ExportVolumeDetailToCSV.ps1

## Show Ingest Progress
This script can be used to track the progress of data ingestion or data growth. This script provides a report of all volumes in an account and the amount of accessible data alongside unprotected data on each Edge Appliance, the last snapshot time, and last snapshot version. Running this daily and compare results to get data for ingest trending or data growth.\
**Required Inputs**: NMC hostname, username, password, reportfile (path to the CSV output file)\
**Compatibility**: Nasuni 7.10 or higher required\
**Output CSV content**: volume_name, volume_guid, filer_description, filer_serial_number, accessible data, unprotected data, last_snapshot_time, last_snapshot_version\
**Known Issues**: Might not work correctly if there is a disconnected volume in the account. \
**Name**: ShowIngestProgress.ps1

## Volume Unprotected Data Alert
Customers can use this script to monitor all Edge Appliances connected to a volume for unprotected data that exceeds a user configured threshold. Once this is exceeded, an email to the administrator is generated. This is designed to be run as a windows scheduled task and can be run as frequently as every 10 minutes. Requires an SMTP server for email alerting.\
**Required Inputs**: NMC hostname, username, password, volume_guid, recipients, from, SMTPserver, port, subject, body\
**Compatibility**: Nasuni 7.10 or higher required\
**Email Content**: Email contains Edge Appliance name(s) and amount of unprotected data for the Edge Appliance.\
**Name**: VolumeUnprotectedDataAlert.ps1

## Export All Shares and Path Info, Including Sizes to CSV
Uses PowerShell to export a list of all shares and with full path info, including current sizes, and exports the results to a CSV.\
**Required Inputs**: NMC hostname, username, password, reportFile, limit\
**Compatibility**: Nasuni 8.5 or higher required\
**Output CSV content**: shareid,volume_name,volume_guid,filer_name,filer_serial,share_name,path,comment,cache_resident,protected,owner,size,pinning_enabled,pinning_mode,pinning_inherited,autocache_enabled,autocache_mode,autocache_inherited,quota_enabled,quota_type,quota_email,quota_usage,quota_limit,quota_inherited,global_locking_enabled,global_locking_inherited,global_locking_mode\
**Known Issues**: Edge Appliances must be online, NMC managed, and running Nasuni 8.5 or higher in order to retrieve share size.\
**Name**: ExportAllSharesAndSizes.ps1

## Export Antivirus Violations to CSV
This script uses the NMC API to export antivirus violations for all volume and Edge Appliances in an Account to a CSV.\
**Required Inputs**: NMC hostname, username, password, reportFile\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ExportAntivirusViolationsToCSV.ps1

## Export QoS Settings for all Edge Appliances
This script uses the NMC API to read the QoS settings for all NMC managed Edge Appliances and export them to a CSV.\
**Required Inputs**: NMC hostname, username, password, report_file\
**Compatibility**: Nasuni 7.10 or higher required\
**Known Issues**: Setting QoS via the NMC API is not currently implemented and is in the backlog for the NMC.\
**Name**: ExportQoSForAllFilers.ps1

## Unprotected Data Alert
Customers can use this script to monitor all Edge Appliances and all Volumes for unprotected data that does not decrease after a user-specified time. Once this is exceeded, an email to the administrator is generated once per day at the time the user specifies. Results are also logged to an output file that is compared against the current status from the NMC API to determine if unprotected data is growing. This is designed to be run as a Windows scheduled task and could be run as frequently as every hour but should be run at least once per day. Requires an SMTP server for email alerting.\
**Required Inputs**: NMC hostname, username, password, DayAlertValue, SendEmailTime, recipients, from, SMTP server, port, subject, body, ReportFileOrig\
**Compatibility**: Nasuni 7.10 or higher required\
**Email Content**: Email contains Edge Appliance name(s), volume(s), and amount of unprotected data for each Edge Appliance and Volume.\
**Name**: CheckAllUnprotectedAndAlert.ps1

# Volume Auditing
Use the NMC API to manage and report on Volume Auditing.

## Export Volume Auditing Settings to CSV
This script uses the NMC API to export volume auditing information for all volume and Edge Appliances in an Account to a CSV.\
**Required Inputs**: NMC hostname, username, password, reportFile\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ExportVolumeAuditingToCSV.ps1

## Set Volume Auditing
This script uses the NMC API to set volume auditing information for the specified volume and Edge Appliance.\
**Required Inputs**: NMC hostname, username, password, volume guid, filer serial, multiple auditing parameters\
**Compatibility**: Nasuni 8.5 or higher required\
**Name**: SetVolumeAuditing.ps1

## Set Volume Auditing for All Volumes and Edge Appliances in an Account
This script uses the NMC API to set find all Volumes and Edge Appliances and configure them all to use the specified auditing settings.\
**Required Inputs**: NMC hostname, username, password, multiple auditing parameters\
**Compatibility**: Nasuni 8.5 or higher required\
**Name**: SetAuditForAllVolumesAndFilers.ps1

# Operations
PowerShell NMC API Scripts to assist with daily Nasuni operations.

## Delete Sync Errors
While the NMC UI does not expose a way to bulk delete/acknowledge sync errors, customers can use the NMC API Messages endpoint to list and delete sync errors. This script deletes sync errors by using the Messages NMC API endpoints to list and delete messages that match the specified status codes and type.\
**NMC API Endpoints Used**: list messages - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#nasuni-management-console-api-messages; delete message - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#delete-message \
**Required Inputs**: NMC hostname, username, password, StatusCode, StatusType, limit\
**Status codes**: set GFL for path (fsbrowser_globallock_edit); Refresh info for path (fsbrowser_stat_item); Create a Share (volumes_shares_add)\
**Compatibility**: Nasuni 8.0 or higher required\
**Name**: DeleteSyncErrors.ps1

## Export NMC Messages to CSV
Customers have requested that we supply robust auditing for actions performed using the NMC API or GUI (PM-320). While we don’t currently audit all NMC actions, the NMC API Messages endpoint currently logs activity performed by NMC GUI and NMC API, including the action performed and the user that initiated it . This script lists all messages that are currently available in the NMC API messages list, sorts them by send_time, and exports them to timestamped CSV.

Note: NMC Messages will only show recent activity since a cron runs on the NMC every 20 minutes that removes messages that are transient and 20 minutes old. In order to capture a full picture of NMC events for logging, run this script every 5 minutes using a cron or Windows Scheduled Task. The exported CSVs of NMC messages can be concatenated and sorted to show all of the NMC activity on a daily basis using the ConcatenateNMCMessages.ps1 script.\
**NMC API Endpoints Used**:list messages - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#nasuni-management-console-api-messages \
**Required Inputs**: NMC hostname, username, password, ReportFile (where to save the CSV), limit (number of messages to return).\
**Compatibility**: Nasuni 8.0 or higher required\
**Name**: ExportMessagesToCSV.ps1

## Export Health Monitor Status for All Edge Appliances
Uses PowerShell to export a list of Health Monitor status for Edge Appliances and export the results to a CSV.\
**NMC API Endpoints Used**: List health status for all Edge Appliances - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#list-health-status-for-all-filers \
**Required Inputs**: NMC hostname, username, password, reportFile, limit\
**Compatibility**: Nasuni 8.8 or higher required\
**Output CSV content**: filer_serial_number, filer_name,last_updated,network,filesystem,cpu,nfs,memory,services,directoryservices,disk,smb\
**Name**: ExportHealthToCSV.ps1\

## Export Edge Appliance Status to CSV
The NMC List Edge Appliances endpoint provides a list of all Edge Appliances, their status, and settings configured for each. This script lists all Edge Appliances in an account along with their status and exports them to CSV. The script does not include the enumeration and export of Edge Appliance settings, but that could easily be added in a future version. \
**NMC API Endpoints Used**: List Edge Appliances - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#list-filers \
**Required Inputs**: NMC hostname, username, password, ReportFile (where to save the CSV), limit (number of Edge Appliances to return).\
Export Contents: Description, SerialNumber, GUID, build, cpuCores, cpuModel, cpuFrequency, cpuSockets, Memory, ManagementState, Offline, OsVersion, Uptime, UpdatesAvailable, CurrentVersion, NewVersion, PlatformName, cacheSize, cacheUsed, cacheDirty, cacheFree, cachePercentUsed\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ExportEAStatusToCSV.ps1

## List Cloud Credentials
Lists cloud credentials for an account and exports results to the PowerShell console. \
**NMC API Endpoint Used**: list cloud credentials - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#list-cloud-credentials \
**Required Inputs**: NMC hostname, username, password\
**Output**: cred_id, name, filer_serial_number, cloud_provider, account, hostname, status, note, in_use\
**Compatibility**: Nasuni 8.0 or higher required\
**Name**: ListCloudCredentials.ps1

## Get Message
This script gives you an example using the message ID to look up the status of an action. The NMC is an asynchronous API and POST or UPDATE actions you initiate with the NMC API will return a “pending” status along with an ID that you can then check to see the status of the request once it has been processed. The screenshot below is the result of a POST request to the NMC API. The red box is the message ID you will use for the messageID in the script. The green box gives you the full URL to the messages NMC API endpoint including the ID.\
**NMC API Endpoint Used**: Get Message - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#nasuni-management-console-api-messages \
**Required Inputs**: NMC hostname, username, messageID\
**Output**: Example below is of a message for an action that failed. A successful message will show “synced” as the status.\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: GetMessage.ps1

## Export Edge Appliance Volume Settings to CSV
This script exports all Edge Appliance settings that are applied on a per-Volume/per-Edge Appliance basis to CSV. The output of these scripts can be used as a reference for updating or validating settings when detaching and re-attaching volumes during cloud to cloud migration. The script exports the following settings and logs them to the listed file name:

| Setting | File Name | Description | CSV Columns |
| ------- | --------- | ----------- | ----------- |
| CIFS Shares | CifsShares.csv | All CIFS shares listed in the NMC | shareid, Volume_GUID, filer_serial_number, share_name, path, comment, readonly, browseable, authAuthall, authRo_users, authRw_users, authDeny_users, authRo_groups, authRw_groups, authDeny_groups, hosts_allow, hide_unreadable, enable_previous_vers, case_sensitive, enable_snapshot_dirs, homedir_support, mobile, browser_access, aio_enabled, veto_files, fruit_enabled, smb_encrypt, shared_links_enabled, link_force_password, link_allow_rw, external_share_url, link_expire_limit, link_authAuthall, link_authAllow_groups_ro, link_authAllow_groups_rw, link_authDeny_groups, link_authAllow_users_ro, link_authAllow_users_rw, link_authDeny_users |
| NFS Exports | NfsExports.csv | All NFS exports listed in the NMC | exportId, Volume_GUID, filer_serial_number, export_name, path, comment, readonly, allowed_hosts, access_mode, perf_mode, sec_options, nfs_host_options |
| FTP Directories | FtpDirectories.csv | All FTP shares listed in the NMC | FtpId, Volume_GUID, filer_serial_number, ftp_name, path, comment, readonly, visibility, ip_restrictions, allowed_users, allowed_groups, allow_anonymous, anonymous_only, Permissions_on_new_files, hide_ownership, use_temporary_files_during_upload |
| Snapshot and Sync Schedule | SnapAndSyncSchedule.csv | List of the configured snapshot and sync schedule for all volumes and Edge Appliances | VolumeName, FilerName, VolumeGuid, FilerSerialNumber, SnapSchedMon, SnapSchedTue, SnapSchedWed, SnapSchedThu, SnapSchedFri, SnapSchedSat, SnapSchedSun, SnapSchedAllday, SnapSchedStart, SnapSchedStop, SnapSchedFrequency, SyncSchedMon, SyncSchedTue, SyncSchedWed, SyncSchedThu, SyncSchedFri, SyncSchedSat, SyncSchedSun, SyncSchedAllday, SyncSchedStart, SyncSchedStop, SyncSchedFrequency, SyncSchedAutocacheAllowed, SyncSchedAutocacheMinFileSize |
| Volume Auditing | VolumeAuditing.csv | List of volume auditing settings for all volumes and Edge Appliances | VolumeName, FilerName, VolumeGuid, FilerSerialNumber, AuditingEnabled, Create, Delete, Rename, Close, Security, Metadata, Write, Read, PruneAuditLogs, DaysToKeep, ExcludeByDefault, IncludeTakesPriority, IncludePatterns, ExcludePatterns, SyslogExportEnabled |
| Folder Quotas and Rules | FolderQuotas.csv | List of all folder quotas and rules for all volumes and Edge Appliances | Quota ID, VolumeGuid, FilerSerial, Path, Quota Type, Quota Limit, Quota Usage, Email |
| Auto Cache Folders | AutoCacheFolders.csv | List of auto cache folders for all volumes and Edge Appliances | volume_guid, filer_serial_number, path, auto cache mode |
| Pinned Folders | PinnedFolders.csv | List of pinned folders for all volumes and Edge Appliances | volume_guid, filer_serial_number, path, pinning mode |
| File Alert Service | FileAlertService.csv | List of file alert service entries for all volumes and Edge Appliances | VolumeName, FilerName, Volume GUID, FilerSerialNumber, File Alerts Enabled, File Alert Patterns |
| Snapshot Directory Access | SnapshotDirAccess.csv | List of the snapshot directory access configuration for all volumes and Edge Appliances | VolumeName, FilerName, Volume GUID, FilerSerialNumber, Snapshot Access Enabled |

**Required Inputs**: NMC hostname, username, password, reportDirectory (where to save the CSV files), limit (limit to use for each API endpoint).\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ExportEaVolumeSettings.ps1

## Export NMC Notifications to CSV
Exports NMC Notifications to CSV.\
**NMC API Endpoints Used**: ist notifications - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#nasuni-management-console-api-notifications \
**Required Inputs**: NMC hostname, username, password, ReportFileName, limit (number of notifications to return)\
**Compatibility**: Nasuni 8.0 or higher required\
**Name**: ExportNotificationsToCSV.ps1

# Volumes
PowerShell NMC API Scripts for working with volumes. 

## Create a Volume
Uses PowerShell to create a volume.\
**Required Inputs**: NMC hostname, username, password, volume_name, filer_serial_number, cred_id, provider_name, shortname, location, permissions_policy, authenticated_access, policy, policy_label, auto_provision_cred, key_name, create_default_access_point, case_sensitive\
**Fields and values**:
* shortName: amazons3, azure, googles3 (9.0 version of the google connector)
* location (case-sensitve):
    * s3 locations: default, Asia, Beijing, Canada, EU, Frankfurt, HongKong, London, Mumbai, Ningxia, Ohio, Oregon, Paris, Seoul, SouthAmerica, Stockholm, Sydney, Tokyo, UsWest
    * Azure: Not Applicable - location is associated with the cred specified
    * on-prem object stores: default
* permissions_policy: PUBLICMODE60 (PUBLIC), NTFS60 (NTFS Compatible), NTFSONLY710 (NTFS Exlusive)
* policy: public (no auth), ads (active directory)
[//]: # (endlist)
**Compatibility**: Nasuni 8.0 or higher required
**Known Issues and Notes**:\
Creating a volume using an existing encryption key: When referencing an existing encryption key rather than creating encryption key, you should not include the “create_new_key”: “false” option. This must be omitted until UNTY-27807 is fixed.

Misleading terminology: The create volume API has an option that misleadingly reference to “cred” in its **Name**: auto_provision_cred. Counterintutively, auto_provision_cred controls the provisioning of encryption keys (pgp), rather than Nasuni cloud credentials.

Use the List Cloud Credentials NMC API endpoint to obtain the cred_id of a credential to use with the create volume NMC API endpoint. Each cred_id returned is actually a hash of the filer serial number and cred UUID (something internal to Nasuni). Since cred_id is a hash of a cred listed in the NMC and the filer serial number, the list cloud credentials NMC API endpoint may list more credentials than you’d expect. Any valid cred_id from any filer can be provided to the create volume NMC API endpoint as long as it shares the provider_name (the name you enter for the cred and that is visible in the NMC) and the shortname (something Nasuni uses internally to for each type of object store). There’s no need to first “copy” the cred to a new filer before using that cred with the NMC API to create a volume on the new filer. Copying creds in the NMC is a leftover artifact from how we had to copy creds from filer to filer before the NMC existed.\
**Name**: CreateVolume.ps1

## Export Volumes and Settings to CSV
Lists volumes for an account and exports results to the specified CSV file.\
**NMC API Endpoint Used**: list volumes: http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#list-volumes \
**Required Inputs**: NMC hostname, username, password, reportFile, limit\
**Output**: name,guid,filer_serial_number,case sensitive,permissions policy,protocols,remote access,remote access permissions,snapshot retention,quota,compression,chunk_size,authenticated access,auth policy,auth policy label,provider name,provider shortname,provider location,provider storage class,bucket name, AV enabled,AV days,AV check immediately,AV allday,AV start,AV stop,AV frequency\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ExportVolumesToCSV.ps1

## Export Volume Snapshot and Sync Schedule to CSV
Lists volumes for an account and exports snapshot and sync schedule for each Edge Appliance to the specified CSV file.\
**Required Inputs**: NMC hostname, username, password, reportFile, limit\
**Output**:VolumeName,FilerName,VolumeGuid,FilerSerialNumber,SnapSchedMon,SnapSchedTue,SnapSchedWed,SnapSchedThu,SnapSchedFri,SnapSchedSat,SnapSchedSun,SnapSchedAllday,SnapSchedStart,SnapSchedStop,SnapSchedFrequency,SyncSchedMon,SyncSchedTue,SyncSchedWed,SyncSchedThu,SyncSchedFri,SyncSchedSat,SyncSchedSun,SyncSchedAllday,SyncSchedStart,SyncSchedStop,SyncSchedFrequency,SyncSchedAutocacheAllowed,SyncSchedAutocacheMinFileSize\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ExportVolumeSnapshotAndSyncScheduleToCSV.ps1
