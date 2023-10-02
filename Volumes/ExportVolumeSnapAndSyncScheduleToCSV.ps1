#Get Volume Snapshot and Sync Schedule and Export them to CSV

#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
 
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"
 
#path to CSV
$reportFile = "c:\export\VolumeSnapAndSyncSchedule.csv"

#Number of Edge Appliances and Volumes to query
$limit = 1000
 
#end variables

#combine credentials for token request
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

#Request token and build connection headers 
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

#Initialize CSV output file
$csvHeader = "VolumeName,FilerName,VolumeGuid,FilerSerialNumber,SnapSchedMon,SnapSchedTue,SnapSchedWed,SnapSchedThu,SnapSchedFri,SnapSchedSat,SnapSchedSun,SnapSchedAllday,SnapSchedStart,SnapSchedStop,SnapSchedFrequency,SyncSchedMon,SyncSchedTue,SyncSchedWed,SyncSchedThu,SyncSchedFri,SyncSchedSat,SyncSchedSun,SyncSchedAllday,SyncSchedStart,SyncSchedStop,SyncSchedFrequency,SyncSchedAutocacheAllowed,SyncSchedAutocacheMinFileSize"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8

#List filers
$FilersUrl="https://"+$hostname+"/api/v1.1/filers/?limit="+$limit+"&offset=0"
$GetFilerInfo = Invoke-RestMethod -Uri $FilersUrl -Method Get -Headers $headers
 
#List volumes
$url="https://"+$hostname+"/api/v1.1/volumes/?limit="+$limit+"&offset=0"
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
 
foreach($i in 0..($getinfo.items.Count-1)){

   #call the list filer specific settings for a volume endpoint
     $volumefilerurl = "https://"+$hostname+"/api/v1.1/volumes/" + $getinfo.items.guid[$i] + "/filers/?limit=' + $limit + '&offset=0/"
     $volumeinfo = Invoke-RestMethod -Uri $volumefilerurl -Method Get -Headers $headers

      #loop through each item in FilerSettingsInfo
        foreach($j in 0..($volumeinfo.items.Count-1)){
        $VolumeName = $volumeinfo.items[$j].name

        #loop through the filer info to get the filer description
            foreach($m in 0..($GetFilerInfo.items.Count-1)){
            $FilerSerial = $GetFilerInfo.items[$m].serial_number
            $FilerDescription = $GetFilerInfo.items[$m].description
            if ($FilerSerial -eq  $volumeinfo.items[$j].filer_serial_number) {$FilerName = $FilerDescription}
    $m++}
      $VolumeGuid = $volumeinfo.items[$j].guid  
      $FilerSerial = $volumeinfo.items[$j].filer_serial_number
      $SnapSchedMon = $volumeinfo.items[$j].snapshot_schedule.days.mon
      $SnapSchedTue = $volumeinfo.items[$j].snapshot_schedule.days.tue
      $SnapSchedWed = $volumeinfo.items[$j].snapshot_schedule.days.wed
      $SnapSchedThu = $volumeinfo.items[$j].snapshot_schedule.days.thu
      $SnapSchedFri = $volumeinfo.items[$j].snapshot_schedule.days.fri
      $SnapSchedSat = $volumeinfo.items[$j].snapshot_schedule.days.sat
      $SnapSchedSun = $volumeinfo.items[$j].snapshot_schedule.days.sun
      $SnapSchedAllday = $volumeinfo.items[$j].snapshot_schedule.allday
      $SnapSchedStart = $volumeinfo.items[$j].snapshot_schedule.start
      $SnapSchedStop = $volumeinfo.items[$j].snapshot_schedule.stop
      $SnapSchedFrequency = $volumeinfo.items[$j].snapshot_schedule.frequency
      $SyncSchedMon = $volumeinfo.items[$j].sync_schedule.days.mon
      $SyncSchedTue = $volumeinfo.items[$j].sync_schedule.days.tue
      $SyncSchedWed = $volumeinfo.items[$j].sync_schedule.days.wed
      $SyncSchedThu = $volumeinfo.items[$j].sync_schedule.days.thu
      $SyncSchedFri = $volumeinfo.items[$j].sync_schedule.days.fri
      $SyncSchedSat = $volumeinfo.items[$j].sync_schedule.days.sat
      $SyncSchedSun = $volumeinfo.items[$j].sync_schedule.days.sun
      $SyncSchedAllday = $volumeinfo.items[$j].sync_schedule.allday
      $SyncSchedStart = $volumeinfo.items[$j].sync_schedule.start
      $SyncSchedStop = $volumeinfo.items[$j].sync_schedule.stop
      $SyncSchedFrequency = $volumeinfo.items[$j].sync_schedule.frequency
      $SyncSchedAcAllowed = $volumeinfo.items[$j].sync_schedule.auto_cache_allowed
      $SyncSchedAcMinFileSize = $volumeinfo.items[$j].sync_schedule.auto_cache_min_file_size

       $datastring = "$VolumeName,$FilerName,$VolumeGuid,$FilerSerial,$SnapSchedMon,$SnapSchedTue,$SnapSchedWed,$SnapSchedThu,$SnapSchedFri,$SnapSchedSat,$SnapSchedSun,$SnapSchedAllday,$SnapSchedStart,$SnapSchedStop,$SnapSchedFrequency,$SyncSchedMon,$SyncSchedTue,$SyncSchedWed,$SyncSchedThu,$SyncSchedFri,$SyncSchedSat,$SyncSchedSun,$SyncSchedAllday,$SyncSchedStart,$SyncSchedStop,$SyncSchedFrequency,$SyncSchedAcAllowed,$SyncSchedAcMinFileSize"
       #write the results to the CSV
       Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append

        $j++}
        #sleep to avoid NMC API throttling
        Start-sleep 1.1

$i++
}
