Param (
[parameter(Mandatory=$true)][String]$File
)

& "C:\Program Files\Windows Defender\MpCmdRun.exe" -Scan -ScanType 3 -File "$($File)"
