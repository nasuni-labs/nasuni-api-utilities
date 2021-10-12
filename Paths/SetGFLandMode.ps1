#Sets GFL Snapshot Status for a path
#Checks the Volumes snapshot status for all Edge Appliances and waiting until idle before executing
#It then checks to see if the path is valid before setting GFL and mode.

#Uses the list snapshot statuses for a volume NMC API endpoint
#http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#list-snapshot-statuses-for-a-volume

#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
  
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'
  
#specify Nasuni volume guid
$volume_guid = "InsertVolumeGuid"

#Set the path for GetPathInfo. The path should start with a "\", is case sensitive, and is the path as displayed in the NMC file browser
# and is not related to the share path.
$FolderPath = "\insert\path\here" 

#Set the desired GFL mode - "optimized, advanced, or asynchronous"
$mode = "optimized"

#Specify Number of times to Retry before giving up
$RetryLimit = "10"

#Specify delay between retries in seconds
$RetryDelay = "30"

#end variables

#change the direction of slashes in folder path for use with the NMC API
$FolderPath = $FolderPath -replace '\\', '/'

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
  
#construct Uri for the token
$url="https://"+$hostname+"/api/v1.1/auth/login/"
   
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)

#Get Volume info URL to find the owning Edge Appliance Serial Number
$VolumeInfoURL="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/"

$GetVolumeInfo = Invoke-RestMethod -Uri $VolumeInfoURL -Method Get -Headers $headers
$filer_serial = $GetVolumeInfo.items[0].filer_serial_number

#Get snapshot status URL
$SnapshotStatusURL="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/snapshots/"

#Set the retry counter to one before starting the loop
$RetryCount = 1

#run loop the number of times specified by the Retry Limit or until the snapshot status is idle
DO
{
write-output "Starting Loop $RetryCount"
#check for Volume snapshot status for all Edge Appliances
$GetSnapshotInfo = Invoke-RestMethod -Uri $SnapshotStatusURL -Method Get -Headers $headers
    foreach($i in 0..($GetSnapshotInfo.items.Count-1)){
        $SnapshotArrayStatus = $GetSnapshotInfo.items[$i].snapshot_status
        $SnapshotArrayFiler = $GetSnapshotInfo.items[$i].filer_serial_number
        write-host $SnapshotArrayStatus "for filer serial number" $SnapshotArrayFiler
            if ($SnapshotArrayStatus -ne "idle") {
            $SnapshotBusy = $true
            write-output "Setting Snapshot Busy to True"
            }
    $i++
    }

#Execute command if Snapshot status is idle, otherwise retry
    if ($SnapshotBusy -ne $true) {
        write-output "Snapshot is Idle for all Edge Appliances running set GFL command"
        #Build the URL for the endpoints
        $PathInfoURL="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + "$filer_serial" + "/path" + $FolderPath
 
        #Refresh Stats on the supplied path
        $RefreshPathInfo=Invoke-RestMethod -Uri $PathInfoURL -Method POST -Headers $headers

        #sleep to allow time for the refresh to complete
        Start-Sleep -s 1

        #Lookup the status of the message ID that is returned from the NMC when POSTing to the Refresh Stats NMC API endpoint
        $Message=Invoke-RestMethod -Uri $RefreshPathInfo.message.links.self.href -Method Get -Headers $headers

            #check for the pending condition and if pending, retry after 5 seconds
            if ($Message.status -eq "pending") {
            start-sleep -s 5
            $Message=Invoke-RestMethod -Uri $RefreshPathInfo.message.links.self.href -Method Get -Headers $headers
            }

        #Check to see if the path is valid by checking to see if the status returns as synced. If it does, set GFL for the path. 
            #If the the status is something else, skip and log.
            if ($Message.status -eq "synced") {
            #enable GFL for path
            #Set the URL for the folder update NMC API endpoint
            $GFLurl="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/global-lock-folders/"

            #build the body for the folder update
            $body = @{
            path = $FolderPath
            mode = $mode
            }
            $SetGFL=Invoke-RestMethod -Uri $GFLurl -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $body)
            write-output $SetGFL | ConvertTo-Json
            }
            else {
    #skip and log pending messages or failure
    if ($Message.status -eq "pending") {write-output "Refresh Path Info operation still pending--please try again"}
    else {write-output $message.status}
            }
            break
            } else {
            #sleep for defined time in Retry delay
            write-host("sleeping for $RetryDelay seconds")
            Start-Sleep -s $RetryDelay
            #end setGFL condition
            }

#Increment the RetryCount and clear SnapshotBusy before retrying
 $RetryCount++
 Clear-Variable SnapshotBusy

 write-output "Now `$Retries is $RetryCount"
 #If the end of the loop completes and the snapshot is still running, log the results
 if ($RetryCount -eq $RetryLimit) {
     write-output "Snapshot still running--retries exceeded"
 }

} Until ($RetryCount -eq $RetryLimit)


