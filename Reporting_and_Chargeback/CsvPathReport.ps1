<# Export all path information for the inputs specified in the CSV to a new CSV output file.
Includes the following info: volume_name,volume_guid,filer_name,filer_serial,path,cache_resident,protected,owner,size,pinning_enabled,
pinning_mode,pinning_inherited,autocache_enabled,autocache_mode,autocache_inherited,quota_enabled,quota_type,quota_email,quota_usage,
quota_limit,quota_inherited,global_locking_enabled,global_locking_inherited,global_locking_mode" #>

#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username@domain.com"
$password = 'password'

#Set Path for CSV Import file
$csvInputPath = "c:\nasuni\PathsToList.csv"

#Set Path for CSV Export
$csvOutputPath = "c:\nasuni\PathReport.csv"

#Number of volumes and filers to query for description lookups
$limit = 1000

#end variables

#combine credentials for token request
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

# Allow untrusted SSL certs - remove if valid NMC ssl cert is installed
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

#construct Uri
$url="https://"+$hostname+"/api/v1.1/auth/login/"
 
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials 
$token = $result.token
$headers.Add("Authorization","Token " + $token)

#read the contents of the input CSV into variables
$inputPaths = Get-Content $csvInputPath | Select-Object -Skip 1 | ConvertFrom-Csv -header "Volume_GUID","filer_serial_number","path"

#initialize csv output file
$csvHeader = "volume_name,volume_guid,filer_name,filer_serial,path,cache_resident,protected,owner,size,pinning_enabled,pinning_mode,pinning_inherited,autocache_enabled,autocache_mode,autocache_inherited,quota_enabled,quota_type,quota_email,quota_usage,quota_limit,quota_inherited,global_locking_enabled,global_locking_inherited,global_locking_mode"

Out-File -FilePath $csvOutputPath -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting Volume Information to: " + $csvOutputPath)

#List filer info
$FilersUrl="https://"+$hostname+"/api/v1.1/filers/?limit="+$limit+"&offset=0"
$GetFilerInfo = Invoke-RestMethod -Uri $FilersUrl -Method Get -Headers $headers 
  
#List volume info
$VolumeUrl="https://"+$hostname+"/api/v1.1/volumes/?limit"+$limit+"&offset=0"
$GetVolumeInfo = Invoke-RestMethod -Uri $VolumeUrl -Method Get -Headers $headers 

foreach($i in 0..($inputPaths.Count-1)){
    	
	#change the the slash direction for use with NMC API input
    $NormalizedPath = $($inputPaths[$i].path).replace("\","/")

    #loop through the filer info to get the filer description
    foreach($m in 0..($GetFilerInfo.items.Count-1)){
        $FilerSerial = $GetFilerInfo.items[$m].serial_number
        $FilerDescription = $GetFilerInfo.items[$m].description
        if ($FilerSerial -eq  $inputPaths[$i].filer_serial_number) {$FilerName = $FilerDescription}
    $m++}
    
    #loop through the volume info to get the volume description
    foreach($n in 0..($GetVolumeInfo.items.Count-1)){
        $VolumeGuid = $GetVolumeInfo.items[$n].guid
        $VolumeDescription = $GetVolumeInfo.items[$n].name
        if ($VolumeGuid -eq  $inputPaths[$i].volume_guid) {$VolumeName = $VolumeDescription}
    $n++}
    
	#Build the URL for the Get Path Info Endpoint
    $GetPathInfoURL="https://"+$hostname+"/api/v1.1/volumes/" + $($inputPaths[$i].Volume_Guid) + "/filers/" + $($inputPaths[$i].filer_serial_number) + "/path" + $NormalizedPath
    write-output $GetPathInfoURL	
    
    #Refresh Stats on the supplied path
    $RefreshStats = Invoke-RestMethod -Uri $GetPathInfoURL -Method POST -Headers $headers
 
    #Sleep to allow time for the refresh stats to complete
    Start-Sleep -s 5
 
	#Get Path Info to get the properties for the path
	$GetPathInfo = Invoke-RestMethod -Uri $GetPathInfoURL -Method Get -Headers $headers

    #Gather all details and write them to the output file
    $datastring =  "$VolumeName,$($inputPaths[$i].volume_guid),$FilerName,$($inputPaths[$i].filer_serial_number),$($inputPaths[$i].path),$($GetPathInfo.cache_resident),$($GetPathInfo.protected),$($GetPathInfo.owner),$($GetPathInfo.size),$($GetPathInfo.pinning_enabled),$($GetPathInfo.pinning_mode),$($GetPathInfo.pinning_inherited),$($GetPathInfo.autocache_enabled),$($GetPathInfo.autocache_mode),$($GetPathInfo.autocache_inherited),$($GetPathInfo.quota_enabled),$($GetPathInfo.quota_type),$($GetPathInfo.quota_email),$($GetPathInfo.quota_usage),$($GetPathInfo.quota_limit),$($GetPathInfo.quota_inherited),$($GetPathInfo.global_locking_enabled),$($GetPathInfo.global_locking_inherited),$($GetPathInfo.global_locking_mode)"
    
	Out-File -FilePath $csvOutputPath -InputObject $datastring -Encoding UTF8 -append
	
	#Sleep before calling the RefreshStats endpoint again
    Start-Sleep -s 1.1

    #clear variables for next loop
    $ClearVar = ("GetPathInfo", "VolumeName", "VolumeGuid", "FilerName", "FilerSerial")
        foreach ($Item in $ClearVar) {
            Get-Variable $Item -ErrorAction SilentlyContinue | Remove-Variable -ErrorAction SilentlyContinue
        }
} 