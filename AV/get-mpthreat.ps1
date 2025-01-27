Param (
[parameter(Mandatory=$true)][String]$command,
[parameter(Mandatory=$false)][String]$command2,
[parameter(Mandatory=$false)][String]$command3,
[parameter(Mandatory=$false)][String]$command4,
[parameter(Mandatory=$false)][String]$command5
)

Get-MpThreat "$($command)" "$($command2)" "$($command3)" "$($command4)" "$($command5)"