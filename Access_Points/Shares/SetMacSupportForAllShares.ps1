#Set enhanced support for Mac clients (vfs_fruit) to all shares
 
#populate NMC hostname and credentials
$hostname = "host.domain.com"
  
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Enable Mac Support - set to True to enable Mac Support; False to disable
$FruitEnabled = "True"

#Number of Shares to query - edit if more are needed
$limit = 1000

#end variables

#Connect to the List all shares for filer NMC API endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit="+$limit+"&offset=0"

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
    "fruit_enabled": "$FruitEnabled"
}
"@
 
#List volumes
$FormatEnumerationLimit=-1
$GetShareInfoUrl="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit="+$limit+"&offset=0"
$GetShareInfo = Invoke-RestMethod -Uri $GetShareInfoUrl -Method Get -Headers $headers

#if the script is Fruit Enabled to true-check shares where it is false and only update those
if ($FruitEnabled -eq $true){
 
    foreach($i in 0..($GetShareInfo.items.Count-1)){
        #loop through shares to find shares without fruit enabled and set fruit enabled to true
        #Build the URL for updating shares
        if ($GetShareInfo.items[$i].fruit_enabled -eq $false){
        $UpdateShareURL="https://"+$hostname+"/api/v1.1/volumes/" + $($GetShareInfo.items[$i].Volume_Guid) + "/filers/" + $($GetShareInfo.items[$i].filer_serial_number) + "/shares/" + $($GetShareInfo.items[$i].id) + "/"
        $response=Invoke-RestMethod -Uri $UpdateShareURL -Method Patch -Headers $headers -Body $UpdateBody
        write-output $response | ConvertTo-Json
        Start-Sleep 1.1
        }

    $i++}
}

#if the script is Fruit Enabled to false-check shares where it is true and only update those
if ($FruitEnabled -eq $false){
 
    foreach($i in 0..($GetShareInfo.items.Count-1)){
        #loop through shares to find shares without fruit enabled and set fruit enabled to true
        #Build the URL for updating shares
        if ($GetShareInfo.items[$i].fruit_enabled -eq $true){
        $UpdateShareURL="https://"+$hostname+"/api/v1.1/volumes/" + $($GetShareInfo.items[$i].Volume_Guid) + "/filers/" + $($GetShareInfo.items[$i].filer_serial_number) + "/shares/" + $($GetShareInfo.items[$i].id) + "/"
        $response=Invoke-RestMethod -Uri $UpdateShareURL -Method Patch -Headers $headers -Body $UpdateBody
        write-output $response | ConvertTo-Json
        Start-Sleep 1.1
        }

    $i++}
}
