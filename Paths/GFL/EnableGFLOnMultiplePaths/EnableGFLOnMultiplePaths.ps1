<# EnableGFLOnMultiplePaths.ps1 - CSV Input with Retries and Delays
Processes each path serially with retry logic and delays
Includes comprehensive error handling and logging

Note: If Advanced GFL mode is set on parent directory, GFL mode cannot be disabled on sub directories.

CSV format: Path,Mode (header row required)
Example CSV content:
Path,Mode
/folder1/folder2,optimized
/folder3,advanced
#>

param(
    [Parameter(Mandatory=$false, HelpMessage="Path to CSV file containing Path and Mode columns")]
    [string]$CsvPath,
    
    [Parameter(Mandatory=$false, HelpMessage="NMC hostname (if not provided, will use value from script)")]
    [string]$Hostname,
    
    [Parameter(Mandatory=$false, HelpMessage="Path to token file (if not provided, will use value from script)")]
    [string]$TokenFile,
    
    [Parameter(Mandatory=$false, HelpMessage="Volume GUID (if not provided, will use value from script)")]
    [string]$VolumeGuid,
    
    [Parameter(Mandatory=$false, HelpMessage="Number of retries per path (default: 20)")]
    [int]$RetryLimit = 20,
    
    [Parameter(Mandatory=$false, HelpMessage="Delay between retries in seconds (default: 30)")]
    [int]$RetryDelay = 30,
    
    [Parameter(Mandatory=$false, HelpMessage="Export detailed results to CSV")]
    [switch]$ExportResults
)

#populate NMC hostname and credentials (fallback values if not provided via parameters)
if (-not $Hostname) {
    $hostname = "InsertNMCHostname"  # Update this default value
}

<#Path to the NMC API authentication token file--use GetTokenCredPrompt/GetToken scripts to get a token.
Tokens expire after 8 hours #>
if (-not $TokenFile) {
    $tokenFile = "c:\nasuni\token.txt"  # Update this default path
}

#populate CSV path (prompt if not provided via parameter)
if (-not $CsvPath) {
    $CsvPath = Read-Host "Enter path to CSV file containing Path and Mode columns [c:\nasuni\input.csv]"
    if ([string]::IsNullOrWhiteSpace($CsvPath)) {
        $CsvPath = "c:\nasuni\input.csv"  # Use default if user just presses Enter
        Write-Host "Using default CSV path: $CsvPath"
    }
}

#specify Volume GUID (fallback if not provided via parameter)
if (-not $VolumeGuid) {
    $volume_guid = "insertVolumeGUID"  # Update this default value
} else {
    $volume_guid = $VolumeGuid
}

# Enhanced logging function
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [switch]$NoNewLine
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    if ($NoNewLine) {
        Write-Host $logMessage -NoNewline
    } else {
        Write-Host $logMessage
    }
}

