# nmc-api-powershell-utilities
Utlilities and scripts that use the NMC API to perform operations and generate reports

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
Exports folder quotas and rules to CSV\
**Required Inputs**: NMC hostname, username, password, limit\
**Output**: Quota ID, VolumeGuid, FilerSerial, Path, Quota Type, Quota Limit, Quota Usage, Email\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ExportFolderQuotasToCSV.ps1
