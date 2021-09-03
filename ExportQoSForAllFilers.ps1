#Read and export all QoS settings for NMC-managed filers.

#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#path to Export CSV
$reportFile = "c:\QoSExport.csv"

#end variables

#combine credentials for token request
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

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
$csvHeader = "Filer Name,Filer Serial,Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Start,Stop,Ingress_Limit,Limit"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8

#Get Filers
$FilerInfoURL="https://"+$hostname+"/api/v1.1/filers/"
$GetFilerInfo = Invoke-RestMethod -Uri $FilerInfoUrl -Method Get -Headers $headers

foreach($f in 0..($GetFilerInfo.items.Count-1)){
    $FilerName = $GetFilerInfo.items[$f].description
    $FilerSerial = $GetFilerInfo.items[$f].serial_number
        #only include NMC managed filers--unmanaged filers will cause errors
        if ($GetFilerInfo.items[$f].management_state -eq "nmc") {
            foreach($r in 0..($GetFilerInfo.items[$f].settings.qos.rules.Count-1)){
                $Sun = $GetFilerInfo.items[$f].settings.qos.rules[$r].days.sun
                $Mon = $GetFilerInfo.items[$f].settings.qos.rules[$r].days.mon
                $Tue = $GetFilerInfo.items[$f].settings.qos.rules[$r].days.tue
                $Wed = $GetFilerInfo.items[$f].settings.qos.rules[$r].days.wed
                $Thu = $GetFilerInfo.items[$f].settings.qos.rules[$r].days.thu
                $Fri = $GetFilerInfo.items[$f].settings.qos.rules[$r].days.fri
                $Sat = $GetFilerInfo.items[$f].settings.qos.rules[$r].days.sat
                $Start = $GetFilerInfo.items[$f].settings.qos.rules[$r].start
                $Stop =  $GetFilerInfo.items[$f].settings.qos.rules[$r].stop
                $IngressLimit = $GetFilerInfo.items[$f].settings.qos.rules[$r].ingress_limit
                $Limit = $GetFilerInfo.items[$f].settings.qos.rules[$r].limit
                $datastring = "$FilerName,$FilerSerial,$Sun,$Mon,$Tue,$Wed,$Thu,$Fri,$Sat, $Start,$Stop,$IngressLimit,$Limit"
                Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
            }
        }
}

