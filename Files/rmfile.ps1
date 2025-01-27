Param (
[parameter(Mandatory=$true)][String]$FileName
)

rm -Recurse -Force "$($FileName)"