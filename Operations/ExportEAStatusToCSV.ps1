#Export All Edge Appliance Info to CSV
#Uses the list Edge Appliances NMC API endpoint - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#list-filers

#populate NMC hostname and credentials
$hostname = "host.domain.com"
   
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

#Number of Edge Appliances to return in results
$limit = 300
   
#path to Report CSV
$reportFile = "c:\export\ExportEAStatus.csv"
 
#Request token and build connection headers
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
  
#initialize csv output file
$csvHeader = "Description,SerialNumber,GUID,build,cpuCores,cpuModel,cpuFrequency,cpuSockets,Memory,ManagementState,Offline,OsVersion,Uptime,UpdatesAvailable,CurrentVersion,NewVersion,PlatformName,cacheSize,cacheUsed,cacheDirty,cacheFree,cachePercentUsed"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8

#List filer info
$FilerInfoUrl="https://"+$hostname+"/api/v1.1/filers/?limit="+$limit+"&offset=0"
$GetFilerInfo = Invoke-RestMethod -Uri $FilerInfoUrl -Method Get -Headers $headers
   
foreach($i in 0..($GetFilerInfo.items.Count-1)){
        #set variables to the output from above
        $Description = $GetFilerInfo.items[$i].description
        $SerialNumber = $GetFilerInfo.items[$i].serial_number
        $GUID = $GetFilerInfo.items[$i].guid
        $build = $GetFilerInfo.items[$i].build
        $cpuCores = $GetFilerInfo.items[$i].status.platform.cpu.cores
        $cpuModel = $GetFilerInfo.items[$i].status.platform.cpu.model
        $cpuFrequency = $GetFilerInfo.items[$i].status.platform.cpu.frequency
        $cpuSockets = $GetFilerInfo.items[$i].status.platform.cpu.sockets
        $Memory = $GetFilerInfo.items[$i].status.platform.memory
        $ManagementState = $GetFilerInfo.items[$i].management_state
        $Offline = $GetFilerInfo.items[$i].status.offline
        $OsVersion = $GetFilerInfo.items[$i].status.osversion
        $Uptime = $GetFilerInfo.items[$i].status.uptime
        $UpdatesAvailable = $GetFilerInfo.items[$i].status.updates_available
        $CurrentVersion = $GetFilerInfo.items[$i].status.current_version
        $NewVersion = $GetFilerInfo.items[$i].status.new_version
        $PlatformName = $GetFilerInfo.items[$i].status.platform.platform_name
        $cacheSize = $GetFilerInfo.items[$i].status.platform.cache_status.size
        $cacheUsed = $GetFilerInfo.items[$i].status.platform.cache_status.used
        $cacheDirty = $GetFilerInfo.items[$i].status.platform.cache_status.dirty
        $cacheFree = $GetFilerInfo.items[$i].status.platform.cache_status.free
        $cachePercentUsed = $GetFilerInfo.items[$i].status.platform.cache_status.percent_used
      
        #write the output to a variable
        $datastring = "$Description,$SerialNumber,$GUID,$build,$cpuCores,$cpuModel,$cpuFrequency,$cpuSockets,$Memory,$ManagementState,$Offline,$OsVersion,$Uptime,$UpdatesAvailable,$CurrentVersion,$NewVersion,$PlatformName,$cacheSize,$cacheUsed,$cacheDirty,$cacheFree,$cachePercentUsed"
        #write the output to a file
        Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
 
        #clear variables for next loop
        $ClearVar = ("Description", "SerialNumber", "GUID", "build", "cpuCores", "cpuModel", "cpuFrequency", "cpuSockets", "Memory", "ManagementState", "Offline", "OsVersion", "Uptime", "UpdatesAvailable", "CurrentVersion", "NewVersion", "PlatformName", "cacheSize", "cacheUsed", "cacheDirty", "CacheFree", "CachePercentUsed")
        foreach ($Item in $ClearVar) {
        Get-Variable $Item | Remove-Variable
        }
$i++
}