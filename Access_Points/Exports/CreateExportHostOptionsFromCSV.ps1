#Create Nasuni NFS Host Options from a CSV
#CSV column order - filer_serial_number,export_name,readonly,allowed_hosts,access_mode,perf_mode,sec_options

#populate NMC hostname and credentials
$hostname = "InsertNMChostname"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#provide the path to input CSV
$csvPath = 'c:\import\NfsHostOptions.csv'

#Number of exports to return when listing to get IDs
$limit = 1000

#end variables
#build credentials for later use
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

#List NFS Exports to find the matching ID
#Connect to the List all exports for filer NMC API endpoint
$getExportsUrl="https://"+$hostname+"/api/v1.1/volumes/filers/exports/?limit=" + $limit + "&offset=0"
$FormatEnumerationLimit=-1
$Exports = Invoke-RestMethod -Uri $getExportsUrl -Method Get -Headers $headers

#Begin Host Objects Creation

#read the contents of the CSV into variables
$hostOptions = Get-Content $csvPath | Select-Object -Skip 1 | ConvertFrom-Csv -header "filer_serial_number","export_name","readonly","allowed_hosts","access_mode","perf_mode","sec_options"
 
#Create the hostOption


ForEach ($hostOption in $hostOptions) {
    $filer_serial_number = $($hostOption.filer_serial_number)
    $export_name = $($hostOption.export_name)
    $readonly = $($hostOption.readonly)
    $allowed_hosts = $($hostOption.allowed_hosts)
    $access_mode = $($hostOption.access_mode)
    $perf_mode = $($hostOption.perf_mode)
    $sec_options = $($hostOption.sec_options)
 
#body for hostOption create
$body = @"
{
    "readonly": "$readonly",
    "hostspec": "$allowed_hosts",
    "access_mode": "$access_mode",
    "perf_mode": "$perf_mode",
	"sec_options": [
        "$sec_options"
    ]
}
"@

    #find the matching export ID
    ForEach ($i in 0..($Exports.items.Count-1)){
        $matchFilerSN = $Exports.items[$i].Filer_Serial_Number
        $matchExportName = $Exports.items[$i].name
        if (($matchFilerSN -eq $filer_serial_number) -and ($matchExportName -eq $export_name)) {
            $export_id = $Exports.items[$i].ID
            $volume_guid = $Exports.items[$i].volume_guid
            #exit since once we have found the ID
            break
        }
        $i++
    }


    #set the create hostOption URL
    $createhostOptionUrl="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial_number + "/exports/" + $export_id + "/nfs_host_options/"

    #create the hostOption
    $response =Invoke-RestMethod -Uri $createhostOptionUrl -Method Post -Headers $headers -Body $body

    #write the response of each hostOption creation request to the console
    $output = "Filer Serial:" + $filer_serial + ", Export Name:" + $export_name + ", Allowed Hosts:" + $allowed_hosts + ", Security Options: " + $sec_options + ", Read Only: " + $readonly + ", Message Status: " + $response.message.status + ", Message ID: " + $response.message.id
    write-output $output

    #sleep between creating hostOptions to avoid NMC API throttling
    Start-Sleep -s 1.1

    #clear ID
    Clear-Variable $export_id -ErrorAction SilentlyContinue
    Clear-Variable $Volume_Guid -ErrorAction SilentlyContinue
}