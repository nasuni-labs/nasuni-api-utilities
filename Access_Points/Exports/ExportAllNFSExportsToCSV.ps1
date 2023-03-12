#Export all NFS exports to CSV

#populate NMC hostname and credentials
$hostname = "InsertNMChostname"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required). Nasuni Native user accounts are also supported.
$username = "InsertUsername"
$password = 'InsertPassword'

#Path for CSV Export
$reportFile = "c:\export\ExportedNFSExports.csv"

#Number of exports to return
$limit = 1000

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

#construct Uri
$url="https://"+$hostname+"/api/v1.1/auth/login/"
 
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)

#Connect to the List all exports for filer NMC API endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/filers/exports/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#initialize csv output file
$csvHeader = "exportId,Volume_GUID,filer_serial_number,export_name,path,comment,readonly,allowed_hosts,access_mode,perf_mode,sec_options,nfs_host_options"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting NFS Exports Information to: " + $reportFile)

foreach($i in 0..($getinfo.items.Count-1)){
    clear-variable nhoOutput -ErrorAction SilentlyContinue
    $exportId = $getinfo.items[$i].id
    $Volume_GUID = $getinfo.items[$i].Volume_Guid
    $filer_serial_number = $getinfo.items[$i].Filer_Serial_Number
    $export_name = $getinfo.items[$i].name
    $path = $getinfo.items[$i].path
    $comment = $getinfo.items[$i].comment
    $readonly = $getinfo.items[$i].readonly
    $allowed_hosts = $getinfo.items[$i].hostspec -replace ",",";"
    $access_mode = $getinfo.items[$i].access_mode
    $perf_mode = $getinfo.items[$i].perf_mode
    $sec_options = $getinfo.items[$i].sec_options
    $nfs_host_options = $getinfo.items[$i].nfs_host_options
    #loop through host options since it can contain multiple values
    ForEach ($nho in $nfs_host_options) {
        $nhoOutput = $nhoOutput + "allowed_hosts: " + ($nho.hostspec -replace ",",";") + "; access_mode: " + $nho.access_mode + "; read_ondly: " + $nho.readonly + "; sec_options: " + $nho.sec_options + "; perf_mode: " + $nho.perf_mode + ";; "
    }

    $datastring = "$exportID,$Volume_Guid,$Filer_Serial_Number,$export_name,$path,$comment,$readonly,$allowed_hosts,$access_mode,$perf_mode,$sec_options,$nhoOutput"
	Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
	$i++
} 
