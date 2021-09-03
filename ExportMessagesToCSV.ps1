#Get NMC Messages and Export them to CSV
 
#populate NMC hostname and credentials
$hostname = "host.domain.com"
  
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'
  
#path to export CSV
$ReportFilePath = "C:\logs\NMCmessages"

#build export file name
$ReportFileName = "NMCMessages.csv"
$FullPath = $ReportFilePath + "\" + (get-date -f yyyy-MM-dd-HH-mm) + "-" + $ReportFileName

#generate a temp file for the report
$ReportFileTemp = $FullPath + ".tmp"

#set the number of messages to retrieve and offset position
$limit = "1000"
$offset = "0"
  
#Request token and build connection headers

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
  
#construct Uri
$url="https://"+$hostname+"/api/v1.1/auth/login/"
  
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)
 
#initialize csv output file
$csvHeader = "id,filer_serial_number,description,code,status,send_time,expiration_time,response_time,initiated_by,applied_resource_href"
Out-File -FilePath $ReportFileTemp -InputObject $csvHeader -Encoding UTF8
  
#List messages
$MessageInfoURL="https://"+$hostname+"/api/v1.1/messages/?limit="+$limit+"&offset="+$offset

$MessageInfo = Invoke-RestMethod -Uri $MessageInfoURL -Method Get -Headers $headers
  
foreach($i in 0..($MessageInfo.items.Count-1)){
 
       $id = $MessageInfo.items[$i].id
       $filer_serial_number = $MessageInfo.items[$i].filer_serial_number
       $description = $MessageInfo.items[$i].description
       $code = $MessageInfo.items[$i].code
       $status = $MessageInfo.items[$i].status
       $send_time = $MessageInfo.items[$i].send_time
       $expiration_time = $MessageInfo.items[$i].expiration_time
       $response_time = $MessageInfo.items[$i].response_time
       $initiated_by = $MessageInfo.items[$i].initiated_by
       $applied_resource_href = $MessageInfo.items[$i].links.applied_resource.href

       $datastring = "$id,$filer_serial_number,$description,$code,$status,$send_time,$expiration_time,$response_time,$initiated_by,$applied_resource_href"
       #write the results to the CSV
       Out-File -FilePath $reportFileTemp -InputObject $datastring -Encoding UTF8 -append
 
$i++
}

#sort the output by send_time
Import-Csv $ReportFileTemp | sort-object send_time | Export-Csv -Path $FullPath -NoTypeInformation
Remove-Item -Path $ReportFileTemp