#Export all shares along with path information, including size, to CSV

#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
 
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Set Path for CSV Export
$reportFile = "c:\reports\SharesAndPathInfo.csv"

#Number of shares, filers, and volumes to query
$limit = 1000

#Specify the Number of times to retry getting status on a path before giving up
$RetryLimit = 20

#Specify the delay between POST and GET operations
$Delay = 5

#end variables

#combine credentials for token request
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

# Allow untrusted SSL certs - remove if valid NMC SSL cert is installed
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

#Connect to the List all shares for the filer NMC API endpoint
$GetShareInfoUrl="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit="+$limit+"&offset=0"
$FormatEnumerationLimit=-1
$GetShareInfo = Invoke-RestMethod -Uri $GetShareInfoUrl -Method Get -Headers $headers 

#Initialize CSV output file
$csvHeader = "shareid,volume_name,volume_guid,filer_name,filer_serial,share_name,path,comment,cache_resident,protected,owner,size,pinning_enabled,pinning_mode,pinning_inherited,autocache_enabled,autocache_mode,autocache_inherited,quota_enabled,quota_type,quota_email,quota_usage,quota_limit,quota_inherited,global_locking_enabled,global_locking_inherited,global_locking_mode"

Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting Volume Information to: " + $reportFile)

#List filer info
$FilersUrl="https://"+$hostname+"/api/v1.1/filers/?limit="+$limit+"&offset=0"
$GetFilerInfo = Invoke-RestMethod -Uri $FilersUrl -Method Get -Headers $headers 
  
#List volume info
$VolumeUrl="https://"+$hostname+"/api/v1.1/volumes/?limit"+$limit+"&offset=0"
$GetVolumeInfo = Invoke-RestMethod -Uri $VolumeUrl -Method Get -Headers $headers 

#Loop through the shares for the CSV export

foreach($i in 0..($GetShareInfo.items.Count-1)){
    	
	#change the the slash direction for use with NMC API input
    $NormalizedPath = $($GetShareInfo.items.path[$i]).replace("\","/")

    #loop through the filer info to get the filer description
    foreach($m in 0..($GetFilerInfo.items.Count-1)){
        $FilerSerial = $GetFilerInfo.items[$m].serial_number
        $FilerDescription = $GetFilerInfo.items[$m].description
        if ($FilerSerial -eq  $GetShareInfo.items[$i].filer_serial_number) {$FilerName = $FilerDescription}
    $m++}
    
    #loop through the volume info to get the volume description
    foreach($n in 0..($GetVolumeInfo.items.Count-1)){
        $VolumeGuid = $GetVolumeInfo.items[$n].guid
        $VolumeDescription = $GetVolumeInfo.items[$n].name
        if ($VolumeGuid -eq  $GetShareInfo.items[$i].volume_guid) {$VolumeName = $VolumeDescription}
    $n++}
    
	#Build the URL for the Get Path Info Endpoint
    $GetPathInfoURL="https://"+$hostname+"/api/v1.1/volumes/" + $($GetShareInfo.items.Volume_Guid[$i]) + "/filers/" + $($GetShareInfo.items.filer_serial_number[$i]) + "/path" + $NormalizedPath
    write-output $GetPathInfoURL	
    
    #run loop the number of times specified by the Retry Limit
    #set the RetryCount to 1 before begging the loop
    $RetryCount = 1
    DO
    {
    write-output "Getting Share Info, attempt number: $RetryCount"

    #Refresh Stats on the supplied path
    $RefreshStats = Invoke-RestMethod -Uri $GetPathInfoURL -Method POST -Headers $headers

    #Sleep to allow time for the refresh stats to complete
    Start-Sleep -s $Delay

    #check to see the status of the refresh stats request
    $RefreshMessage=Invoke-RestMethod -Uri $RefreshStats.message.links.self.href -Method Get -Headers $headers

    #check if message status is synced and if it is, exit the loop so we can get the path info
        if ($RefreshMessage.status -eq "synced") {
            #Get Path Info to get the size of the share
            $GetPathInfo = Invoke-RestMethod -Uri $GetPathInfoURL -Method Get -Headers $headers

            #Gather all details and write them to the output file
            $datastring =  "$($GetShareInfo.items[$i].id),$VolumeName,$($GetShareInfo.items[$i].volume_guid),$FilerName,$($GetShareInfo.items[$i].filer_serial_number),$($GetShareInfo.items[$i].name),$($GetShareInfo.items[$i].path),$($GetShareInfo.items[$i].comment),$($GetPathInfo.cache_resident),$($GetPathInfo.protected),$($GetPathInfo.owner),$($GetPathInfo.size),$($GetPathInfo.pinning_enabled),$($GetPathInfo.pinning_mode),$($GetPathInfo.pinning_inherited),$($GetPathInfo.autocache_enabled),$($GetPathInfo.autocache_mode),$($GetPathInfo.autocache_inherited),$($GetPathInfo.quota_enabled),$($GetPathInfo.quota_type),$($GetPathInfo.quota_email),$($GetPathInfo.quota_usage),$($GetPathInfo.quota_limit),$($GetPathInfo.quota_inherited),$($GetPathInfo.global_locking_enabled),$($GetPathInfo.global_locking_inherited),$($GetPathInfo.global_locking_mode)"
            
            Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
            
            #this path is done, write the status to the console and exit the loop
            write-output "Share Info Export Successful"
            break
            }
    
     #Increment the RetryCount before retrying
     $RetryCount++

        if ($RetryCount -ge $RetryLimit) {
        write-output "Retries exceeded, moving on to next share"} 

    } Until ($RetryCount -ge $RetryLimit)
	

    #clear variables for next loop
    $ClearVar = ("GetPathInfo", "VolumeName", "VolumeGuid", "FilerName", "FilerSerial")
        foreach ($Item in $ClearVar) {
            Get-Variable $Item -ErrorAction SilentlyContinue | Remove-Variable -ErrorAction SilentlyContinue
        }
} 
