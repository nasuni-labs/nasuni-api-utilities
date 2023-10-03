<# Send Email if unprotected data for the specified volume exceeds a configured threshold
example in batch/scheduled task - powershell.exe -executionpolicy bypass -command "C:\scripts\VolumeUnprotectedDataAlert.ps1" #>

#populate NMC hostname and credentials
$hostname = "host.domain.com"
  
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#specify Nasuni volume guid
$volume_guid = "InsertVolumeGuidHere"

#Alert Threshold for Unprotected Data in Bytes (20GB = 21474836480)
$AlertBytes = 21474836480

#end variables

#combine credentials for token request
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

#Request token and build connection headers
# Allow untrusted SSL certs
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

#List filers specific settings of a volume
$FormatEnumerationLimit=-1
$url="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/?limit=100&amp;offset=0"

$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#build the array
$OutputArray = @()
foreach($i in 0..($getinfo.items.Count-1)){
    $filerurl = "https://"+$hostname+"/api/v1.1/filers/" + $getinfo.items.filer_serial_number[$i] + "/"
    $filerinfo = Invoke-RestMethod -Uri $filerurl -Method Get -Headers $headers
    $OutputArray += New-Object psobject -Property @{
                        FilerName = $filerinfo.description
                        UnprotectedData = $getinfo.items.status.data_not_yet_protected[$i]
                        }  
    #sleep to avoid NMC API throttling
    Start-Sleep -s 1.1
    $i++
} 
#write-output $FinalResult
$EmailBody = @()
foreach($row in @($OutputArray |Where-Object {$_.UnprotectedData -ge $AlertBytes })){
    $emailorder = [ordered]@{
    FilerName = $row.FilerName
    UnprotectedData = $row.UnprotectedData
    }
    $EmailBody += New-Object psobject -Property $emailorder
}


if ($EmailBody.Count -ge 1) {
    $recipients = @("user1@somedomain.com", "user2@somedomain.com")
    $from = "alerts@somedomain.com"
    $SMTPServer = "mail.somedoamin.com"
    $Port = "25"
    $Subject = "Nasuni Unprotected Data Alert"
    $Body = $EmailBody
    Send-MailMessage -to $recipients -From $from -Subject $Subject -SmtpServer $SMTPServer -port $Port -Body ($body | Out-String)
}

