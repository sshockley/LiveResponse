New-Item -Path c:\Temp -ItemType directory -Force

$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest 'https://go.microsoft.com/fwlink/?LinkID=87341' -OutFile 'C:\Temp\mpam-feX64.exe'
Invoke-WebRequest 'https://go.microsoft.com/fwlink/?LinkID=187316&arch=x64&nri=true' -OutFile 'C:\Temp\nis_full.exe'
$ProgressPreference = 'Continue'

Write-Output "Validating MAPS connection"
& "C:\Program Files\Windows Defender\MpCmdRun.exe" -ValidateMapsConnection

Write-Output "Updating definitions"
& 'C:\Temp\mpam-feX64.exe'

Write-Output "Updating NIS"
& 'C:\Temp\nis_full.exe'
