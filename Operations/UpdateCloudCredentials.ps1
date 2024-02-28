#Update Cloud Credentials for a given CRED_UUID
#Available for NMC API v1.2 and onward
#Description: The script updates one credential at a time. The script updates all online Filers using the credential. 
#CRED UUID is used to identify cloud credentials. To find the CRED UUID, use the list cloud credential NMC API or the ListCloudCredential.ps1 Powershell script in the Nasuni Labs repo.  



#populate NMC hostname and credentials
$hostname = "insertHostname"
  
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Number of Credentials to query
$limit = 1000

#list of offline filers
$offlineFilers = @{}

#Boolean check for offline filers.
$continueUpdate = $true

#list of filers with pending filer status
$updatePending = @{}

#To track the number of API calls made per second
$throttleControl = 1

#Number of tries to recheck pending update status
$retryCounter = 2

#Credential UUID. Identifies the set of edge appliances that share a set of credentials.
$credUuid = "CredUUID"

#new credentials
$credAccessKey = "accesskey"
$credSecret = "secret"
$credHostname = "hostname"
$credName = "name"
$credNote = "notes"


#body for updating the cloud credentials. 
$body = @"
{
    "name": "$credName",
    "account": "$credAccessKey",
    "hostname": "$credHostname",
    "secret": "$credSecret",
    "note": "$credNote"
}
"@
#end variables



#combine credentials for authentication
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

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


#List credentials
$CredURL="https://"+$hostname+"/api/v1.2/account/cloud-credentials/"+$credUuid+"/?limit="+$limit+"&offset=0"
$getCredInfo = Invoke-RestMethod -Uri $CredURL -Method Get -Headers $headers

if($credUuid){
Write-Output "`nUpdating credentials for Cred_UUID: $credUuid `n"
}
else{
    Write-Output "`nCred UUID cannot be empty`n"
}

Write-Output "Number of Filers associated with Cred_UUID: $($getCredInfo.items.Count) `n"

#Checking if any filer is offline
$listFilerURL="https://"+$hostname+"/api/v1.2/filers/?limit="+$limit+"&offset=0"
$getFilerInfo = Invoke-RestMethod -Uri $listFilerURL -Method Get -Headers $headers

foreach($i in 0..($getCredInfo.items.Count-1)){
foreach($j in 0..($getFilerInfo.items.Count-1)){
    
    if($getCredInfo.items[$i].filer_serial_number -eq $getFilerInfo.items[$j].serial_number){

        if($getFilerInfo.items[$j].status.offline){
            $offlineFilers.Add($getCredInfo.items[$i].filer_serial_number,$getFilerInfo.items[$j].status.offline)
        }
    }
}
}

#Confirming before continuing updates with offline filers if any
if($offlineFilers.Count -gt 0){

$continueUpdate= $false
    
    Write-Output "The following filers are offline:"

    Write-Output $offlineFilers.Keys

    Write-Output "`nUpdates to the cloud credentials for these offline filers may not take effect"
    $continueUpdateResponse = Read-Host "Do you wish to continue(Y/N):"

    if($continueUpdateResponse -eq "Y"){
    $continueUpdate = $true
    }
}


if($continueUpdate){

Write-Output "Filer Serial Number: Update Status"

foreach($i in 0..($getCredInfo.items.Count-1)){

    $filer_serial_number = $getCredInfo.items[$i].filer_serial_number

    #patch requests to update credentials
    $PatchCredURL = "https://"+$hostname+"/api/v1.2/account/cloud-credentials/"+$credUuid+"/filers/"+$filer_serial_number+"/?limit="+$limit+"&offset=0"

    $patchCredInfo = Invoke-RestMethod -Uri $PatchCredURL -Method Patch -Headers $headers -Body $body

    $MessageURL = $patchCredInfo.message.links.self.href
    $getMessage = Invoke-RestMethod -Uri $MessageURL -Method Get -Headers $headers
    $datastring = "$($getMessage.filer_serial_number): $($getMessage.status)"

    Write-Output $datastring

    #Adding pending filers to a list and reporting failed statuses
   if($getMessage.status -eq "pending"){
        $updatePending.Add($getMessage.filer_serial_number, $MessageURL)
    } 
    elseif($getMessage.status -eq "failure"){
       Write-Output "$($getMessage.error.code): $($getMessage.error.description)"
    }

    $i++

    #Wait in accordance to NMC API throlling (Patch request)
    Start-Sleep -s 1.1
}

while(($updatePending.Count -gt 0) -and ($retryCounter -ge 0)){ 
#if($updatePending.Count -gt 0) {
    Write-Output "`nChecking for pending updates `n"

    $retryUpdate = $updatePending.Clone()
  
    foreach($i in $retryUpdate.GetEnumerator()){

    #Wait in accordance to NMC API throlling (Get request)
    $throttleControl++
    if((($throttleControl) % 5) -eq 0){
        Start-Sleep -s 1.1
    }   

    $MessageURL = $i.Value
    $getMessage = Invoke-RestMethod -Uri $MessageURL -Method Get -Headers $headers
    $datastring = "$($getMessage.filer_serial_number): $($getMessage.status)"

    Write-Output $datastring

    #Remove synced filers from the pending list
    if($getMessage.status -eq "synced"){
        $updatePending.Remove($getMessage.filer_serial_number)
    }
    elseif($getMessage.status -eq "failure"){
        #$updateFailed.Add($getMessage.filer_serial_number, $message_id)
        $updatePending.Remove($getMessage.filer_serial_number)
       Write-Output "$($getMessage.error.code):  $($getMessage.error.description) `n"
    }
    #$i++
    }
    $retryCounter--
    
    #One second wait before next retry
    Start-Sleep -s 1.1
}

#Final advisory for pending filers
if($updatePending.Count -gt 0){
    Write-Output "`nSome filers haven't synced yet. Please check NMC to track changes"
}

}
