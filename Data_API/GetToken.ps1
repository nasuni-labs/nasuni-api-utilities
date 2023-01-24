#Request a Nasuni Data API token and store the output in the the specified file
    
#populate Edge Appliance hostname
$hostname = "InsertEdgeApplianceHostname"
   
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\samaccountname formats.
$username = "InsertUsername"
$password = 'InsertPassword'
 
#Path to token output file
$dataTokenFile = "c:\nasuni\dataToken.txt"
 
#specify device ID and type for authentication
$deviceID = "unique01"
$deviceType = "linux"
 
#end variables
   
#Request token and build connection headers
#Allow untrusted SSL certs
if ($PSVersionTable.PSEdition -eq 'Core') #PowerShell Core
{
    if ($PSDefaultParameterValues.Contains('Invoke-WebRequest:SkipCertificateCheck')) {}
    else {
        $PSDefaultParameterValues.Add('Invoke-WebRequest:SkipCertificateCheck', $true)
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
$headers.Add("username", $username)
$headers.Add("password", $password)
$headers.Add("device_id", $deviceID)
$headers.Add("device_type", $deviceType)
    
#construct Uri
$url="https://"+$hostname+"/mobileapi/1/auth/login"
     
#Use body to request and store a session token from the Nasuni Data API for later use
$result = Invoke-WebRequest -Uri $url -Method Post -Body $headers
$dataToken= $result.Headers.'X-Secret-Key'
 
#write the token to the console to verify script ouput
write-output "Obtained token: $dataToken "
 
#combine the token with device ID and encode before saving for re-use
$pair = "$($deviceID):$($dataToken)"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
 
#write the updated token to a file
Set-Content $dataTokenFile $encodedCreds
 
#clear headers for authentication
Clear-Variable headers