function Invoke-SinglePathProcessing {
    param(
        [string]$Path,
        [string]$Mode,
        [int]$RowNumber,
        [hashtable]$Headers,
        [string]$Hostname,
        [string]$VolumeGuid,
        [int]$RetryLimit,
        [int]$RetryDelay
    )
    
    Write-Log "=" * 80
    Write-Log "Processing Row $RowNumber - Path: $Path, Mode: $Mode" -Level "INFO"
    
    # Create result object to track this path's processing
    $result = [PSCustomObject]@{
        RowNumber = $RowNumber
        Path = $Path
        Mode = $Mode
        Status = "Unknown"
        RetryCount = 0
        ErrorMessage = ""
        ProcessedAt = Get-Date
        Success = $false
    }
    
    #set the RetryCount to 1 before beginning the loop
    $RetryCount = 1
    $status = "Unknown"

    Write-Log "Setting $Mode GFL mode on: $Path"

    #run loop the number of times specified by the Retry Limit or until the snapshot status is idle
    DO {
        Write-Log "  Attempt $RetryCount of $RetryLimit"
        $result.RetryCount = $RetryCount

        try {
            #enable GFL for path
            #Set the URL for the folder update NMC API endpoint
            $GFLurl = "https://" + $Hostname + "/api/v1.1/volumes/" + $VolumeGuid + "/global-lock-folders/"
            
            #build the body for the folder update
            $body = @{
                path = $Path
                mode = $Mode
            }

            #set GFL and mode for the specified path
            Write-Log "    Sending GFL request..."
            $SetGFL = Invoke-RestMethod -Uri $GFLurl -Method Post -Headers $Headers -Body (ConvertTo-Json -InputObject $body)

            #wait for setting GFL to complete
            Start-Sleep -Seconds 5

            #see what happened when setting GFL
            Write-Log "    Checking operation status..."
            $Message = Invoke-RestMethod -Uri $SetGFL.message.links.self.href -Method Get -Headers $Headers

            #check for the pending condition and if pending, retry after 10 seconds
            if ($Message.status -eq "pending") {
                Write-Log "    Status pending, waiting 10 seconds..." -Level "WARN"
                Start-Sleep -Seconds 10
                #get the message again to see if waiting longer helped
                $Message = Invoke-RestMethod -Uri $SetGFL.message.links.self.href -Method Get -Headers $Headers
            }
            
            #if message status is synced the set GFL operation was successful
            if ($Message.status -eq "synced") {
                $status = "success"
                $result.Status = $status
                $result.Success = $true
                Write-Log "    SUCCESS: GFL configured successfully" -Level "SUCCESS"
                break
            }
            
            #handle failure cases
            if ($Message.status -eq "failure") {
                if ($Message.error.description -like "*snapshot is taking place*") {
                    #snapshot is busy - we need to retry
                    $status = "Snapshot Busy"
                    $result.Status = $status
                    Write-Log "    Snapshot busy - will retry" -Level "WARN"
                } else {
                    #failure from invalid path - log and exit loop
                    $status = "Invalid Path"
                    $result.Status = $status
                    $result.ErrorMessage = $Message.error.description
                    Write-Log "    ERROR: Invalid Path - $($Message.error.description)" -Level "ERROR"
                    
                    if ($Message.links.acknowledge) {
                        $DeleteMessageURL = $Message.links.acknowledge.href
                        try {
                            $null = Invoke-RestMethod -Uri $DeleteMessageURL -Method Delete -Headers $Headers
                            Write-Log "    Cleaned up error message" -Level "INFO"
                        } catch {
                            Write-Log "    Warning: Could not clean up error message: $($_.Exception.Message)" -Level "WARN"
                        }
                    }
                    break
                }
                
                #clean up the sync error for snapshot busy case
                if ($Message.links.acknowledge) {
                    try {
                        $DeleteMessageURL = $Message.links.acknowledge.href
                        $null = Invoke-RestMethod -Uri $DeleteMessageURL -Method Delete -Headers $Headers
                    } catch {
                        Write-Log "    Warning: Could not clean up pending message: $($_.Exception.Message)" -Level "WARN"
                    }
                }
            }
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-Log "    API Error: $errorMessage" -Level "ERROR"
            $result.ErrorMessage = $errorMessage
            
            # For API errors, we might want to retry depending on the error type
            if ($errorMessage -like "*timeout*" -or $errorMessage -like "*connection*") {
                Write-Log "    Network-related error, will retry..." -Level "WARN"
            } else {
                # For other errors, consider them fatal for this path
                $status = "API Error"
                $result.Status = $status
                break
            }
        }

        #Increment the RetryCount before retrying
        $RetryCount++

        #If the end of the loop completes and the snapshot is still running end the loop and clean up the pending request
        if ($RetryCount -gt $RetryLimit) {
            Write-Log "    Maximum retries exceeded" -Level "ERROR"
            $status = "retryExceeded"
            $result.Status = $status
            $result.ErrorMessage = "Maximum retry limit ($RetryLimit) exceeded"
            break
        }

        #sleep for defined time in Retry delay before starting the loop again
        if ($RetryCount -le $RetryLimit) {
            Write-Log "    Waiting $RetryDelay seconds before retry..." -Level "WARN"
            Start-Sleep -Seconds $RetryDelay
        }

    } Until ($RetryCount -gt $RetryLimit)
    
    # Final status update
    if ($result.Success) {
        Write-Log "Row $RowNumber completed successfully after $($result.RetryCount) attempts" -Level "SUCCESS"
    } else {
        Write-Log "Row $RowNumber failed: $($result.Status) - $($result.ErrorMessage)" -Level "ERROR"
    }
    
    return $result
}

