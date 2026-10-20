#Set all shares on the specified filer to read only
#Throttled: keeps at most $maxPending requests in "pending" status at any time.
#Each PATCH returns a message ID; the Get Message endpoint is polled to see whether
#the message is synced (done), pending (waiting) or failure (error).
 
#populate NMC hostname and credentials
$hostname = "host.domain.com"
  
<# Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
$tokenFile = "c:\nasuni\token.txt"

#Provide Filer Serial number to set to read only
$FilerSerial = "InsertFilerSerial"

#Number of shares to query
$limit = 1000

#Maximum number of messages allowed to be pending at the same time
$maxPending = 10

#Seconds to wait between polling cycles while messages are still pending
$pollIntervalSeconds = 5

#Delay in milliseconds after every NMC API call (the original script used ~1.1 seconds between requests)
$requestDelayMs = 1100

#Give up tracking a message that is still not finished after this many minutes (0 = wait forever)
$maxWaitMinutes = 60

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
 
#Read the token from a file and add it to the headers for the request
$token = Get-Content $tokenFile
$headers.Add("Authorization","Token " + $token)

#Build json body for share update
$UpdateBody = @"
{
    "readonly": "False"
}
"@

function Write-Log {
    param([string]$Text, [string]$Color = "Gray")
    Write-Host ("{0}  {1}" -f (Get-Date -Format "HH:mm:ss"), $Text) -ForegroundColor $Color
}

#Connect to the List all shares for filer NMC API endpoint
$url="https://"+$hostname+"/api/v1.1/volumes/filers/shares/?limit="+$limit+"&offset=0"
 
#List volumes
$FormatEnumerationLimit=-1
$GetShareInfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

#Base URL of the Get Message endpoint (message ID and trailing / are appended)
$MessageBaseURL = "https://" + $hostname + "/api/v1.1/messages/"

#Build the list of shares to update (only shares on the specified filer)
$queue = New-Object 'System.Collections.Generic.Queue[object]'
foreach ($share in $GetShareInfo.items) {
    if ($share.filer_serial_number -eq $FilerSerial) {
        $shareName = $share.share_name
        if (-not $shareName) { $shareName = $share.name }
        if ($shareName) { $label = "$shareName ($($share.id))" } else { $label = "share id $($share.id)" }

        $queue.Enqueue([pscustomobject]@{
            Label = $label
            Url   = "https://" + $hostname + "/api/v1.1/volumes/" + $share.Volume_Guid + "/filers/" + $share.filer_serial_number + "/shares/" + $share.id + "/"
        })
    }
}

$total = $queue.Count
if ($total -eq 0) {
    Write-Log "No shares found for filer $FilerSerial. Nothing to do." "Yellow"
    return
}
Write-Log "Found $total share(s) on filer $FilerSerial. Max pending messages: $maxPending" "Cyan"

$pending = @{}   # message ID -> @{ Label; SentAt }
$synced  = New-Object System.Collections.Generic.List[string]
$failed  = New-Object System.Collections.Generic.List[string]

while ($queue.Count -gt 0 -or $pending.Count -gt 0) {

    # ---- 1) Poll every pending message and retire the ones that are finished ----
    foreach ($id in @($pending.Keys)) {
        $entry = $pending[$id]
        $msg = $null
        try {
            $msg = Invoke-RestMethod -Uri ($MessageBaseURL + $id + "/") -Method Get -Headers $headers
        } catch {
            Write-Log "Could not read message $id for $($entry.Label): $($_.Exception.Message) (will retry)" "Yellow"
        }
        Start-Sleep -Milliseconds $requestDelayMs

        $finished = $false
        if ($null -ne $msg) {
            if ($msg.status -eq "synced") {
                $pending.Remove($id)
                $synced.Add($entry.Label)
                $finished = $true
                Write-Log "DONE     $($entry.Label)  [message $id]" "Green"
            }
            elseif ($msg.status -eq "failure") {
                $pending.Remove($id)
                $reason = "$($msg.error.code) $($msg.error.description)".Trim()
                $failed.Add("$($entry.Label) - $reason")
                $finished = $true
                Write-Log "FAILED   $($entry.Label)  [message $id]  $reason" "Red"
            }
        }

        # still pending (or status unknown) - check for timeout
        if (-not $finished -and $maxWaitMinutes -gt 0 -and ((Get-Date) - $entry.SentAt).TotalMinutes -ge $maxWaitMinutes) {
            $pending.Remove($id)
            $failed.Add("$($entry.Label) - gave up after $maxWaitMinutes minutes (message $id may still be pending on the NMC)")
            Write-Log "TIMEOUT  $($entry.Label)  [message $id]" "Red"
        }
    }

    # ---- 2) Send new requests until $maxPending messages are pending ----
    while ($queue.Count -gt 0 -and $pending.Count -lt $maxPending) {
        $share = $queue.Dequeue()
        try {
            $response = Invoke-RestMethod -Uri $share.Url -Method Patch -Headers $headers -Body $UpdateBody
            $msgId = $response.message.id
            if (-not $msgId) { $msgId = $response.id }

            if ($msgId) {
                $pending[$msgId] = @{ Label = $share.Label; SentAt = (Get-Date) }
                Write-Log "SENT     $($share.Label)  [message $msgId]  pending: $($pending.Count)/$maxPending, queued: $($queue.Count)" "Cyan"
            } else {
                $failed.Add("$($share.Label) - request sent but no message ID returned, cannot verify")
                Write-Log "NO MSG ID  $($share.Label)  - cannot verify completion" "Red"
            }
        } catch {
            $failed.Add("$($share.Label) - request failed: $($_.Exception.Message)")
            Write-Log "REQUEST FAILED  $($share.Label)  $($_.Exception.Message)" "Red"
        }
        Start-Sleep -Milliseconds $requestDelayMs
    }

    # ---- 3) Wait before the next polling cycle ----
    if ($pending.Count -gt 0) {
        Write-Log "Pending: $($pending.Count)  Queued: $($queue.Count)  Synced: $($synced.Count)  Failed: $($failed.Count)  - waiting $pollIntervalSeconds s" "DarkGray"
        Start-Sleep -Seconds $pollIntervalSeconds
    }
}

# ---- Summary ----
Write-Host ""
Write-Log "Finished. Total: $total  Synced: $($synced.Count)  Failed: $($failed.Count)" "Cyan"
if ($failed.Count -gt 0) {
    Write-Log "Shares that did not complete:" "Red"
    foreach ($f in $failed) { Write-Host "  - $f" -ForegroundColor Red }
}
