#Export Antivirus Violations to CSV
 
#populate NMC hostname and credentials
$hostname = "host.domain.com"
  
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"
  
#path to CSV
$reportFile = "c:\export\AntivirusViolationsExport.CSV"

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
 
#initialize csv output file
$csvHeader = "VolumeName,VolumeGUID,FilerName,FilerSerial,VirusName,VirusPath"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
 
#List up to the first 200 filers - adjust limit in the URL if more are required
$FilersUrl="https://"+$hostname+"/api/v1.1/filers/?limit=200&offset=0"
$GetFilerInfo = Invoke-RestMethod -Uri $FilersUrl -Method Get -Headers $headers 
  
#List up to the first 200 volumes - adjust limit in the URL if more are required
$VolumeUrl="https://"+$hostname+"/api/v1.1/volumes/?limit=200&offset=0"
$GetVolumeInfo = Invoke-RestMethod -Uri $VolumeUrl -Method Get -Headers $headers 

#List up the first 200 AV Violations - adjust limit in the URL if more are required
$AvUrl="https://"+$hostname+"/api/v1.1/volumes/filers/antivirus-violations/?limit=200&offset=0"
$GetAvInfo = Invoke-RestMethod -Uri $AvUrl -Method Get -Headers $headers 
  
foreach($i in 0..($GetAvInfo.items.Count-1)){
        #loop through the filer info to get the filer description
        foreach($m in 0..($GetFilerInfo.items.Count-1)){
            $FilerSerial = $GetFilerInfo.items[$m].serial_number
            $FilerDescription = $GetFilerInfo.items[$m].description
            if ($FilerSerial -eq  $GetAvInfo.items[$i].filer_serial_number) {$FilerName = $FilerDescription}
        $m++}

        #loop through the volume info to get the volume description
        foreach($n in 0..($GetVolumeInfo.items.Count-1)){
            $VolumeGuid = $GetVolumeInfo.items[$n].guid
            $VolumeDescription = $GetVolumeInfo.items[$n].name
            if ($VolumeGuid -eq  $GetAvInfo.items[$i].volume_guid) {$VolumeName = $VolumeDescription}
        $n++}

        #set variables to the output from above
        $VolumeGUID = $GetAvInfo.items[$i].volume_guid
        $FilerSerial = $GetAvInfo.items[$i].filer_serial_number
        $VirusName = $GetAvInfo.items[$i].vname
        $VirusPath = $GetAvInfo.items[$i].fpath

        #write the output to a variable
        $datastring = "$VolumeName,$VolumeGUID,$FilerName,$FilerSerial,$VirusName,$VirusPath"
        #write the output to a file
        Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append

        #clear variables for next loop
        $ClearVar = ("VolumeName", "VolumeGUID", "FilerName", "FilerSerial", "VirusName", "VirusPath")
        foreach ($Item in $ClearVar) {
        Get-Variable $Item | Remove-Variable
        }

$i++
}




