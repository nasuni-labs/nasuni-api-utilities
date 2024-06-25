# Upload Encryption Key

#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"
 
#specify Nasuni volume guid and filer serial number
$filer_serial = "InsertFilerSerialHere"

#Encryption Key Path
$encyrptionKeyPath = "InsertEncryptionKeyFilePathHere"

#Optional key passphrase
$passphrase = ""


#end variables

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
$headers.Add("Content-Type", 'multipart/form-data')
 
#Read the token from a file and add it to the headers for the request
$token = Get-Content $tokenFile
$headers.Add("Authorization","Token " + $token)

#test to see if a passphrase has been specified
if ([string]::IsNullOrEmpty($passphrase)) {
    Write-Host "Variable is null or empty"
    
    $formData = @{
        key_file = Get-Item -Path $encyrptionKeyPath
        passphrase = $null
    }
}
else {
    
    $formData = @{
        key_file = Get-Item -Path $encyrptionKeyPath
        passphrase = $passphrase
    }
}

#upload the encryption key
$uploadEncryptionKeyUrl = "https://"+$hostname+"/api/v1.2/filers/$filer_serial/encryption-keys/"

# Send the request
$result = Invoke-RestMethod -Uri $uploadEncryptionKeyUrl  -Headers $headers -Method Post -Form $formData -ContentType "multipart/form-data"
write-output $result

write-output "Waiting 10 seconds to check upload status"
Start-Sleep -s 10

#Checking the status of upload
$MessageURL = $result.message.links.self.href
$getMessage = Invoke-RestMethod -Uri $MessageURL -Method Get -Headers $headers

#Adding pending filers to a list and reporting failed statuses
if($getMessage.status -eq "pending"){
    write-output "Pending. Please track upload status from NMC UI-Filer Encryption Keys page."
} 
elseif($getMessage.status -eq "failure"){
   Write-Output "$($getMessage.error.code): $($getMessage.error.description)"
}
else {
    Write-Output "Encryption key successfully uploaded"
}
