<# Concatenate, sort, and remove duplicate entries from Export NMC Messages CSV files.
Uses today's date to match and combine files. #>

#path for the CSVs
$ReportFilePath = "C:\logs\NMCmessages"

#Name used for report files
$ReportFileName = "NMCMessages.csv"

#match files
$Today = get-date -f yyyy-MM-dd
$OutFileTemp = $ReportFilePath + "\"+ $Today + "combined.csv.tmp"
$OutFile = $ReportFilePath + "\"+ $Today + "combined.csv"
$Match = $Today + "*" + $ReportFileName

# Build the file list
$fileList = Get-ChildItem -Path $ReportFilePath -Filter $Match -File

# Get the header info from the first file
Get-Content $fileList[0] | select -First 1 | Out-File -FilePath $OutfileTemp -Encoding ascii

# Cycle through and get the data (sans header) from all the files in the list, removing the source files as they are processed
foreach ($file in $filelist)
{
    Get-Content $file | Select -Skip 1 | Out-File -FilePath $outfileTemp -Encoding ascii -Append
    Remove-Item $file
}

#remove duplicates in the combined CSV and sort by sendtime
Import-Csv $OutFileTemp | sort send_time –Unique | Export-Csv -Path $OutFile -NoTypeInformation
Remove-Item -Path $OutFileTemp
