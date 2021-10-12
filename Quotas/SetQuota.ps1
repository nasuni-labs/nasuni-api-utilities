#Sets a quota for the specified path. Does not create quota rules.
#See http://docs.api.nasuni.com/nmc/api/1.1.0/index.html#create-folder-quota for reference

#populate NMC hostname
$hostname = "host.domain.com"

# username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ).
# Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

#specify the corresponding Nasuni volume guid for the path
$volume_guid = "InsertVolumeGuidHere"

#Specify the path to the quota folder. The path should start with a "/" and is the path as displayed in the file browser. Replace the "\" supplied by the file browser with "/".
$FolderPath = "/insert/path/here"

#Use this as the new quota (specified in bytes)
$NewQuota = "InsertAmountHere"

#Specify the email address for quota reports
$Email = "InsertEmailAddressHere"

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

#specify the URL for the create folder quota endpoint
$SetURL="https://"+$hostname+"/api/v1.1/volumes/"+$Volume_Guid+"/folder-quotas/"

#build the body for creating the quota
$quotaincbody = @{

    type = "quota"
    path = "$FolderPath"
    email = "$Email"
    limit = "$NewQuota"

    }

$response = Invoke-RestMethod -uri $SetURL -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $quotaincbody)
write-output $response | ConvertTo-Json