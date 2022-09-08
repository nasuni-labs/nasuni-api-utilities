# nmc-api-powershell-utilities
Utlilities and scripts that use the NMC API to perform operations and generate reports

# Reporting and Chargeback
Use these NMC API scripts to help with reporting and chargeback.

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

## Export Top Level Folder Sizes to CSV
Get the size of top level folders within a share using the NMC API and export the results to CSV. Uses the Edge Appliance Data API to provide the list of top level folders within the share — assumes all shares are connected to the Edge Appliance specified in the script. Shares to query for Top Level folders need to have the 'Sync and Mobile Access' share-level Advanced Setting enabled. Leave this off for other shares.

**API Endpoints Used**:  
* NMC API: List Shares (GET) - http://docs.api.nasuni.com/nmc/api/1.2.0/index.html#list-shares
* NMC API: Refresh Info on Path (POST) - http://docs.api.nasuni.com/nmc/api/1.2.0/index.html#refresh-info-about-a-given-path  
* NMC API: Get Info on a Path (GET) - http://docs.api.nasuni.com/nmc/api/1.2.0/index.html#get-info-on-a-specific-path
* Data API: Get items (GET) - http://b.link/Nasuni_API_Documentation

**Required Inputs**: NMC hostname, NMC username, NMC password, Data API username, Data API Password, Top Level Folder, Report File, Limit\
**Compatibility**: Nasuni 8.5 or higher required\
**Output CSV content**: volume_guid, filer_serial_number, path, size\
**Known Issues**: Edge Appliances must be online, NMC managed, and running Nasuni 8.5 or higher in order to retrieve folder size. The Data API user must have NTFS permissions to the folders being listed.\
**Name**: ExportTopLevelFolderSizesToCSV.ps1

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
