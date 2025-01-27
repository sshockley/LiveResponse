if (-not (Test-Path -LiteralPath "C:\Temp")) {
	$ignore = New-Item -Path "c:\Temp" -ItemType directory
}

Get-TroubleshootingPack -Path C:\Windows\diagnostics\system\WindowsUpdate | Invoke-TroubleshootingPack -Unattended -Result C:\Temp\