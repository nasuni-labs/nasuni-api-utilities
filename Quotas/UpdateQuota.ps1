#Update the quota for an existing Path. Lists all quotas in place and finds the matching quota ID for the specified path
#and uses that as a reference to update the quota.
#See http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#update-folder-quota for reference

#populate NMC hostname
$hostname = "host.domain.com"

# username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ).
# Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

#Specify the path to the quota folder. The path should start with a "/" and is the path as displayed in the file browser.
$FolderPath = "/insert/path/here"

#Use this as the new quota (specified in KB)
$NewQuota = "InsertAmountHere"

#Number of Quota entries to query. Should be greater than the number of configured quotas
$limit = 1000

#Request token and build connection headers
# Allow untrusted SSL certs if required
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

#construct Uri
$url="https://"+$hostname+"/api/v1.1/auth/login/"
 
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)

#return existing quota entries.
$url="https://"+$hostname+"/api/v1.1/volumes/folder-quotas/?limit="+$limit+"&offset=0"

$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#iterate through the returned quotas to find the quota ID that matches the specified path
foreach($i in 0..($getinfo.items.Count-1))
{
   if ($getinfo.items[$i].path -eq $FolderPath)
    {
    $sharevolguid = ($getinfo.items[$i].volume_guid)
    $shareid = ($getinfo.items[$i].id)
    }
    $i++
}

$UpdateURL="https://"+$hostname+"/api/v1.1/volumes/"+$sharevolguid+"/folder-quotas/"+$shareid + "/"

#build the body for the update
$quotaincbody = @{

    limit = "$NewQuota"

    }

$response = Invoke-RestMethod -uri $UpdateURL -Method Patch -Headers $headers -Body (ConvertTo-Json -InputObject $quotaincbody)
write-output $response | ConvertTo-Json