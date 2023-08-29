#Loads the data API token from disk and lists the contents of the supplied directory
    
#populate Edge Appliance hostname
$hostname = "InsertEdgeApplianceHostname"
 
#Path to token input file
$dataTokenFile = "c:\nasuni\dataToken.txt"
  
#path to list - path to list - path is case sensitive and includes the share name followed by the path, separated using forward slashes (/)
$folderPath = 'share1/folder1'
 
#end variables
   
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
   
#Read the encoded credentials from a file and add it to the headers for the request
$encodedCreds = Get-Content $dataTokenFile
$basicAuthValue = "Basic $encodedCreds"
  
$Headers = @{
    Authorization = $basicAuthValue
}
  
#directory listing
#URI for directory listing
$getItemsUri = "https://"+$hostname+"/mobileapi/1/fs/" + $folderPath
  
#list directory - skip 404 errors in case the directory doesn't exist yet -SkipHttpErrorCheck
$getItems = Invoke-RestMethod -Uri $getItemsUri -Method Get -Headers $headers
  
foreach ($item in $getItems.items){
    write-output $item
}
 
#clear headers for authentication
Clear-Variable headers
Clear-Variable getItems
