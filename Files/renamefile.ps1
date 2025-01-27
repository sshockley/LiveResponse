Param (
[parameter(Mandatory=$true)][String]$oldFileName
[parameter(Mandatory=$true)][String]$newFileName
)

Rename-Item "$($oldFileName)" "$($oldFileName)" -Confirm -Force