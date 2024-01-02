#Sets a quota for the specified path. Does not create quota rules.

#populate NMC hostname
$hostname = "host.domain.com"

<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#specify the corresponding Nasuni volume guid for the path
$volume_guid = "InsertVolumeGuidHere"

#Specify the path to the quota folder. The path should start with a "/" and is the path as displayed in the file browser. Replace the "\" supplied by the file browser with "/".
$FolderPath = "/insert/path/here"

#Use this as the new quota (specified in bytes)
$NewQuota = "InsertAmountHere"

#Specify the email address for quota reports
$Email = "InsertEmailAddressHere"

#end variables
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
 
#Read the token from a file and add it to the headers for the request
$token = Get-Content $tokenFile
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
