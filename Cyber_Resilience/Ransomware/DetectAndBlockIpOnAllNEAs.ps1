<# Reads NMC Notifications to find Ransomware Incidents and block the IP address on all NEAs.
Designed to run as a Windows Scheduled task. Will also need to run the GetToken script as a scheduled task
since NMC API tokens expire after 8 hours. Needs NMC version 23.3+ and NEA 9.14+  #>
 
#populate NMC hostname and credentials
$hostname = "host.domain.com"
  
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#set the number of notifications to return - set at 5000 by default.
$limit = "5000"

#minutes to look back - 5 minutes by default. Match to the frequency of the scheduled task running the script.
$minutesAgo = 5
  
#end variables

#Get the time from the OS and convert to UTC
$scriptUtcTime = Get-Date
$scriptUtcTime = $scriptUtcTime.ToUniversalTime()

#Allow untrusted SSL certs
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
  
#List notifications
$nmcNotificationsURL="https://"+$hostname+"/api/v1.1/notifications/?limit="+$limit+"&offset=0"
$nmcNotifications = Invoke-RestMethod -Uri $nmcNotificationsURL -Method Get -Headers $headers
  
foreach($i in 0..($nmcNotifications.items.Count-1)){
       $date = $nmcNotifications.items[$i].date
       $name = $nmcNotifications.items[$i].name
       $message = $nmcNotifications.items[$i].message -replace ",",";"
      
       if ($name -eq "AR_NEW_ATTACK") {
            #get the date and time for the attack
            $detectionTime = $date -replace 'UTC', '' -replace 'T', '-'
            $detectionTimeAsDate = [datetime]::ParseExact($detectionTime, "yyyy-MM-dd-HH:mm:ss", $null)
            $timeDifference = NEW-TIMESPAN –Start $detectionTimeAsDate –End $scriptUtcTime
            #only look at events that match the minutesAgo query so we can exclude ransomware incidents
            if ($timeDifference.TotalMinutes -le $minutesAgo) {
                write-output "Attack detected at $detectionTimeAsDate UTC."
                #Find the IP Address in the message
                $startParen = $message.IndexOf('(')
                $endParen = $message.IndexOf(')', $startParen)
                $ipAddress = $message.Substring($startParen+1, $endParen - $startParen - 1)
                write-output "Blocking Client IP Address: $ipAddress"
#put IP address into the body for blocking the client$
$body = @"
{
    "ip_address": "$ipAddress"
}
"@
                #Get list of Filers so we can block the IP on each
                $FilerInfoURL="https://"+$hostname+"/api/v1.2/filers/?limit="+$limit+"&offset=0"
                $GetFilerInfo = Invoke-RestMethod -Uri $FilerInfoUrl -Method Get -Headers $headers
                foreach($f in 0..($GetFilerInfo.items.Count-1)){
                    $FilerSerial = $GetFilerInfo.items[$f].serial_number
                        #only include NMC managed filers--unmanaged filers will cause errors
                        if ($GetFilerInfo.items[$f].management_state -eq "nmc") {
                            #set the block client IP URL
                            $blockClientIpUrl="https://"+$hostname+"/api/v1.2/filers/" + $filerSerial + "/blocked-clients/"
                
                            #block the client IP
                            try { $response=Invoke-RestMethod -Uri $blockClientIpUrl -Method Post -Headers $headers -Body $body} catch {Failure}
                            write-output "-on NEA with Serial Number: $($response.message.filer_serial_number)"
                
                            #sleep between requests to avoid throttling
                            Start-Sleep -s 1.1
                        }
                        $f++
                }
            }
       }
 
$i++
}
