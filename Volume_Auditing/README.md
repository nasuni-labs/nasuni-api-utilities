# nmc-api-powershell-utilities
Utlilities and scripts that use the NMC API to perform operations and generate reports

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
