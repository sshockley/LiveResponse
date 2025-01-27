Param (
[parameter(Mandatory=$true)][String]$ServiceName
)

Start-Service "$($ServiceName)"
