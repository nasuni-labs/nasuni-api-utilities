#Get NMC Notifications and Export them to CSV
 
#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
  
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Path to Export Files
$ReportFileName = "c:\export\NMCMessages.csv"

#set the number of notifications to return
$limit = "1000"
  
#end variables

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
 
#Initialize CSV output file
$csvHeader = "id,date,priority,name,message,group,acknowledged,sticky,urgent,origin"
Out-File -FilePath $ReportFileName -InputObject $csvHeader -Encoding UTF8
  
#List notifications
$nmcNotificationsURL="https://"+$hostname+"/api/v1.1/notifications/?limit="+$limit+"&offset=0"

$nmcNotifications = Invoke-RestMethod -Uri $nmcNotificationsURL -Method Get -Headers $headers
  
foreach($i in 0..($nmcNotifications.items.Count-1)){
       $id = $nmcNotifications.items[$i].id
       $date = $nmcNotifications.items[$i].date
       $priority = $nmcNotifications.items[$i].priority
       $name = $nmcNotifications.items[$i].name
       $message = $nmcNotifications.items[$i].message -replace ",",";"
       $group = $nmcNotifications.items[$i].group
       $acknowledged = $nmcNotifications.items[$i].acknowledged
       $sticky = $nmcNotifications.items[$i].sticky
       $urgent = $nmcNotifications.items[$i].urgent
       $origin = $nmcNotifications.items[$i].origin
      
       $datastring = "$id,$date,$priority,$name,$message,$group,$acknowledged,$sticky,$urgent,$origin"
       #write the results to the CSV
       Out-File -FilePath $ReportFileName -InputObject $datastring -Encoding UTF8 -append
 
$i++
}
