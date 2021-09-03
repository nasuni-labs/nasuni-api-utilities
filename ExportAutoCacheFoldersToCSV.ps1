#Export Auto Cache Folders to CSV

#populate NMC hostname and credentials
$hostname = "insertHostname"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#Path for CSV Export
$reportFile = "c:\export\ACfolders.csv"

#Number of Auto Cache to return
$limit = 1000

#end variables

#build credentials
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

#construct Uri
$url="https://"+$hostname+"/api/v1.1/auth/login/"
 
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)

#List Auto Cache Folders NMC API endpoint
$ACFoldersUrl="https://"+$hostname+"/api/v1.1/volumes/filers/auto-cached-folders/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$GetACFolders = Invoke-RestMethod -Uri $ACFoldersUrl -Method Get -Headers $headers

#initialize Auto Cache CSV output file
$csvHeader = "volume_guid,filer_serial_number,path,autocache mode"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting Auto Cache Folder information to: " + $reportFile)

foreach($i in 0..($GetACFolders.items.Count-1)){
	$VolumeGuid = $GetACFolders.items[$i].volume_guid
	$FilerSerial = $GetACFolders.items[$i].filer_serial_number
	$Path = $GetACFolders.items[$i].path
	$Mode = $GetACFolders.items[$i].mode
	$datastring = "$VolumeGuid,$FilerSerial,$Path,$Mode"
	Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
} 