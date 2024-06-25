#Export Antivirus Violations to CSV
 
#populate NMC hostname and credentials
$hostname = "insertNMChostname"
  
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"
  
#path to CSV
$reportFile = "c:\export\AntivirusViolationsExport.CSV"

#Number of antivirus violations, NEAs, and volumes to query in lookups
$limit = 1000

#Specify the action to perform (delete_file or ignore_violation)
$action = "ignore_violation" 


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
$csvHeader = "VolumeName,VolumeGUID,FilerName,FilerSerial,VirusName,VirusPath,ViolationID,Status"

if (-not (Test-Path -Path $reportFile)) {
  New-Item -Path $reportFile -ItemType File
  Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
} else {
  Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
}

 
#List NEAs to get NEA names rather than SNs only
$FilersUrl="https://"+$hostname+"/api/v1.1/filers/?limit="+$limit+"&offset=0"
$GetFilerInfo = Invoke-RestMethod -Uri $FilersUrl -Method Get -Headers $headers 
  
#List volumes to get friendly volume names
$VolumeUrl="https://"+$hostname+"/api/v1.1/volumes/?limit="+$limit+"&offset=0"
$GetVolumeInfo = Invoke-RestMethod -Uri $VolumeUrl -Method Get -Headers $headers 

#List AV Violations
$AvUrl="https://"+$hostname+"/api/v1.1/volumes/filers/antivirus-violations/?limit="+$limit+"&offset=0"
$GetAvInfo = Invoke-RestMethod -Uri $AvUrl -Method Get -Headers $headers 



$avViolations = @()  # Initialize an empty hashtable for violations

  
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
        $ViolationID = $GetAvInfo.items[$i].id


        #Process the violation
        $avProcessUrl = "https://"+$hostname+"/api/v1.2/volumes/$VolumeGUID/filers/$FilerSerial/antivirus-violations/$ViolationID/?action=$action"

        #Send request
        $result = Invoke-RestMethod -Uri $avProcessUrl -Method Delete -Headers $headers -ContentType "application/json" -SkipCertificateCheck
        
        #Storing AV violation details to as an object  
        $violation = New-Object PSObject -Property @{
          "VolumeName" = $VolumeName
          "VolumeGUID" = $VolumeGUID
          "FilerName" = $FilerName
          "FilerSerial" = $FilerSerial
          "VirusName" = $VirusName
          "VirusPath" = $VirusPath
          "ViolationID" = $ViolationID
          "messageURL" = $result.message.links.self.href
        }
        
        #Adding the violation to the list to check status updates
        $avViolations += $violation
        

$i++
}

#buffer time to allow NMC to process requests.
write-output "Waiting 5 seconds before checking status"
Start-Sleep -s 5

#Looping through violations and updating their status
foreach ($avObj in $avViolations) {
 
  $getMessage = Invoke-RestMethod -Uri $($avObj.messageURL) -Method Get -Headers $headers
  
  #write the output to a variable
  $datastring = "$($avObj.VolumeName),$($avObj.VolumeGUID),$($avObj.FilerName),$($avObj.FilerSerial),$($avObj.VirusName),$($avObj.VirusPath),$($avObj.ViolationID),$($getMessage.status)"

  #write the output to a file
  Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
  
}
