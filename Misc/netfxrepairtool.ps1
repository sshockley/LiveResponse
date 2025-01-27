if (-not (Test-Path -LiteralPath "C:\Temp")) {
	$ignore = New-Item -Path "c:\Temp" -ItemType directory
}

$file = "C:\Temp\netfxrepairtool.exe"

Write-Output "Downloading netfxrepairtool"
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest "https://aka.ms/DotnetRepairTool" -OutFile $file
$ProgressPreference = 'Continue'


$params = "/quiet", "/logs C:\Temp", "/noceipconsent"

Write-Output "Running repair"
$result = (Start-Process $file -ArgumentList $params -NoNewWindow -Wait -PassThru).ExitCode
Write-Output "Result: $result"

rm -Force $file