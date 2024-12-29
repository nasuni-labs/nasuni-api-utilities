<# Sets GFL Snapshot Status for the path provided and retries using a delay until complete
Does not check snapshot status before attempting to set GFL
Checks the message status after submitting GFL request to see if the operation was completed successfully
Writes the following info to the console: path, retry number, status
Includes error handling for invalid paths #>
  
#populate NMC hostname and credentials
$hostname = "InsertNMCHostname"
  
<#Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"
 
#specify Volume GUID
$volume_guid = "insertVolumeGUID"

#specify folder path using slashes (/) - do not include a trailing slash
$path = "/folder1/folder2"

#Set the desired GFL mode - "optimized, advanced, or asynchronous"
$mode = "optimized"

#Specify the number of times to retry before giving up
$RetryLimit = 20

#Specify the delay between retries in seconds
$RetryDelay = 30

#end variables
  
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
 
#Read the token from a file and add it to the headers for the request
$token = Get-Content $tokenFile
$headers.Add("Authorization","Token " + $token)

#start working on setting GFL

#set the RetryCount to 1 before beginning the loop
$RetryCount = 1

write-output "Setting $mode GFL mode on: $path"

#run loop the number of times specified by the Retry Limit or until the snapshot status is idle
DO
{
write-output "Loop $RetryCount"

#enable GFL for path
#Set the URL for the folder update NMC API endpoint
$GFLurl="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/global-lock-folders/"
            
#build the body for the folder update
$body = @{
path = $Path
mode = $mode
}

#set GFL and mode for the specified path
$SetGFL=Invoke-RestMethod -Uri $GFLurl -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $body)

#wait for setting GFL to complete
start-sleep -Seconds 5

#see what happened when setting GFL
$Message=Invoke-RestMethod -Uri $SetGFL.message.links.self.href -Method Get -Headers $headers

    #check for the pending condition and if pending, retry after 5 seconds
    if ($Message.status -eq "pending") {
        start-sleep -s 10
        #get the message again to see if waiting longer helped
        $Message=Invoke-RestMethod -Uri $SetGFL.message.links.self.href -Method Get -Headers $headers
        }
    #if message status is synced the set GFL operation was successful
    if ($Message.status -eq "synced") {
        $status = "success"
        #this path is done - exit the loop
        write-output $status
        break
        }
    #handle failure cases
    if ($Message.status -eq "failure") {
        if ($Message.error.description -like "*snapshot is taking place*"){
            #snapshot is busy - we need to retry
            write-output "Snapshot Busy"
        }
        else {
            #failure from invalid path -log and exit loop
            $status = "Invalid Path"
            write-output $status    
            break
        }
        #clean up the sync error
        $DeleteMessageURL = $message.links.acknowledge.href
        #call deleteMessage uses a variable to suppress output
        $DeleteMessage = Invoke-RestMethod -Uri $DeleteMessageURL -Method Delete -Headers $headers -Body $credentials
        }

 #Increment the RetryCount before retrying
 $RetryCount++

 #If the end of the loop completes and the snapshot is still running end the loop and clean up the pending request
 if ($RetryCount -ge $RetryLimit) {
     write-output "Snapshot still running--retries exceeded, removing pending request"
     $status = "retryExceeded"

     #clean up the pending request
     $DeleteMessageURL = $message.links.acknowledge.href
     #call deleteMessage uses a variable to suppress output
     $DeleteMessage = Invoke-RestMethod -Uri $DeleteMessageURL -Method Delete -Headers $headers -Body $credentials
 }

#sleep for defined time in Retry delay before starting the loop again
Start-Sleep -s $RetryDelay    

            } Until ($RetryCount -ge $RetryLimit)
        
