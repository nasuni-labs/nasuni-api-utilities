# nmc-api-powershell-utilities
Utlilities and scripts that use the NMC API to perform operations and generate reports

# Access Points
PowerShell NMC API Scripts for working with access points. Access points include SMB (CIFS) Shares, NFS Exports, and FTP Directories.

## SMB (CIFS) Shares
### Create a Share
Uses PowerShell to create a share by referencing an existing volume, Edge Appliance, and path. Useful as an example of how shares can be created using PowerShell.\
**Required Inputs**: NMC hostname, username, password, filer_serial, volume_guid, ShareName, Path\
**Compatibility**: Nasuni 8.0 or higher required\
**Optional Inputs**: comment, readonly, browseable (visible), auth, ro_users, ro_groups, rw_users, rw_groups, hosts_allow, hide_unreadable (access based enumeration, enable_previous_vers, case_sensitive, enable_snapshot_dirs, homedir_support, mobile, browser_access, aio_enabled, veto_files, fruit_enabled, smb_encrypt\
**Name**: CreateShare.ps1

### Export All Shares and Settings to CSV
Uses PowerShell to export a list of all shares and configured share settings to a CSV.\
**Required Inputs**: NMC hostname, username, password, reportFile, limit (preset to 1000 shares, but can be increased)\
**Compatibility**: Nasuni 7.10 or higher required; Required PowerShell Version: 7.0 or higher.\
**Output CSV content**: shareid,volume_guid,volume_name,filer_serial_number,filer_name,share_name,path,comment,readonly,browseable,authAuthall,authRo_users,authRw_users,authDeny_users,authRo_groups,authRw_groups,authDeny_groups,hosts_allow,hide_unreadable,enable_previous_vers,case_sensitive,enable_snapshot_dirs,homedir_support,mobile,browser_access,aio_enabled,veto_files,fruit_enabled,smb_encrypt,shared_links_enabled,link_force_password,link_allow_rw,external_share_url,link_expire_limit,link_authAuthall,link_authAllow_groups_ro,link_authAllow_groups_rw,link_authDeny_groups,link_authAllow_users_ro,link_authAllow_users_rw,link_authDeny_users\
**Name**: ExportAllSharesToCSV.ps1

### Bulk Share Creation
These scripts demonstrate how shares can be created, exported, and subsequently updated. The scripts use CSV files for Input and output.\
**Compatibility**: Nasuni 8.0 or higher required

#### Step 1 - Create Shares From CSV
Uses CSV input to create shares. We recommend manually creating several shares along with desired settings and then use the ExportAllSharesToCSV.ps1 script to output a CSV. Use the exported CSV as template for creating additional shares, deleting the columns for volume_name and filer_name. The shareid column is ignored during import but must be present.\
**Required Inputs**: hostname, username, password, csvPath\
**CSV Contents**:(shareid,volume_guid,filer_serial_number,share_name,path,comment,readonly,browseable,authAuthall,authRo_users,authRw_users,authDeny_users,authRo_groups,authRw_groups,authDeny_groups,hosts_allow,hide_unreadable,enable_previous_vers,case_sensitive,enable_snapshot_dirs,homedir_support,mobile,browser_access,aio_enabled,veto_files,fruit_enabled,smb_encrypt,shared_links_enabled,link_force_password,link_allow_rw,external_share_url,link_expire_limit,link_authAuthall,link_authAllow_groups_ro,link_authAllow_groups_rw,link_authDeny_groups,link_authAllow_users_ro,link_authAllow_users_rw,link_authDeny_users)\
**Name**: CreateSharesFromCSV.ps1

#### Step 2 - Export Filtered List Shares to CSV (optional)
Exports all shares for the provided volume_guid and filer_serial to CSV. This could be modified to include all shares for a volume (regardless of filer) or all shares managed by the NMC. A more comprehensive example is available here: ExportAllSharesToCSV.ps1.\
**Required Inputs**:  hostname, username, password, reportFile, filer_serial, volume_guid\
**CSV Output**: shareid, Volume_GUID, filer_serial, share_name, path, comment, block_files, fruit_enabled, authall, ro_users, ro_groups, rw_users, rw_groups\
**Name**: ExportFilteredSharesToCSV.ps1

#### Step 3 - Set Share Permissions (optional)
All share properties, including share permissions, can be set upon share creation. If a customer chooses to implement share permissions during a bulk process, we recommend using a multi-step process with verification at each step since share permissions are very complex to implement. Note: While Nasuni supports share permissions, Nasuni recommends using NTFS permissions where possible. In most use cases, share permissions are not necessary. Our Permissions Best Practices Guide has more information about NTFS and Share permissions usage.

Reads share information from a CSV file and use the input to update share permissions for each share. If more than one user or group is present for a section, separate them with spaces. Domain group or usernames should use this format: DOMAIN\sAMAccountName.\
**Required Inputs**:  hostname, username, password, csvPath\
**Name**: UpdateSharePermissions.ps1, UpdateSharePermissions-Sample.csv

### Set All Shares on an Edge Appliance to Read Only
This script uses the NMC API to list all shares for an Edge Appliance and update the share properties for each share so that the shares are set to Read Only. This was originally developed to assist with quiescing all shares on a specific Edge Appliance to assist with data migration. \
**Required Inputs**: NMC hostname, username, password, Filer Serial\
**Compatibility**: Nasuni 8.0 or higher required\
**Known Issues**: none\
**Name**: SetFilerSharesToReadOnly.ps1
### Set All Shares on an Edge Appliance to Read Only
This script uses the NMC API to list all shares for an Edge Appliance and update the share properties for each share so that the shares are set to Read Only. This was originally developed to assist with quiescing all shares on a specific Edge Appliance to assist with data migration. \
**Required Inputs**: NMC hostname, username, password, Filer Serial\
**Compatibility**: Nasuni 8.0 or higher required\
**Known Issues**: none\
**Name**: SetFilerSharesToReadOnly.ps1

### Enable Previous Versions for all Shares
This script uses the NMC API to list all shares, check to see if previous versions is enabled, and update the share properties for each share without previous versions support so that previous versions support is enabled. It can also be used to disable previous versions support for all shares. There is a 1.1 second pause after updating each share in order to avoid NMC throttling. Based on the pause, the script could take 1110 seconds to complete for 1000 shares this list by default. Also, 1100 seconds only reflects the time the script will take to execute--the NMC could take considerably longer to contact each Edge Appliance and update share properties.\
**Required Inputs**: NMC hostname, username, password, PreviousVersions (True/False)\
**Compatibility**: Nasuni 8.0 or higher required\
**Known Issues**: none\
**Name**: EnablePreviousVersionsForAllShares.ps1

### Set block files for all shares on an Edge Appliance
This script uses the NMC API to list all shares for an Edge Appliance and update the share properties for each share to match the supplied value for block files. The list of blocked files should be comma-separated.\
**Required Inputs**: NMC hostname, username, password, FilerSerial, BlockFiles\
**Compatibility**: Nasuni 8.0 or higher required\
**Known Issues**: none\
**Name**: SetBlockFilesForAllSharesOnaFiler.ps1

### Delete a Share
Deletes the specified share. Share must be referenced by share_id. Share_id can be obtained by using the list shares NMC API endpoint: http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#list-shares \
**NMC API Endpoint Used**: Delete a share: http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#delete-a-share \
**Required Inputs**: NMC hostname, username, password, filer_serial, volume_guid, share_id\
**Compatibility**: Nasuni 8.0 or higher required\
**Name**: DeleteShare.ps1

### List Shares
Lists shares for an account and exports results to the PowerShell console.\
**NMC API Endpoint Used**: list shares: http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#list-shares \
**Required Inputs**: NMC hostname, username, password, limit (number of shares to list)\
**Output**: shareid, Volume_GUID,filer_serial_number, share_name, path, comment, readonly, browseable, authall, ro_users, rw_users, ro_groups, rw_groups, hosts_allow, hide_unreadable, enable_previous_vers, case_sensitive, enable_snapshot_dirs, homedir_support, mobile, browser_access, aio_enabled, veto_files, fruit_enabled, smb_encrypt
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ListShares.ps1

### Export CIFS Locks to CSV
Uses PowerShell to list CIFS locks for the specified Edge Appliance and exports the results to CSV.\
**Required Inputs**: NMC hostname, username, password, filer_serial, reportFile, limit, nmcApiVersion\
**Compatibility**: NMC API Version 1.2 (NMC 22.2 and higher), NMC API Version 1.1 (NMC 22.1 and older)\
**Name**: ExportCifsLocksToCSV.ps1

### Enable Mac Support for all Shares
This script uses the NMC API to list all shares, check for shares without Mac support and update those shares to enable Mac support. There is a 1.1 second pause after updating each share in order to avoid NMC throttling. Based on the pause, the script could take 1110 seconds to complete for 1000 shares this lists by default. Also, 1100 seconds only reflects the time the script will take to execute--the NMC could take considerably longer to contact each Edge Appliance and update share properties.\
**Required Inputs**: NMC hostname, username, password, FruitEnabled (True/False)\
**Compatibility**: Nasuni 8.0 or higher required\
**Name**: EnableMacSupportForAllShares.ps1

### Export CIFS Clients to CSV
Uses PowerShell to list CIFS clients for all Edge Appliance and exports the results to CSV. 
**Required Inputs**: NMC hostname, username, password, reportFile, limit, nmcApiVersion\
**Compatibility**: NMC API Version 1.2 (NMC 22.2 and higher), NMC API Version 1.1 (NMC 22.1 and older)\
**Output**: Edge Appliance Serial Number, User Name, Client_Name, Share ID (one line for each connected client)\
**Name**: ExportCifsClientsToCSV.ps1

### Replicate Shares from Source to Destination Edge Appliance
This script uses the NMC API to list all shares for source Edge Appliance, compare a listing of those shares on the destination Edge Appliance, and create the missing shares on the destination. Shares for volumes that are not owned or connected to the destination Edge Appliance are skipped. All share settings are copied from the source to the destination. Shares that are already present on the destination are not changed.\
**Required Inputs**: NMC hostname, username, password, SourceFilerSerialNumber, DestinationFilerSerialNumber\
**Compatibility**: Nasuni 8.0 or higher required\
**Known Issues**: none\
**Name**: ReplicateMissingShares.ps1

## NFS Exports
### Create an Export
Uses PowerShell to create an NFS Export by referencing an existing volume, Edge Appliance, and path. Useful as an example of how exports can be created using PowerShell.\
**Required Inputs**: NMC hostname, username, password, filer_serial, volume_guid, exportName, Path\
**Compatibility**: NMC 21.2 or higher required\
**Optional Inputs**: comment, readonly, hostspec, accessMode, perfMode, secOptions\
**Name**: CreateExport.ps1

### Export All NFS Exports and Settings to CSV
Uses PowerShell to export all NFS exports and configurable settings to CSV.\
**Required Inputs**: NMC hostname, username, password, reportFile, limit (preset to 1000 exports, but can be increased)\
**Compatibility**: Nasuni 7.10 or higher required; Requires PowerShell Version: 7.0 or higher.\
**Output CSV content**: exportId,Volume_GUID,filer_serial_number,export_name,path,comment,readonly,allowed_hosts,access_mode,perf_mode,sec_options,nfs_host_options\
**Name**: ExportAllNFSExportsToCSV.ps1

## FTP Directories
### Export All FTP Directories and Settings to CSV
Uses PowerShell to export all FTP directories and configurable settings to CSV.\
**Required Inputs**: NMC hostname, username, password, reportFile, limit (preset to 1000 FTP directories, but can be increased)\
**Compatibility**: Nasuni 7.10 or higher required; Requirs PowerShell Version: 7.0 or higher.\
**Output CSV content**: FtpId,Volume_GUID,filer_serial_number,ftp_name,path,comment,readonly,visibility,ip_restrictions,allowed_users,allowed_groups,allow_anonymous,anonymous_only,Permissions_on_new_files,hide_ownership,use_temporary_files_during_upload\
**Name**: ExportAllFtpDirectoriesToCSV.ps1

