#Export Health for all Edge Appliances to CSV
#List health status for all Edge Appliances - http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#list-health-status-for-all-filers

#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
   
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Number of Edge Appliances to return in results
$limit = 300
   
#path to CSV
$reportFile = "c:\export\HealthExport.CSV"
 
#Request token and build connection headers
# Allow untrusted SSL certs - remove if valid NMC SSL cert is installed
if ("TrustAllCertsPolicy" -as [type]) {} else {  
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
}
   
#build JSON headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", 'application/json')
$headers.Add("Content-Type", 'application/json')
 
#Read the token from a file and add it to the headers for the request
$token = Get-Content $tokenFile
$headers.Add("Authorization","Token " + $token)
  
#initialize csv output file
$csvHeader = "filer_serial_number,filer_name,last_updated,network,filesystem,cpu,nfs,memory,services,directoryservices,disk,smb"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8

#List filer info
$FilerInfoUrl="https://"+$hostname+"/api/v1.1/filers/?limit="+$limit+"&offset=0"
$GetFilerInfo = Invoke-RestMethod -Uri $FilerInfoUrl -Method Get -Headers $headers
  
#List the health monitor status for all Edge Appliances
$HealthUrl="https://"+$hostname+"/api/v1.1/filers/health/?limit="+$limit+"&offset=0"
$GetHealthInfo = Invoke-RestMethod -Uri $HealthUrl -Method Get -Headers $headers

   
foreach($i in 0..($GetHealthInfo.items.Count-1)){
        #set variables to the output from above
        $filer_serial_number = $GetHealthInfo.items[$i].filer_serial_number
        $last_updated = $GetHealthInfo.items[$i].last_updated
        $network = $GetHealthInfo.items[$i].network
        $filesystem = $GetHealthInfo.items[$i].filesystem
        $cpu = $GetHealthInfo.items[$i].cpu
        $nfs = $GetHealthInfo.items[$i].nfs
        $memory = $GetHealthInfo.items[$i].memory
        $services = $GetHealthInfo.items[$i].services
        $directoryservices = $GetHealthInfo.items[$i].directoryservices
        $disk = $GetHealthInfo.items[$i].disk
        $smb = $GetHealthInfo.items[$i].smb

            #loop through the filer info to get the filer description
            foreach($m in 0..($GetFilerInfo.items.Count-1)){
            $FilerInfoSerial = $GetFilerInfo.items[$m].serial_number
            $FilerInfoDescription = $GetFilerInfo.items[$m].description
            if ($FilerInfoSerial -eq  $filer_serial_number) {$filer_name = $FilerInfoDescription}
            $m++}

        #write the output to a variable
        $datastring = "$filer_serial_number,$filer_name,$last_updated,$network,$filesystem,$cpu,$nfs,$memory,$services,$directoryservices,$disk,$smb"
        #write the output to a file
        Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
 
        #clear variables for next loop
        $ClearVar = ("filer_serial_number", "filer_name", "last_updated", "network", "filesystem", "cpu", "nfs", "memory", "services", "directoryservices", "disk", "smb")
        foreach ($Item in $ClearVar) {
        Get-Variable $Item | Remove-Variable
        }
$i++
}
