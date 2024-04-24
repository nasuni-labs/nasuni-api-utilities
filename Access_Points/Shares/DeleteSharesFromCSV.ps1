<# Deletes shares using a CSV for input--use ExportAllSharesToCSV script to generate the CSV and
edit the CSV to remove the lines for shares you want to retain. The CSV input file should only contains the shares to delete.
CSV column order - shareid,Volume_GUID,filer_serial_number,filer_name,share_name #>

#populate NMC hostname or IP address
$hostname = "InsertNMChostname"

<#Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#provide the path to input CSV - all shares listed in the CSV will be deleted
$csvPath = 'c:\nasuni\DeleteShares.csv'

#end variables

#Build connection headers
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

#Begin share deletion
#read the contents of the CSV into variables
$shares = Get-Content $csvPath | Select-Object -Skip 1 | ConvertFrom-Csv -header "shareid","Volume_GUID","Volume_Name","filer_serial_number","filer_name","share_name"

ForEach ($share in $shares) {
    $volume_guid = $($share.Volume_Guid)
    $filer_serial_number = $($share.filer_serial_number)
    $share_id = $($share.shareid)
    $share_name = $($share.share_name)
    $filer_name = $($share.filer_name)
   
    #set up the URL for the delete share NMC endpoint
    $url="https://"+$hostname+"/api/v1.2/volumes/" + $volume_guid + "/filers/" + $filer_serial_number + "/shares/" + $share_id + "/"
    
    #delete the share
    $response=Invoke-RestMethod -Uri $url -Method Delete -Headers $headers

    #write the response of each share deletion request to the console
    $output = "Share Name: " + $share_name + ", Edge Name: " + $filer_name + ", Volume GUID: " + $volume_guid + ", Message Status: " + $response.message.status + ", Message ID: " + $response.message.id
    write-output $output

    #sleep between deleting shares to avoid NMC API throttling
    Start-Sleep -s 1.1
}
