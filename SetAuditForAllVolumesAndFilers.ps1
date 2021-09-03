#Enable Auditing and settings for all Volumes and Edge Appliances in an Account.

#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#Number of Edge Appliances and Volumes to query
$limit = 1000
  
#Set Audit Parameters
#Enable Auditing - True/False
$AuditingEnabled = "False"
#audit create events - True/False
$EventsCreate = "False"
#audit delete events - True/False
$EventsDelete = "False"
#audit rename events - True/False
$EventsRename = "False"
#audit close events - True/False
$EventsClose = "False"
#audit security events - True/False
$EventsSecurity = "False"
#audit metadata events - True/False
$EventsMetadata = "False"
#audit write events - True/False
$EventsWrite = "False"
#audit read events - True/False
$EventsRead = "False"
#enable audit log pruning - True/False
$PruneAuditLogs = "False"
#days to keep before pruning - Number
$DaysToKeep = "90"
#export audit events via Syslog - True/False
$SyslogExport = "False"

#end variables

#combine credentials for token request
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

#Request token and build connection headers
# Allow untrusted SSL certs - remove if valid SSL cert is loaded for NMC
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
  
#construct Uri for authentication
$url="https://"+$hostname+"/api/v1.1/auth/login/"
   
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)
  
#Configure Auditing
$url="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial + "/"
  
#body for share create - populated by variables
$body = @"
{
    "auditing": {
        "enabled": "$AuditingEnabled",
        "events": { 
            "create": "$EventsCreate",
            "delete": "$EventsDelete",
            "rename": "$EventsRename",
            "close": "$EventsClose",
            "security": "$EventsSecurity",
            "metadata": "$EventsMetadata",
            "write": "$EventsWrite",
            "read": "$EventsRead"
            },
        "logs": {
            "prune_audit_logs": "$PruneAuditLogs",
            "days_to_keep": "$DaysToKeep"
            },
        "syslog_export": "$SyslogExport"
        }
 
}
"@

#List filers
$FilersUrl="https://"+$hostname+"/api/v1.1/filers/?limit="+$limit+"&offset=0"
$GetFilerInfo = Invoke-RestMethod -Uri $FilersUrl -Method Get -Headers $headers

#Pause to avoid NMC API throttling
start-sleep 1.1

#List volumes
$url="https://"+$hostname+"/api/v1.1/volumes/?limit="+$limit+"&offset=0"
$GetVolumeInfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#This loop looks at each volume returned from the volumes endpoint
foreach($i in 0..($GetVolumeInfo.items.Count-1)){
 
     #Get Filer Settings for each volume
     $GetVolumeFilerUrl = "https://"+$hostname+"/api/v1.1/volumes/" + $GetVolumeInfo.items.guid[$i] + "/filers/?limit="+$limit+"&offset=0"
     $GetVolumeFilerInfo = Invoke-RestMethod -Uri $GetVolumeFilerUrl -Method Get -Headers $headers

           #loop through the filer info to get the filer status and skip if offline
           foreach($q in 0..($GetVolumeFilerInfo.items.Count-1)){
                #get a list of filers connected to the volume
                foreach($m in 0..($GetFilerInfo.items.Count-1)){
      
                if (($($GetVolumeFilerInfo.items[$q].filer_serial_number) -eq  $($GetFilerInfo.items[$m].serial_number)) -and ($($GetFilerInfo.items[$m].status.offline) -eq $false ) ){ 
                    $VolumeGuid = $GetVolumeInfo.items[$i].guid
                    $FilerSerial = $($GetFilerInfo.items[$m].serial_number)
                    $SetAuditURL = "https://"+$hostname+"/api/v1.1/volumes/" + $VolumeGuid + "/filers/" + $FilerSerial + "/"
                    #set auditing for each volume and filer
                    $response=Invoke-RestMethod -Uri $SetAuditUrl -Method Patch -Headers $headers -Body $body
                    write-output $response | ConvertTo-Json
                    #Pause to avoid NMC API throttling
                    start-sleep 1.1
                }
                $m++}
            $q++}
}