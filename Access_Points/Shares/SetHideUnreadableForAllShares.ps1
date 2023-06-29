#Set Hide Unreadable for All Shares
 
#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
<#Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#hide unreadable folders and files - default is "true"
$hide_unreadable = "true"

#Number of Shares to query - edit if more are needed
$limit = 1000

#end variables

#build credentials

#Load token and build connection headers
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

#Build json body for share update
$UpdateBody = @"
{
    "hide_unreadable": "$hide_unreadable"
}
"@
 
#List shares
$FormatEnumerationLimit=-1
$GetShareInfoUrl="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit="+$limit+"&offset=0"
$GetShareInfo = Invoke-RestMethod -Uri $GetShareInfoUrl -Method Get -Headers $headers

#if the script is setting hide unreadable to false-check shares where it is true and only update those
if ($hide_unreadable -eq $false){

	foreach($i in 0..($GetShareInfo.items.Count-1)){
		if ($GetShareInfo.items[$i].hide_unreadable -eq $true){
		#Build the URL for updating shares
		$UpdateShareURL="https://"+$hostname+"/api/v1.1/volumes/" + $($GetShareInfo.items[$i].Volume_Guid) + "/filers/" + $($GetShareInfo.items[$i].filer_serial_number) + "/shares/" + $($GetShareInfo.items[$i].id) + "/"
		$response=Invoke-RestMethod -Uri $UpdateShareURL -Method Patch -Headers $headers -Body $UpdateBody
		write-output $response | ConvertTo-Json -Depth 4
		Start-Sleep -s 1.1
		}

	$i++}
	}

#if the script is setting hide unreadable to true-check shares where it is false and only update those
if ($hide_unreadable -eq $true){

	foreach($i in 0..($GetShareInfo.items.Count-1)){
		if ($GetShareInfo.items[$i].hide_unreadable -eq $false){
		#Build the URL for updating shares
		$UpdateShareURL="https://"+$hostname+"/api/v1.1/volumes/" + $($GetShareInfo.items[$i].Volume_Guid) + "/filers/" + $($GetShareInfo.items[$i].filer_serial_number) + "/shares/" + $($GetShareInfo.items[$i].id) + "/"
		$response=Invoke-RestMethod -Uri $UpdateShareURL -Method Patch -Headers $headers -Body $UpdateBody
		write-output $response | ConvertTo-Json -Depth 4
		Start-Sleep -s 1.1
		}

	$i++}
	}
