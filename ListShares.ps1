#Export All Shares and details to a CSV

#populate NMC hostname and credentials
$hostname = "insertNMChostnameHere"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#Number of shares to return
$limit = 1000

#end variables
#build the cred for authentication
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

#Connect to the List all shares for filer NMC API endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit=" + $limit+ "&offset=0"
$FormatEnumerationLimit=-1
$getinfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#list shares and export to console
$OutputHeader = "shareid, Volume_GUID,filer_serial_number, share_name, path, comment, readonly, browseable, authall, ro_users, rw_users, ro_groups, rw_groups, hosts_allow, hide_unreadable, enable_previous_vers, case_sensitive, enable_snapshot_dirs, homedir_support, mobile, browser_access, aio_enabled, veto_files, fruit_enabled, smb_encrypt"
write-output $OutputHeader

foreach($i in 0..($getinfo.items.Count-1)){
    $datastring =  "$($getinfo.items[$i].id),$($getinfo.items[$i].Volume_Guid),$($getinfo.items[$i].Filer_Serial_Number),$($getinfo.items[$i].name),$($getinfo.items[$i].path),$($getinfo.items[$i].comment),$($getinfo.items[$i].readonly),$($getinfo.items[$i].browseable),$($getinfo.items[$i].auth.authall),$($getinfo.items[$i].auth.ro_users),$($getinfo.items[$i].auth.rw_users),$($getinfo.items[$i].auth.ro_groups),$($getinfo.items[$i].auth.rw_groups),$($getinfo.items[$i].hosts_allow),$($getinfo.items[$i].hide_unreadable),$($getinfo.items[$i].enable_previous_vers),$($getinfo.items[$i].case_sensitive),$($getinfo.items[$i].enable_snapshot_dirs),$($getinfo.items[$i].homedir_support),$($getinfo.items[$i].mobile),$($getinfo.items[$i].browser_access),$($getinfo.items[$i].aio_enabled),$($getinfo.items[$i].veto_files),$($getinfo.items[$i].fruit_enabled),$($getinfo.items[$i].smb_encrypt)"
	write-output $datastring
	$i++
} 