#Get the size of subfolders within a path using the NMC API and export the results to CSV.
#Uses the Edge Appliance Data API to provide the list of subfolders within a path
#The 'Sync and Mobile Access' share-level Advanced Setting must be enabled for the Data API to work

#populate NMC hostname and credentials
$nmcHostname = "insertNMChostnameHere"
 
#NMC API username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$nmcUsername = "username@domain.com"
$nmcPassword = 'password'

#populate Edge Appliance hostname or IP address for the Data API
$dataHostname = "insertEdgeApplianceHostnameHere"

#Authenticate to get a Data API token
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\samaccountname formats.
#the account used for the data API must have NTFS permissions to list the folder names
$dataUsername = 'username@domain.com'
$dataPassword = 'password'

#Volume GUID
$volumeGuid = 'InsertVolumeGuid'

#Filer Serial
$filerSerial = 'InsertFilerSerial'

#Path to the Folder containing the subfolders to list (do not add a trailing slash to the end)
$nmcFolderPath = '/folder/folder1'

#Name of Share containing the folder path - we need the share name for the data api call that lists subfolders
$shareName = 'InsertShareName'

#Path for CSV Size Report
$reportFile = "c:\subfolderSize.csv"

#specify device ID and type for Data API authentication - should not need to change
$deviceID = "device01"
$deviceType = "linux"

#end variables

#initialize csv output file
$csvHeader = "volume_guid,filer_serial_number,path,size"
Out-File -FilePath $reportFile -InputObject $csvHeader -Encoding UTF8
write-host ("Exporting Subfolder Size Information to: " + $reportFile)
 
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
 
#build the cred for NMC authentication
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

#login to the Data API and get token

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

#Get the share information from the NMC so that we can retrieve the path for the share since the share name and the path can be different
$nmcGetSharesURL = "https://"+$nmcHostname+"/api/v1.1/volumes/" + $VolumeGuid + "/filers/" + "$filerSerial" + "/shares/"
$nmcGetShares = Invoke-RestMethod -Uri $nmcGetSharesURL -Method Get -Headers $nmcHeaders

# loop through the share list from the NMC API
foreach($i in 0..($nmcGetShares.items.Count-1)){
    $nmcShareName = $nmcGetShares.items[$i].name
    #when we find the share name, save the associated path
    if ($shareName -like $nmcShareName) {
        $nmcSharePath = $nmcGetShares.items[$i].path
        #normalize the slashes
        $nmcSharePathFixed = $nmcSharePath.replace('\','/')
    }
    $i++
}

#compare paths from the Volume and share path to find the correct portion to pass to the data api
$dataRelativePath = $nmcFolderPath.substring($nmcSharePathFixed.length)

#build path for getting share properties using the data API, 
$dataGetShareUri = "https://"+$dataHostname+"/mobileapi/1/fs/" + $ShareName + $dataRelativePath + "/"

#get the individual share information using the data API
$dataGetShare = Invoke-RestMethod -Uri $dataGetShareUri -Method Get -Headers $dataHeaders -SkipCertificateCheck -SkipHttpErrorCheck
                
    #loop through the results to get a listing of subfolders
    foreach ($dataShare in $dataGetShare.items){
        #Only include folders in the comparison
        if ($dataShare.type -eq "directory") {
        $dataFolder = $dataShare.name
        
            #now we need to loop through the folders to get their size using the NMC API

            #Build the URL for the endpoints
            $nmcPathInfoURL="https://"+$nmcHostname+"/api/v1.1/volumes/" + $VolumeGuid + "/filers/" + "$filerSerial" + "/path" + $nmcFolderPath +'/' + $dataFolder
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







    