# Main script execution
try {
    Write-Log "Starting Enhanced GFL Configuration Script" -Level "INFO"
    Write-Log "Script Version: 2.0 (CSV Input Support)"
    Write-Log "Timestamp: $(Get-Date)"
    
    # Validate parameters
    if (-not (Test-Path $CsvPath)) {
        throw "CSV file not found: $CsvPath"
    }
    
    if (-not (Test-Path $tokenFile)) {
        throw "Token file not found: $tokenFile"
    }
    
    Write-Log "Configuration:"
    Write-Log "  CSV Path: $CsvPath"
    Write-Log "  NMC Hostname: $hostname"
    Write-Log "  Token File: $tokenFile"
    Write-Log "  Volume GUID: $volume_guid"
    Write-Log "  Retry Limit: $RetryLimit"
    Write-Log "  Retry Delay: $RetryDelay seconds"

    # Allow untrusted SSL certs - cross-platform compatible approach
    if ($PSVersionTable.PSEdition -eq 'Core') {
        # PowerShell Core (Windows/Mac/Linux)
        if (-not $PSDefaultParameterValues.ContainsKey('Invoke-RestMethod:SkipCertificateCheck')) {
            $PSDefaultParameterValues.Add('Invoke-RestMethod:SkipCertificateCheck', $true)
        }
    }
    else {
        # Windows PowerShell 5.1 and earlier
        if (-not ("TrustAllCertsPolicy" -as [type])) {
            # Use a simpler approach that avoids C# interface syntax issues
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        } 
    }

    #build JSON headers
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept", 'application/json')
    $headers.Add("Content-Type", 'application/json')

    #Read the token from a file and add it to the headers for the request
    Write-Log "Reading authentication token..."
    $token = Get-Content $tokenFile -Raw
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Token file is empty or contains only whitespace"
    }
    $headers.Add("Authorization", "Token " + $token.Trim())

    # Import and validate CSV
    Write-Log "Importing CSV file..."
    try {
        $csvData = Import-Csv -Path $CsvPath
    }
    catch {
        throw "Failed to import CSV file: $($_.Exception.Message)"
    }
    
    if ($csvData.Count -eq 0) {
        throw "CSV file is empty or contains no data rows"
    }

    # Validate CSV structure
    $requiredColumns = @('Path', 'Mode')
    $csvProperties = $csvData[0].PSObject.Properties.Name
    
    foreach ($column in $requiredColumns) {
        if ($column -notin $csvProperties) {
            throw "CSV file missing required column: '$column'. Required columns: $($requiredColumns -join ', '). Found columns: $($csvProperties -join ', ')"
        }
    }

    Write-Log "CSV validation successful:"
    Write-Log "  Rows to process: $($csvData.Count)"
    Write-Log "  Columns found: $($csvProperties -join ', ')"

    # Validate individual rows
    $invalidRows = @()
    $validModes = @('optimized', 'advanced', 'asynchronous')  # Based on original script comment
    
    for ($i = 0; $i -lt $csvData.Count; $i++) {
        $row = $csvData[$i]
        $currentRowNum = $i + 1
        
        if ([string]::IsNullOrWhiteSpace($row.Path)) {
            $invalidRows += "Row $currentRowNum`: Empty or missing Path"
        }
        if ([string]::IsNullOrWhiteSpace($row.Mode)) {
            $invalidRows += "Row $currentRowNum`: Empty or missing Mode"
        } elseif ($row.Mode.Trim() -notin $validModes) {
            $invalidRows += "Row $currentRowNum`: Invalid Mode '$($row.Mode)'. Valid modes: $($validModes -join ', ')"
        }
    }

    if ($invalidRows.Count -gt 0) {
        Write-Log "CSV validation errors found:" -Level "ERROR"
        foreach ($validationError in $invalidRows) {
            Write-Log "  $validationError" -Level "ERROR"
        }
        throw "CSV contains invalid data. Please fix the errors and try again."
    }

    # Process each row serially
    Write-Log "Beginning serial processing of $($csvData.Count) paths..."
    $results = @()
    $successCount = 0
    $failureCount = 0

    for ($i = 0; $i -lt $csvData.Count; $i++) {
        $row = $csvData[$i]
        $rowNumber = $i + 1
        
        # Clean the data
        $cleanPath = $row.Path.Trim()
        $cleanMode = $row.Mode.Trim()
        
        # Process this path with retry logic
        $result = Invoke-SinglePathProcessing -Path $cleanPath -Mode $cleanMode -RowNumber $rowNumber -Headers $headers -Hostname $hostname -VolumeGuid $volume_guid -RetryLimit $RetryLimit -RetryDelay $RetryDelay
        
        $results += $result
        
        if ($result.Success) {
            $successCount++
        } else {
            $failureCount++
        }
        
        # Small delay between processing different paths to be gentle on the API
        if ($i -lt ($csvData.Count - 1)) {
            Write-Log "Waiting 5 seconds before processing next path..." -Level "INFO"
            Start-Sleep -Seconds 5
        }
    }

    # Final summary
    Write-Log "=" * 80
    Write-Log "PROCESSING COMPLETE" -Level "SUCCESS"
    Write-Log "Total paths processed: $($csvData.Count)"
    Write-Log "Successful: $successCount"
    Write-Log "Failed: $failureCount"
    Write-Log "Success rate: $([math]::Round(($successCount / $csvData.Count) * 100, 1))%"

    if ($failureCount -gt 0) {
        Write-Log ""
        Write-Log "FAILED PATHS SUMMARY:" -Level "ERROR"
        foreach ($failedResult in ($results | Where-Object { -not $_.Success })) {
            Write-Log "  Row $($failedResult.RowNumber): '$($failedResult.Path)' ($($failedResult.Mode)) - $($failedResult.Status)" -Level "ERROR"
            if ($failedResult.ErrorMessage) {
                Write-Log "    Error: $($failedResult.ErrorMessage)" -Level "ERROR"
            }
        }
    }

    # Export results if requested or if there were failures
    if ($ExportResults -or $failureCount -gt 0) {
        $resultsCsvPath = $CsvPath -replace '\.csv$', '_results.csv'
        try {
            $results | Export-Csv -Path $resultsCsvPath -NoTypeInformation
            Write-Log "Detailed results exported to: $resultsCsvPath" -Level "INFO"
        }
        catch {
            Write-Log "Warning: Could not export results CSV: $($_.Exception.Message)" -Level "WARN"
        }
    }

    # Exit with appropriate code
    if ($failureCount -gt 0) {
        Write-Log "Script completed with errors. Check the output above for details." -Level "WARN"
        exit 1
    } else {
        Write-Log "All paths processed successfully!" -Level "SUCCESS"
        exit 0
    }
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Script execution failed." -Level "ERROR"
    exit 2
}
