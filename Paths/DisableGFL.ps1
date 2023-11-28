<# Disables GFL for the path provided. The script checks whether GFL was enabled on the path or if it was inherited from up the directory tree. 
The script lists the path, GFL enablement status, GFL mode, and GFL inheritance status. 
The script seeks acknowledgment before disabling GFL, as it also affects subfolders. 
Recursively disables GFL and triggers a subsequent snapshot to ensure GFL status is cleared for the given path.
Note: Disabling GFL can affect end-users. We recommend running this script when there is no end-user activity on the path.
#>
  
#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
  
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required).
#Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'
 
#specify Volume GUID
$volume_guid = "InsertVolumeGuidHere"

#specify Filer Serial Number
$filer_serial_number = "InsertFilerSerialHere"

#specify folder path using slashes (/) - do not include a trailing slash
$path = "/Share-1/Folder-1/Text_files"

#end variables


#Start of functions

#Function to check message status for POST API calls. 
#Loops as many times as specified in the Retry Counter to resolve pending state.
function Get-Message {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [object]$Response
    )
    
    #Message Status Retry Counterer
    $RetryCounter = 10
    
    #initial wait for message to process
    start-sleep -Seconds 1

    $Message = Invoke-RestMethod -Uri $Response.message.links.self.href -Method Get -Headers $headers

    While ($Message.status -eq "pending" -and $RetryCounter -gt 0) {
        #wait for message to process
        start-sleep -Seconds 5

        $Message = Invoke-RestMethod -Uri $Response.message.links.self.href -Method Get -Headers $headers
        
        $RetryCounter--
    }

    if ($Message.status -eq "synced") {
        $result = @{
            result_status = $Message.status
        }
    }
    elseif ($Message.status -eq "failure") {
        $result = @{
            result_status      = $Message.status
            result_error_code  = if ($Message.PSObject.Properties.Match($error)) {
                $Message.error.code
            }
            else { "" }
            result_description = if ($Message.PSObject.Properties.Match($error)) {
                $Message.error.description
            }
            else { "Error/Invalid Path" }
            
        
            
        }
    }
    #if message status is still pending after all the retries- check NMC
    elseif ($RetryCounter -eq 0 -and $Message.status -eq "pending") {
        $result = @{
            result_status      = $Message.status
            result_description = "Request is taking longer than expected to sync. Please check the NMC for status change"
        }
    }
    else {  
        $result = @{
            result_status = $Message.status
        }
    }
    return $result
}

#Function to invoke Delete GFL API and return status
function DisableGFL {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [object]$path
    )
    

    #Disabling GFL
    write-output "Disabling GFL on path: $path"

    #Set the URL for the folder update NMC API endpoint
    $GFLurl = "https://" + $hostname + "/api/v1.2/volumes/" + $volume_guid + "/global-lock-folders/" + $path
 
    #Delete GFL for the specified path
    $DeleteGFL = Invoke-RestMethod -Uri $GFLurl -Method Delete -Headers $headers -Body (ConvertTo-Json -InputObject $body)

    return $DeleteGFL
}

#End of functions


#Begin execution

#combine credentials for NMC authentication
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'
  
#Request token and build connection headers
# Allow untrusted SSL certs
if ($PSVersionTable.PSEdition -eq 'Core') { #PowerShell Core
    if ($PSDefaultParameterValues.Contains('Invoke-RestMethod:SkipCertificateCheck')) {}
    else {
        $PSDefaultParameterValues.Add('Invoke-RestMethod:SkipCertificateCheck', $true)
    }
}
else { #other versions of PowerShell
    if ("TrustAllCertsPolicy" -as [type]) {} else {		
	
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
    } 
}
 
#build JSON headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", 'application/json')
$headers.Add("Content-Type", 'application/json')
  
#construct Uri for login
$url = "https://" + $hostname + "/api/v1.1/auth/login/"
  
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization", "Token " + $token)


#Boolean variable to iterate while gfl status is enabled
$originalPathGFLStatus = "enabled"

