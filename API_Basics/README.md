# nmc-api-powershell-utilities
Utilities and scripts that use the NMC API to perform operations and generate reports

# PowerShell REST API Basics
These NMC API PowerShell scripts provide the building blocks for interacting with the NMC API.

## Authentication and Access
Accessing the NMC API requires a user that is a member of an NMC group that has the "Enable NMC API Access" permission enabled. API users must also have the corresponding NMC permission for the action that they are performing. For example, setting folder quotas with the NMC API requires the "Manage Folder Quotas" NMC permission. Users must first authenticate to the NMC to obtain a token, and then can use that token to access subsequent API endpoints.

Both native and domain accounts are supported for NMC API authentication (SSO accounts are not supported using with the NMC API). Domain account usernames should be formatted as a UPN (username@emailaddress) for the best compatibility with PowerShell and Bash syntax.

## Request a Token
This is a simple script to validate NMC API connectivity and obtain a token that can be used with other NMC API endpoints. The script writes the token to the console if execution is successful and outputs the token to the path specified in the tokenFile variable so that it can be used for authentication for subsequent scripts. Be sure to use single rather than double quotes when entering the password since passwords may contain special characters that need to be treated literally by PowerShell.\
**Required Inputs**: NMC hostname, username, password, tokenFile\
**Compatibility**: Nasuni 7.10 or higher required\
**Name**: GetToken.ps1

## Better Error Handling
PowerShell's Invoke-RestMethod cmdlet only includes basic error handling by default, returning messages such as "400 Error Bad Request", while suppressing the full error message from the API endpoint. Fortunately, there is a way to get verbose error messages by using try/catch with Invoke-RestMethod and calling a function in case of error. PowerShell 6 and PowerShell core support a newer method for error handling while older versions of PowerShell require the use of GetResponseStream to capture errors. This script checks the PowerShell version to determine which method to use.

The code snippet below can be used as an example for modifying the PowerShell code examples in Confluence. Add the function (lines 1-13) to your script before referencing it, since functions must be defined before calling them in PowerShell. Line 15 of this script is an example of using try/catch with a command and should not be directly copied to your script since the variable names will not match. Instead, modify the Invoke-RestMethod line of the script that you would like to get better errors for by adding "try" and the matching open and close curly braces along followed by the "catch" command and "Failure" within curly braces.\
**Name**: BetterErrorHandling.ps1

## Allow Untrusted SSL Certificates
Having a valid SSL certificate for the NMC is a best practice, but test/dev or new environments may not yet have a valid SSL certificate. Fortunately, there's a way to skip SSL certificate checks and this is included in most of the PowerShell examples we provide. If you have a valid SSL certificate for your NMC, you can remove this code block from the provided examples.

If you are using PowerShell 6 or higher, the Invoke-RestMethod cmdlet natively includes a “-SkipCertificateCheck” option and this script changes the default for the Invoke-RestMethod cmdlet to skip certificate checks. Versions of PowerShell before version 6 and PowerShell core do not support a “-SkipCertificateCheck” option and must rely on the .Net subsystem to disable certificate checks.\
**Name**: AllowUntrustedSSLCerts.ps1

## Avoid NMC API Throttling
Beginning with version 8.5, NMC API endpoints are now throttled to preserve NMC performance and stability. NMC API endpoints are generally limited to 5 requests/second for "Get" actions and 1 request per second for "Post", "Update", or "Delete" actions. Nasuni recommends adding "sleep" or "wait" steps to existing API integrations to avoid exceeding the throttling defaults. The PowerShell Start-Sleep cmdlet can be used inside of your scripts to limit the speed of PowerShell Execution and to avoid throttling limits. For example, this command will pause execution for 1.1 seconds:

Start-Sleep -s 1.1

## PowerShell Tools
Windows includes built-in tools for PowerShell editing and testing and there is also a good cross-platform, Microsoft-provided option for code editing that has native support for PowerShell. 

PowerShell ISE is part of the Windows server and client. 

Visual Studio Code (Windows, macOS, Linux) has native support for PowerShell editing and is both free and built on open source.

## Version Troubleshooting
Some NMC API endpoints require a specific NMC or Edge Appliance version, and if the request is made to the NMC the NMC API endpoint will return a message such as:

"Current filer version does not support this type of request. Please update your Edge Appliance to use this feature."

If the Edge Appliance version and NMC do in fact match what is documented for the NMC API endpoint and the error is still returned, it's possible that Edge Appliances were updated prior to upgrading the NMC. If this were to occur, the fulldumps that the Edge Appliances sent to the NMC would have contained information that the NMC couldn't process, causing the NMC to think the Edge Appliance doesn't meet the version criteria for the particular NMC API endpoint. The fix for this is to have the Edge Appliances resend their fulldumps once the NMC is running the current version–the "Refresh Managed Filers" button on the NMC overview page will do this.

