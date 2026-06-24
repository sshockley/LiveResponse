Param (
[parameter(Mandatory=$true)][String]$FileName
)

Get-ChildItem -Include "$($FileName)" -Recurse -ErrorAction SilentlyContinue