while ($originalPathGFLStatus -ne "disabled") {

    #Boolean variable to track the path where GFL was set in the directory tree
    $gflPathFound = $false
    
    #Temporary path variable to track directory tree traversal incase of inheritance
    $gflEnabledPath = $path

    #counter to track the directory tree depth at which GL was set and inherited from
    #counter value higher than 0 indicates, GFL status was inherited
    $gflStatusInherited = 0

    #Loop through the directory tree untill path where GFL was enabled is found
    while (($gflPathFound -ne $true) -and ($gflEnabledPath.Length -gt 1)) {

       
        $InfoUrl = "https://" + $hostname + "/api/v1.2/volumes/" + $volume_guid + "/filers/" + $filer_serial_number + "/path" + $gflEnabledPath

        #Requesting information refresh for the path
        $RefreshInfo = Invoke-RestMethod -Uri $InfoUrl -Method Post -Headers $headers

        $MessageStatus = Get-Message -Response $RefreshInfo
    
        if ($MessageStatus.result_status -eq "synced") {

            #getting info for the path
            $GetInfo = Invoke-RestMethod -Uri $InfoUrl -Method Get -Headers $headers
        
            Write-Output "GFL enabled on Path: $gflEnabledPath :$($GetInfo.global_locking_enabled) "
        
            #If GFL is enabled, print GFL mode and inheritance status
            if ($GetInfo.global_locking_enabled -eq $true) {
                Write-Output "GFL Mode: $($GetInfo.global_locking_mode)"
                Write-Output "GFL Inherited: $($GetInfo.global_locking_inherited)"
            }

            if ($GetInfo.global_locking_enabled -eq $false) {

                if ($gflEnabledPath -eq $Path) {

                    $originalPathGFLStatus = "disabled"
                    Write-Output "GFL is disabled on the requested path "
                    break
                }

                Write-Output "GFL is not enabled on this path. "
            }
            elseif ($GetInfo.global_locking_inherited -eq $true) {

                #incrementing counter to track inheritance status
                $gflStatusInherited++

                Write-Output "GFL is inheritied on the path: $gflEnabledPath" 
            
                #Fetching the parent directory path
                $gflEnabledPath = $gflEnabledPath.Substring(0, $gflEnabledPath.LastIndexOf("/"))

                Write-Output "Checking its parent folder $gflEnabledPath"
            }
            else {

                #Path where GFL is enabled and not inherited from up the directory tree
                $gflPathFound = $true
                Write-Output "GFL is enabled on the path: $gflEnabledPath" 
            }


        }
        elseif ($MessageStatus.result_status -eq "failure") {

            Write-Output "Error while refreshing information on path: $gflEnabledPath"
            Write-Output "Error Code: $($MessageStatus.result_error_code) "
            Write-Output "Decription: $($MessageStatus.result_description) "

            #Setting boolean as false to exit while loop
            $originalPathGFLStatus = "disabled"
            break
            
        }
    

    }

    if ($gflPathFound) {
        
        #Incase GFL status was inherited, check with user whether to disable GFL on a different path
        if ($gflStatusInherited -gt 0) {

            Write-Host "GFL status was inherited from a directory up the tree." 

        }

        #Seeking confirmation before disabling GFL on the path. 
        Write-Host "Disabling GFL on this folder will disable GFL on all inherited sub-folders."
        $confirmSelection = Read-Host "Do you want to disable GFL on $gflEnabledPath. (Y/N):"

        if ($confirmSelection -ieq "Y") {
            
            $DisableGFLResponse = DisableGFL -path $gflEnabledPath
            
            #wait for GFL to disable
            start-sleep -Seconds 1

            $DisableGFLStatus = Get-Message -Response $DisableGFLResponse

            if ($DisableGFLStatus.result_status -eq "synced") {

                #A snapshot is required to reflect GFL status changes. 
                #triggering a snapshot to save change in GFL status
                $SnapshotURL = "https://" + $hostname + "/api/v1.2/volumes/" + $volume_guid + "/filers/" + $filer_serial_number + "/snapshots/"

                #checking if an existing snapshot is in-progress

                #Boolean variable to check if an existing snapshot is running
                $snapshot_in_progress = $true

                #Boolean variable to check is snapshot complete successfully
                $snapshot_pending = $true
        
                #counter to check snapshot status. Increase the value for long running snapshots
                $snapshot_status_check_counter = 5
 
                #checking if an existing snapshot running status
                while ($snapshot_in_progress -and $snapshot_status_check_counter -gt 0) { 
            
                    $SnapshotStatus = Invoke-RestMethod -Uri $SnapshotURL -Method Get -Headers $headers
     
                    if ($SnapshotStatus.items[0].snapshot_status -in ("pending", "in_progress")) {

                        Write-Output "An existing snapshot is in-progress or pending"

                        #Wait time for snapshot to complete
                        start-sleep -Seconds 15
                        $snapshot_status_check_counter--
                    }
                    else {
                        #No existing snapshots running
                        $snapshot_in_progress = $false
                        break
                    }   
         
                }
                #In case an existing snapshot was initiated but hasn't finished processing, end the script and initiate a manual snapshot
                if ($snapshot_in_progress -and $snapshot_status_check_counter -eq 0) {
                    Write-Output "An existing snapshot is in-progress. It may take a while to complete. Please check the NMC and initiate another snapshot"
                 
                    #breaking the primary loop as snapshot is taking too long to complete
                    $originalPathGFLStatus = "disabled"
                }
                else {

                    #No existing snapshots running. Initiating a new snapshot
                    $SnapshotRequest = Invoke-RestMethod -Uri $SnapshotURL -Method Post -Headers $headers

                    $SnapshotRequestStatus = Get-Message -Response $SnapshotRequest

                    if ($SnapshotRequestStatus.result_status -eq "synced") {

                        #Boolean variable to check is snapshot complete successfully
                        $snapshot_pending = $true
        
                        #counter to retry 
                        $snapshot_status_check_counter = 5
        
                        #checking snapshot running status
                        while ($snapshot_pending -and $snapshot_status_check_counter -gt 0) { 
                   
                            $SnapshotStatus = Invoke-RestMethod -Uri $SnapshotURL -Method Get -Headers $headers

                            Write-Output "Requested snapshot status: $($SnapshotStatus.items[0].snapshot_status)"

                            if ($SnapshotStatus.items[0].snapshot_status -in ("pending", "in_progress")) {

                                #Wait time for snapshot to complete
                                start-sleep -Seconds 15
            
                                $snapshot_status_check_counter--
                
                            }
                            else {

                                Write-Output "Requested snapshot has completed"
                                #Snapshot has successfully completed
                                $snapshot_pending = $false
                                break
                            }   
                
                        }
                        #In case snapshot was inititated but hasn't finished processing
                        if ($snapshot_pending -and $snapshot_status_check_counter -eq 0) {
                            Write-Output "Snapshot is in-progress. It may take a while to complete. Please check the NMC for change in status"
                        
                            #breaking the primary loop as snapshot is taking too long to complete
                            $originalPathGFLStatus = "disabled"
                        }
                    
                    }
                    elseif ($SnapshotRequestStatus.result_status -eq "failure") {
                    
                        Write-Output "Something went wrong. Check NMC."
                        Write-Output "Error Code: $($SnapshotRequestStatus.error.code)"
                        Write-Output "Error Description: $($SnapshotRequestStatus.error.description)"
                    }
                    else {
                        #Snapshot request is still pending
                        Write-Output "Snashot initiation is taking longer than expected. Check NMC"
                    }


                }
            }
            else {

                #Failed to disable GFL
                Write-Output "Something went wrong. Check NMC."
                Write-Output "Error Code: $($DisableGFLStatus.error.code)"
                Write-Output "Error Description: $($DisableGFLStatus.error.description)"
            }
        }
        else {
            #User elected not to disable GFL
            Write-Output "GFL will remain enabled on the path: $Path"
        }
    }
}
