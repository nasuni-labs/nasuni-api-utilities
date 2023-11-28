<# This script disables GFL on all the paths provided in a CSV file. 
The script seeks acknowledgment before disabling GFL, as it also affects subfolders. 
If GFL status is inherited from up the directory tree, GFL won't be disabled on the path. 
The script outputs a CSV file with details of GFL status for each path pre and post-execution. 
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


# Create an empty list
$gflObjectList = @()

#Path to CSV files
#specify folder path using slashes (/) - do not include a trailing slash
$inputFilePath = "c:\GFL\inputGFLFilePaths.csv"

$outputFilePath = "c:\GFL\outputGFLFilePaths.csv"

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
    
    #Message Status Retry Counter
    $RetryCounter = 10
    
    #initial wait for message to process
    start-sleep -Seconds 1

    $Message = Invoke-RestMethod -Uri $Response.message.links.self.href -Method Get -Headers $headers

    While ($Message.status -eq "pending" -and $RetryCounter -gt 0) {
        #wait for the message to process
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
            result_description = "Request is taking longer than expected to sync. Please check the NMC for status change."
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
#Login
#combine credentials for NMC authentication
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'
  
#Request token and build connection headers
# Allow untrusted SSL certs
if ($PSVersionTable.PSEdition -eq 'Core') {
    #PowerShell Core
    if ($PSDefaultParameterValues.Contains('Invoke-RestMethod:SkipCertificateCheck')) {}
    else {
        $PSDefaultParameterValues.Add('Invoke-RestMethod:SkipCertificateCheck', $true)
    }
}
else {
    #other versions of PowerShell
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

######
#get cvs



# Read the CSV file
$data = Import-Csv -Path $inputFilePath

# Display the data
Write-Output "$($data.Length) file paths detected"

#Add warning-
Write-Output "Disabling GFL on a given path will disable it for all subfolders."
Write-Output "Note: In case GFL is inherited from up the directory, GFL will remain enabled on the path."

$confirmSelection = Read-Host "Do you want to disable GFL on all the paths in the CSV file? (Y/N):"

if ($confirmSelection -ieq "Y") {

    # Iterate over the data

    Write-Output "Getting current information on all the paths."
    foreach ($item in $data) {
    
        $gflObject = [PSCustomObject]@{
            path                   = $item.path
            pre_run_gfl_state      = ""
            pre_run_gfl_mode       = ""
            pre_run_gfl_inherited  = ""
            post_run_gfl_state     = ""
            post_run_gfl_mode      = ""
            post_run_gfl_inherited = ""
            status                 = ""
            error_code             = ""
            error_description      = ""
            message_status         = ""
            message                = $null 
    
        }
        #Write-Host "Disabling GFL on Path: $($item.path)"
        $InfoUrl = $("https://" + $hostname + "/api/v1.2/volumes/" + $volume_guid + "/filers/" + $filer_serial_number + "/path" + $item.path)

    
        #Requesting information refresh for the path
        $RefreshInfo = Invoke-RestMethod -Uri $InfoUrl -Method Post -Headers $headers

        $MessageStatus = Get-Message -Response $RefreshInfo
    
        if ($MessageStatus.result_status -eq "synced") {

            #getting info for the path
            $GetInfo = Invoke-RestMethod -Uri $InfoUrl -Method Get -Headers $headers

            #collecting GFL configuration before changing them
            $gflObject.pre_run_gfl_state = $GetInfo.global_locking_enabled
            $gflObject.pre_run_gfl_mode = $GetInfo.global_locking_mode  
            $gflObject.pre_run_gfl_inherited = $GetInfo.global_locking_inherited         

        }
        elseif ($MessageStatus.result_status -eq "failure") {
            $gflObject.error_code = $MessageStatus.result_error_code
            $gflObject.error_description = $MessageStatus.result_description
        }

        $gflObjectList += $gflObject
    }

    Write-Output "Disabling GFL on all GFL-enabled paths."
    #disabling GFL
    foreach ($item in $gflObjectList) {

        #disabling GFL only if GFL was enabled on the path
        if ($item.pre_run_gfl_state) {
                
            $DisableGFLResponse = DisableGFL -path $item.path
        
            $item.message_status = $DisableGFLResponse.message.status

            if ($DisableGFLResponse.message.status -eq "pending") {
        
                $item.message = $DisableGFLResponse
            }
            elseif ($DisableGFLResponse.message.status -eq "failure") {
                $item.error_code = $DisableGFLResponse.message.error.code
                $item.error_description = $DisableGFLResponse.message.error.description
            }

            #for throttling
            start-sleep -Seconds 1
        }
    }

    #checking status change for disable GFL requests
    foreach ($item in $gflObjectList) {

        if ($item.message_status -eq "pending") {
        
            $MessageStatus = Get-Message -Response $item.message

            $item.status = $MessageStatus.result_status

            if ($MessageStatus.result_status -eq "failure") {
                $item.error_code = $MessageStatus.result_error_code
                $item.error_description = $MessageStatus.result_description
            }
        }
    }

    Write-Output "To reflect GFL status changes, a snapshot is required."

    #A snapshot is required to reflect GFL status changes. 
    #triggering a snapshot to save the change in GFL status
    $SnapshotURL = "https://" + $hostname + "/api/v1.2/volumes/" + $volume_guid + "/filers/" + $filer_serial_number + "/snapshots/"

    #Boolean variable to check if an existing snapshot is running
    $snapshot_in_progress = $true

    #Boolean variable to check is snapshot complete successfully
    $snapshot_pending = $true
        
    #counter to check snapshot status. Increase the value for long-running snapshots
    $snapshot_status_check_counter = 5
 
    #checking if an existing snapshot is in running status
    while ($snapshot_in_progress -and $snapshot_status_check_counter -gt 0) { 
            
        $SnapshotStatus = Invoke-RestMethod -Uri $SnapshotURL -Method Get -Headers $headers
     
        if ($SnapshotStatus.items[0].snapshot_status -in ("pending", "in_progress")) {

            Write-Output "An existing snapshot is in progress or pending."

            #Wait time for the snapshot to complete
            start-sleep -Seconds 15
            $snapshot_status_check_counter--
        }
        else {
\            #No existing snapshots running
            $snapshot_in_progress = $false
            break
        }   
         
    }
    #In case an existing snapshot was initiated but hasn't finished processing, end the script and initiate a manual snapshot
    if ($snapshot_in_progress -and $snapshot_status_check_counter -eq 0) {
       
        Write-Output "An existing snapshot is in progress. It may take a while to complete. Please check the NMC and initiate another snapshot."
                
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

                    #Wait time for the snapshot to complete
                    start-sleep -Seconds 15
            
                    $snapshot_status_check_counter--
                
                }
                else {

                    Write-Output "Requested snapshot has completed."
                    #Snapshot has successfully completed
                    $snapshot_pending = $false
                    break
                }   
                
            }
            #In case the snapshot was initiated but hasn't finished processing
            if ($snapshot_pending -and $snapshot_status_check_counter -eq 0) {
                Write-Output "Snapshot is in progress. It may take a while to complete. Please check the NMC for change in status."
            }
                    
        }
        elseif ($SnapshotRequestStatus.result_status -eq "failure") {
                    
            Write-Output "Something went wrong. Check NMC."
            Write-Output "Error Code: $($SnapshotRequestStatus.error.code)"
            Write-Output "Error Description: $($SnapshotRequestStatus.error.description)"
        }
        else {
            #Snapshot request is still pending
            Write-Output: "Snapshot initiation is taking longer than expected. Check NMC"
        }


    
    }
    
    #Update GFL status for the list paths
    if ($snapshot_pending -eq $false) {

        Write-Output "Updating GFL status for all the listed paths."
        foreach ($item in $gflObjectList) {

            $InfoUrl = "https://" + $hostname + "/api/v1.2/volumes/" + $volume_guid + "/filers/" + $filer_serial_number + "/path" + $item.path
    
            #Requesting information refresh for the path
            $RefreshInfo = Invoke-RestMethod -Uri $InfoUrl -Method Post -Headers $headers
    
            $MessageStatus = Get-Message -Response $RefreshInfo
        
            if ($MessageStatus.result_status -eq "synced") {
    
                #getting info for the path
                $GetInfo = Invoke-RestMethod -Uri $InfoUrl -Method Get -Headers $headers    
                
                #Update GFL state for the path
                $item.post_run_gfl_state = $GetInfo.global_locking_enabled
                $item.post_run_gfl_mode = $GetInfo.global_locking_mode  
                $item.post_run_gfl_inherited = $GetInfo.global_locking_inherited         
    
            }
            elseif ($MessageStatus.result_status -eq "failure") {
                $item.error_code = $MessageStatus.result_error_code
                $item.error_description = $MessageStatus.result_description
            }
        }

    }


    # Export the object to a CSV file
    $selectedAttributes = $gflObjectList | Select-Object path, pre_run_gfl_state, pre_run_gfl_mode, pre_run_gfl_inherited, post_run_gfl_state, post_run_gfl_mode, post_run_gfl_inherited, error_code, error_description

    $selectedAttributes | Export-Csv -Path $outputFilePath -NoTypeInformation

}
