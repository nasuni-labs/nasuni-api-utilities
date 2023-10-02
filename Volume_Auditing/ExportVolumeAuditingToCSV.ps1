#Get Volume Audit settings for all Volumes and Connected Filers and Export them to CSV

#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"
 
#path to CSV
$reportFile = "c:\export\GetAuditSettings.csv"

#Number of Edge Appliances and Volumes to query
$limit = 1000
 
#end variables

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
$csvHeader = "VolumeName,FilerName,FilerSerialNumber,AuditingEnabled,Create,Delete,Rename,Close,Security,Metadata,Write,Read,PruneAuditLogs,DaysToKeep,ExcludeByDefault,IncludeTakesPriority,IncludePatterns,ExcludePatterns,SyslogExportEnabled"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8

#List filers
$FilersUrl="https://"+$hostname+"/api/v1.1/filers/?limit="+$limit+"&offset=0"
$GetFilerInfo = Invoke-RestMethod -Uri $FilersUrl -Method Get -Headers $headers
 
#List volumes
$url="https://"+$hostname+"/api/v1.1/volumes/?limit="+$limit+"&offset=0"
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
 
foreach($i in 0..($getinfo.items.Count-1)){

   #call the list filer specific settings for a volume endpoint
     $volumefilerurl = "https://"+$hostname+"/api/v1.1/volumes/" + $getinfo.items.guid[$i] + "/filers/?limit=200&offset=0/"
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
      $FilerSerial = $volumeinfo.items[$j].filer_serial_number
       $AuditingEnabled = $volumeinfo.items[$j].auditing.enabled
       $EventsCreate = $volumeinfo.items[$j].auditing.events.create
       $EventsDelete = $volumeinfo.items[$j].auditing.events.delete
       $EventsRename = $volumeinfo.items[$j].auditing.events.rename
       $EventsClose = $volumeinfo.items[$j].auditing.events.close
       $EventsSecurity = $volumeinfo.items[$j].auditing.events.security
       $EventsMetadata = $volumeinfo.items[$j].auditing.events.metadata
       $EventsWrite = $volumeinfo.items[$j].auditing.events.write
       $EventsRead = $volumeinfo.items[$j].auditing.events.read
       $PruneAuditLogs = $volumeinfo.items[$j].auditing.logs.prune_audit_logs
       $DaysToKeep = $volumeinfo.items[$j].auditing.logs.days_to_keep
       $ExcludeByDefault = $volumeinfo.items[$j].auditing.logs.exclude_by_default
       $IncludeTakesPriority = $volumeinfo.items[$j].auditing.logs.include_takes_priority
       $IncludePatterns = $volumeinfo.items[$j].auditing.logs.include_patterns
       $ExcludePatterns = $volumeinfo.items[$j].auditing.logs.exclude_patterns
       $SyslogExport = $volumeinfo.items[$j].auditing.logs.syslog_export
       $datastring = "$VolumeName,$FilerName,$FilerSerial,$AuditingEnabled,$EventsCreate,$EventsDelete,$EventsRename,$EventsClose,$EventsSecurity,$EventsMetadata,$EventsWrite,$EventsRead,$PruneAuditLogs,$DaysToKeep,$ExcludeByDefault,$IncludeTakesPriority,$IncludePatterns,$ExcludePatterns,$SyslogExport"
       #write the results to the CSV
       Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append

        $j++}
        #sleep to avoid NMC API throttling
        Start-sleep 1.1

$i++
}
