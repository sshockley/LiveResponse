Param (
[parameter(Mandatory=$true)][String]$FileName
)

Get-ChildItem -Path / -Include "$($FileName)" -Recurse -ErrorAction SilentlyContinue
