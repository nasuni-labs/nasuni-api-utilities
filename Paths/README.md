# nmc-api-powershell-utilities
Utlilities and scripts that use the NMC API to perform operations and generate reports

# Paths
## Working With Paths
Scripts that use the NMC API to list and control settings for paths. Nasuni provides two primary NMC API endpoints to deal with paths and path status:

1. Refresh info about a given path: http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#refresh-info-about-a-given-path. Posting to this endpoint causes the NMC to request current information from the associated Edge Appliance for the path (statting it). Once this is done, the path is considered to be a "known path" for the Get info on a specific path endpoint. Known paths are only cached for 10 minutes before expiring.
2. GET info on a specific path (only valid for known paths): http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#get-info-on-a-specific-path. Calling this NMC API endpoint and specifying the Edge Appliance serial and path, asks the NMC to give the requestor information it has about the specified path. This only works if the path is a "known path"-- In other words, if the path has recently been enumerated/statted by the NMC file browser or API call. 

Finally, the "Get a list of all known paths with a specific volume and filer", http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#get-a-list-of-all-known-paths, can be used to get a list of paths that are "known"--in other words, have recently been statted by Posting to "refresh info about a given path". A directory reported as being reported as "known" just lets you know that it is eligible to be used with the "GET info on a specific path" endpoint. Known paths expire from the NMC after 10 minutes.

## Get Path Info
This script uses the NMC API to get info for specified path. It first calls the "refresh info" endpoint to update stats for the path and then calls the "get info" endpoint.\
**Required Inputs**: NMC hostname, username, password, volume_guid, filer_serial, path - The path should start with a "/" and is the path as displayed in the volume file browser and is not related to the share path--it should start at the volume root. Path is case sensitive.\
**Compatibility**: Nasuni 8.5 or higher required\
**Name**: GetPathInfo.ps1, GetPathInfo.png


## Bring Path into Cache
This script uses the NMC API to bring the specified path into cache. By default, both the metadata and data for the specified path are brought into cache. Bringing only the metadata into cache is an option if $MetadataOnly is set to "true".\
**NMC API Endpoints Used**: Bring Path Into Cache -http://docs.api.nasuni.com/nmc/api/1.2.0/index.html#bring-path-into-cache
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
**Name**: DisableAutocache.ps1

## Export Auto Cache Folders to CSV
Exports a list of Auto Cache enabled folders to CSV.\
**Required Inputs**: NMC hostname, username, password, limit\
**Output**: volume_guid, filer_serial_number, path, autocache mode\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ExportAutoCacheFoldersToCSV.ps1

## Export Pinned Folders to CSV
Exports a list of pinned folders to CSV.\
**Required Inputs**: NMC hostname, username, password, limit\
**Output**: volume_guid, filer_serial_number, path, pinning mode\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: ExportPinnedFoldersToCSV.ps1
