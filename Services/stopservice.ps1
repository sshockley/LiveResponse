Param (
[parameter(Mandatory=$true)][String]$ServiceName
)

Stop-Service "$($ServiceName)"
