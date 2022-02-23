# nmc-api-powershell-utilities
Utlilities and scripts that use the NMC API to perform operations and generate reports

# Volumes
PowerShell NMC API Scripts for working with volumes. 

## Create a Volume
Uses PowerShell to create a volume.\
**Required Inputs**: NMC hostname, username, password, volume_name, filer_serial_number, cred_id, provider_name, shortname, location, permissions_policy, authenticated_access, policy, policy_label, auto_provision_cred, key_name, create_default_access_point, case_sensitive\
**Fields and values**:
* shortName: amazons3, azure, googles3 (9.0 version of the google connector), vipr (ecs)
* location (case-sensitve):
    * s3 locations: default, Asia, Beijing, Canada, EU, Frankfurt, HongKong, London, Mumbai, Ningxia, Ohio, Oregon, Paris, Seoul, SouthAmerica, Stockholm, Sydney, Tokyo, UsWest
    * Azure: Not Applicable - location is associated with the cred specified
    * on-prem object stores: default
* permissions_policy: PUBLICMODE60 (PUBLIC), NTFS60 (NTFS Compatible), NTFSONLY710 (NTFS Exlusive)
* policy: public (no auth), ads (active directory)

<!-- -->

**Compatibility**: Nasuni 8.0 or higher required\
**Known Issues and Notes**:\
Creating a volume using an existing encryption key: When referencing an existing encryption key rather than creating encryption key, you should not include the “create_new_key”: “false” option. This must be omitted until Issue 27807 is fixed.

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

## Set Volume Remote Access
Sets remote access (enable/disable) and permissions for remote access. \
**Required Inputs**: NMC hostname, tokenFile (path to token from getToken.ps1), volume_guid, remoteAccessEnabled, remoteAccessPermissions \
**Compatibility**: Nasuni 8.0 or higher required\
**Name**: SetVolumeRemoteAccess.ps1
