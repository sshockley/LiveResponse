<#
.SYNOPSIS
    Archive a file or directory in zip format in preparation for Microsoft Defender for Endpoint (MDE) Live Response getfile
.DESCRIPTION
	Stolen from https://github.com/dfir-alvin/mde_live_response_scripts/blob/main/zip.ps1
    Leverage PowerShell's native compression module to zip up a file or directory. This can be used before the getfile command with Microsoft Defender for Endpoint (MDE) Live Response to avoid using multiple getfile commands manually. File is saved with local timestamp and .zip extension to prevent file name conflict. Supports zipping of either file or directory. 

    Disclaimer
    This is a sample script and is provided without any warranty. Please test scripts within test environment before using in real incident response scenarios. The author of this script has no affiliations with Microsoft or the Microsoft Defender for Endpoint (MDE) product. 
.PARAMETERS
    -i
    name of file or directory to zip
.USAGE
    zip.ps1 -i "C:\Windows\Temp\Test"
    zip.ps1 "C:\Windows\Temp\Test"
.VERSION
    2.0
    Renamed variables and documentation for file and directory support.

    1.0
    Initial release
#>

# Input for file or directory
Param (
[parameter(Mandatory=$true)][String]$i
)

# Remove quotes from input so variable is usable
$formatted_input_name = $i.Replace("`"", "").Replace("`'", "")

# Test if file or directory exists
$existence_check = Test-Path -Path "$formatted_input_name"

# Zip file or directory into new file
function create_zipped_file {

    # Zipping variable
    $zipped_file = "C:\Windows\Temp\zip"+(Get-Date -f _yyyy.MM.dd-HH.mm.ss.K | ForEach-Object { $_ -replace ":", "." })+".zip"

    #Compression process
    Compress-Archive -Path $formatted_input_name -DestinationPath $zipped_file -CompressionLevel Fastest

    # Hash newly created encrypted file
    $zipped_file_hash = Get-FileHash $zipped_file | Format-List

    # Provide hash information to user
    Write-Host "Encrypted File Information"
    Write-Output $zipped_file_hash
    }

# Main execution code
if ($existence_check -eq $true){
    create_zipped_file
    }
else {
    Write-Host "File or directory does not exist. Please check input path provided."
}