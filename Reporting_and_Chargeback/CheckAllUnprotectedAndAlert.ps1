#Check all Volumes and Edge Appliances for Unprotected Data and Send Email Alerts

#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"

#username format - Native account, use the account name. Domain account, use the UPN
$username = "username"
$password = 'password'
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

#number of days to wait on unprotected data growth before alerting
$DayAlertValue = 3

#SendEmailTime accepted values are 1-24, indicating hour to send email
$SendEmailTime = 9

#Email Parameters
$recipients = @("user1@somedomain.com", "user2@somedomain.com")
$from = "alerts@somedomain.com"
$SMTPServer = "mail.somedomain.com"
$Port = "25"
$Subject = "Nasuni Unprotected Data Alert"

#path to CSV file
$ReportFileOrig = "c:\NasuniOutput\UnprotectedAlertOutput.csv"
$ReportFileNew = $ReportFileOrig + ".new"

#Number of Edge Appliances and Volumes to query
$limit = 1000

#record the current time at run time
$Now = Get-Date -UFormat "%m/%d/%Y %R %Z"
$NowHour = Get-Date -Format "HH" $Now

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

#construct Uri for login
$url="https://"+$hostname+"/api/v1.1/auth/login/"

#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)

#List volumes using the NMC API
$VolumeInfoUrl="https://"+$hostname+"/api/v1.1/volumes/?limit="+$limit+"&offset=0"
$GetVolumeInfo = Invoke-RestMethod -Uri $VolumeInfoUrl -Method Get -Headers $headers

#build headers for the files
$csvHeader = "filer_description,filer_serial_number,volume_name,volume_guid,unprotected_data,timestamp"

#Check to see if the Output file from a previous run is present and if not, create it
$PathStatus = Test-Path $ReportFileOrig 
if ($PathStatus -eq $false) {
    Out-File -FilePath $reportFileOrig -InputObject $csvHeader -Encoding UTF8
     #loop through the new content from the NMC API
     Foreach($m in 0..($GetVolumeInfo.items.Count-1)){ 

        #call the list filer specific settings for a volume endpoint
        $VolumeFilerSpecificUrl = "https://"+$hostname+"/api/v1.1/volumes/" + $GetVolumeInfo.items.guid[$m] + "/filers/?limit="+$limit+"&offset=0"
        $VolumeFilerSpecificInfo = Invoke-RestMethod -Uri $VolumeFilerSpecificUrl -Method Get -Headers $headers
        
        #loop through each item in the volume results
           foreach($n in 0..($VolumeFilerSpecificInfo.items.Count-1)){
           #get filer info for the owner and each connected filer
           $FilerUrl = "https://"+$hostname+"/api/v1.1/filers/" + $($VolumeFilerSpecificInfo.items[$n].filer_serial_number) + "/"
           $filerinfo = Invoke-RestMethod -Uri $FilerUrl -Method Get -Headers $headers
           $InitialReport = "$($filerinfo.description),$($filerinfo.serial_number),$($GetVolumeInfo.items.name[$m]),$($GetVolumeInfo.items.guid[$m]),$($VolumeFilerSpecificInfo.items[$n].status.data_not_yet_protected),$Now"
           Out-File -FilePath $ReportFileOrig -InputObject $InitialReport -Encoding UTF8 -append
           $n++
           #Sleep between Get requests to avoid throttling
            Start-Sleep -Milliseconds 200  
           }
        $m++
        #Sleep between Get requests to avoid throttling
        Start-Sleep -Milliseconds 200  
        }
    }

#import from the files
$ReportArrayOrig = import-csv $reportFileOrig

#Build the array for script output
$OutputArray = @()

#write headers to the new output file
Out-File -FilePath $reportFileNew -InputObject $csvHeader -Encoding UTF8

