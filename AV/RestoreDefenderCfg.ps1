if (-not (Test-Path -LiteralPath "C:\Temp")) {
	$ignore = New-Item -Path "c:\Temp" -ItemType directory
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Output "Downloading RestoreDefenderConfig.exe"
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest "https://github.com/DebugPrivilege/CPP/raw/main/Windows%20Defender/RestoreDefenderConfig.exe" -OutFile "C:\Temp\RestoreDefenderConfig.exe"
$ProgressPreference = 'Continue'

& "C:\Temp\RestoreDefenderConfig.exe" "--start"
& "C:\Temp\RestoreDefenderConfig.exe" "--removeAllExclusions"
& "C:\Temp\RestoreDefenderConfig.exe" "--removeAllExtensions"
& "C:\Temp\RestoreDefenderConfig.exe" "--removeAllDirectories"
& "C:\Temp\RestoreDefenderConfig.exe" "--fullScan"

rm "C:\Temp\RestoreDefenderConfig.exe"