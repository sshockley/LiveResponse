# How to run:
# run cpfile.ps1 -parameters "-FileName 'C:\users\username\OneDrive - Aras Corp\Microsoft Teams Chat Files\filename.zip' -Destination C:\filename.zip"
#
# Note the combination of quotes for parameters and spaces

Param (
[parameter(Position=0,Mandatory=$true)][String]$FileName,
[parameter(Position=1,Mandatory=$true)][String]$Destination
)

$formatted_FileName = $FileName.Replace("`"", "").Replace("`'", "")


Copy-Item -Path $formatted_FileName -Destination $Destination -Force -Recurse