#loop through the content in the imported file
ForEach ($lineOrig in $ReportArrayOrig) {

    #loop through the new content from the NMC API
    Foreach($i in 0..($GetVolumeInfo.items.Count-1)){ 

     #call the list filer specific settings for a volume endpoint
     $VolumeFilerSpecificUrl = "https://"+$hostname+"/api/v1.1/volumes/" + $GetVolumeInfo.items.guid[$i] + "/filers/?limit="+$limit+"&offset=0"
     $VolumeFilerSpecificInfo = Invoke-RestMethod -Uri $VolumeFilerSpecificUrl -Method Get -Headers $headers
     
     #loop through each item in the volume results
        foreach($j in 0..($VolumeFilerSpecificInfo.items.Count-1)){
        #get filer info for the owner and each connected filer
        $FilerUrl = "https://"+$hostname+"/api/v1.1/filers/" + $($VolumeFilerSpecificInfo.items[$j].filer_serial_number) + "/"
        $filerinfo = Invoke-RestMethod -Uri $FilerUrl -Method Get -Headers $headers

            #check to see if the volume_guid and filer_serial_number match
            if (($GetVolumeInfo.items.guid[$i] -eq $lineOrig.volume_guid) -and ($filerinfo.serial_number -eq $lineOrig.filer_serial_number)){
                #check date differential
                $OrigDate   = Get-Date (Get-Date -UFormat "%m/%d/%Y %R %Z" $lineOrig.timestamp)
                $DateDiff = (Get-Date($Now)) - $OrigDate

                    #check to see if unprotected data is greater than zero growing or stable for more than defined days and email - preserve original timestamp
                    if (([int]$VolumeFilerSpecificInfo.items[$j].status.data_not_yet_protected -ge [int]$lineOrig.unprotected_data) -and ([int]$VolumeFilerSpecificInfo.items[$j].status.data_not_yet_protected -gt 0) -and $DateDiff.Days -ge $DayAlertValue) { 
                        $OutputArray += New-Object psobject -Property @{
                            volume_name = $GetVolumeInfo.items.name[$i]
                            volume_guid = $GetVolumeInfo.items.guid[$i]
                            filer_description = $filerinfo.description
                            filer_serial_number = $filerinfo.serial_number
                            unprotected_data = $VolumeFilerSpecificInfo.items[$j].status.data_not_yet_protected
                            timestamp = $lineOrig.timestamp
                        } 
                    }
                    else { #reset timestamp to current if unprotected data is not growing or stable
                        $ReportFileNewContent = "$($GetVolumeInfo.items.name[$i]),$($GetVolumeInfo.items.guid[$i]),$($filerinfo.description),$($filerinfo.serial_number),$($VolumeFilerSpecificInfo.items[$j].status.data_not_yet_protected),$Now"
                        $OutputArray += New-Object psobject -Property @{
                            volume_name = $GetVolumeInfo.items.name[$i]
                            volume_guid = $GetVolumeInfo.items.guid[$i]
                            filer_description = $filerinfo.description
                            filer_serial_number = $filerinfo.serial_number
                            unprotected_data = $VolumeFilerSpecificInfo.items[$j].status.data_not_yet_protected
                            timestamp = $Now
                        } 
                    }
           
            }
        #Sleep between Get requests to avoid throttling
        Start-Sleep -Milliseconds 200     
        $j++
        }
$i++
#Sleep between Get requests to avoid throttling
Start-Sleep -Milliseconds 200   
} }

# write-output the OutputArray to a new log file
foreach($row in @($OutputArray)) {
    $ReportFileNewContent = "$($row.filer_description),$($row.filer_serial_number),$($row.volume_name),$($row.volume_guid),$($row.unprotected_data),$($row.timestamp)"
    Out-File -FilePath $reportFileNew -InputObject $ReportFileNewContent -Encoding UTF8 -append
}

#If it is time to send the daily alert email, build the body and send the email
if ([int]$NowHour -eq [int]$SendEmailTime) {
    #Build the Email Body
    $EmailBody = @()
        foreach($row in @($OutputArray |Where-Object {(Get-Date -UFormat "%m/%d/%Y %R %Z" $_.timestamp) -lt $Now })){
            $emailorder = [ordered]@{
            filer_description = $row.filer_description
            filer_serial_number = $row.filer_serial_number
            volume_name = $row.volume_name
            volume_guid = $row.volume_guid
            unprotected_data = $row.unprotected_data
            timestamp = $row.timestamp
        }
    $EmailBody += New-Object psobject -Property $emailorder
}
 
    if ($EmailBody.Count -ge 1) {
        $Body = $EmailBody
        Send-MailMessage -to $recipients -From $from -Subject $Subject -SmtpServer $SMTPServer -port $Port -Body ($Body | Out-String)
    }
}    

#Clear the Contents of the OutputArray
$OutputArray = $null

#remove the old log file and replace with the new
Remove-Item -Path $ReportFileOrig
Rename-Item -Path $ReportFileNew -NewName $ReportFileOrig