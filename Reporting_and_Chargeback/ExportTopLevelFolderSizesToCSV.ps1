<# Get the size of top level folders within one share using the NMC API and export the results to CSV.
Uses the Edge Appliance Data API to provide the list of top level folders within a share - assumes all shares are connected to the Edge Appliance specified in the script
Shares to query for Top Level folders need to have the 'Sync and Mobile Access' share-level Advanced Setting enabled. Leave this off for other shares. #>

#populate NMC hostname and credentials
$nmcHostname = "insertNMChostnameHere"
 
<# NMC API username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ).
Nasuni Native user accounts are also supported. #>
$nmcUsername = "username@domain.com"
$nmcPassword = 'password'

#populate Edge Appliance hostname or IP address for the Data API
$dataHostname = "insertEdgeApplianceHostnameHere"

<# Authenticate to get a Data API token
username for AD accounts supports both UPN (user@domain.com) and DOMAIN\samaccountname formats. Nasuni Native user accounts are also supported.
the account used for the data API must have the ability to login/access the data using the SMB protocol #>
$dataUsername = 'username@domain.com'
$dataPassword = 'password'

#Top Level Folder Name - do not include slashes
$topLevelFolder = 'folderName'

#Path for CSV Size Report
$reportFile = "c:\FolderSize.csv"

#Number of NMC shares to list - increase if necessary
$limit = 5000

#specify device ID and type for Data API authentication - should not need to change
$deviceID = "device01"
$deviceType = "linux"

#end variables

#initialize csv output file
$csvHeader = "volume_guid,filer_serial_number,path,size"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting Top Level Folder Size Information to: " + $reportFile)
 
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
 
#Get Shares from the NMC API
#build the cred for authentication
$nmcCredentials = '{"username":"' + $nmcUsername + '","password":"' + $nmcPassword + '"}'

#build JSON headers
$nmcHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$nmcHeaders.Add("Accept", 'application/json')
$nmcHeaders.Add("Content-Type", 'application/json')

#construct Uri
$nmcLoginUrl="https://"+$nmcHostname+"/api/v1.1/auth/login/"
 
#Use credentials to request and store a session token from NMC for later use
$nmcResult = Invoke-RestMethod -Uri $nmcLoginurl -Method Post -Headers $nmcHeaders -Body $nmcCredentials
$nmcToken = $nmcResult.token
$nmcHeaders.Add("Authorization","Token " + $nmcToken)

#build Form values for Data API authentication
$Form = [ordered]@{
    username = $dataUsername
    password = $dataPassword
    device_id = $deviceID
    device_type = $deviceType
}

#login the Data API and get token

#construct Uri for Data API login
$dataLoginUrl="https://"+$dataHostname+"/mobileapi/1/auth/login"

#Use body to request and store the secret key from the Data API for later use
$response = Invoke-WebRequest -Uri $dataLoginUrl -Method Post -Form $Form -SkipCertificateCheck
$xSecretKey = $response.headers.'X-Secret-Key'
$pair = "$($deviceID):$($xSecretKey)"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$basicAuthValue = "Basic $encodedCreds"

$dataHeaders = @{
    Authorization = $basicAuthValue
}

#Connect to the List all shares for filer NMC API endpoint
$nmcGetSharesUrl="https://"+$nmcHostname+"/api/v1.1/volumes/filers/shares/?limit=" + $limit+ "&offset=0"
$FormatEnumerationLimit=-1

$nmcGetShares = Invoke-RestMethod -Uri $nmcGetSharesUrl -Method Get -Headers $nmcHeaders

#URI for share listing using the Data API
$dataListSharesUri = "https://"+$dataHostname+"/mobileapi/1/fs/"
$dataListShares = Invoke-RestMethod -Uri $dataListSharesUri -Method Get -Headers $dataHeaders -SkipCertificateCheck -SkipHttpErrorCheck

# loop through the share list from the NMC API
foreach($i in 0..($nmcGetShares.items.Count-1)){
    $nmcShareName = $nmcGetShares.items[$i].name
    $nmcSharePath = $nmcGetShares.items[$i].path
    $nmcSharePathFixed = $nmcSharePath.replace('\','/')
    $nmcShareFilerSerial = $nmcGetShares.items[$i].filer_serial_number
    $nmcShareVolumeGuid = $nmcGetShares.items[$i].volume_guid
    $nmcShareMobileEnabled = $nmcGetShares.items[$i].mobile

    if ($nmcShareMobileEnabled -eq "True") {
    # loop through the share list from the data API
    foreach($j in 0..($dataListShares.items.Count-1)){
        $dataShareName = $dataListShares.items[$j].name
            #loop through the data share list to find the corresponding NMC share name for the loop we are running in
            if ($dataShareName -like $nmcShareName) {
                #get the top level folders in each share using the data API

                #build path for getting share properties using the data API, including the top level folder name
                $dataGetShareUri = "https://"+$dataHostname+"/mobileapi/1/fs/" + $dataShareName + "/" + $topLevelFolder + "/"
                #get the individual share information using the data API
                $dataGetShare = Invoke-RestMethod -Uri $dataGetShareUri -Method Get -Headers $dataHeaders -SkipCertificateCheck -SkipHttpErrorCheck
                
                #loop through the results to get a listing of top level folders
                foreach ($dataShare in $dataGetShare.items){
                    #Only include folders in the comparison
                    if ($dataShare.type -eq "directory") {
                    $dataFolder = $dataShare.name
                    
                        #now we need to loop through the folders to get their size using the NMC API

                        #Build the URL for the endpoints
                        $nmcPathInfoURL="https://"+$nmcHostname+"/api/v1.1/volumes/" + $nmcShareVolumeGuid + "/filers/" + "$nmcShareFilerSerial" + "/path" + $nmcSharePathFixed + '/' + $topLevelFolder + '/' + $dataFolder
                        write-output $nmcPathInfoURL

                        #Refresh Stats on the supplied path - calling as a variable to suppress output
                        $nmcPathRefresh=Invoke-RestMethod -Uri $nmcPathInfoURL -Method POST -Headers $nmcHeaders
                        
                        #sleep to allow time for the refresh to complete
                        Start-Sleep -s 5
                        
                        #Get Path Info
                        $nmcGetPathInfo = Invoke-RestMethod -Uri $nmcPathInfoURL -Method Get -Headers $nmcHeaders
                        $reportVolumeGuid = $nmcGetPathInfo.volume_guid
                        $reportFilerSerial = $nmcGetPathInfo.filer_serial_number
                        $reportPath = $nmcGetPathInfo.Path
                        $reportSize = $nmcGetPathInfo.size

                        #write folder size information to the CSV
                        $datastring = "$reportVolumeGuid,$reportFilerSerial,$reportPath,$reportSize"
                        Out-File -FilePath $reportFile -InputObject $datastring -Encoding UTF8 -append
                    }
                }
            }
        $j++
    }}
    $i++
}







    

