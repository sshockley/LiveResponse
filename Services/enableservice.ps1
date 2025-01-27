Param (
[parameter(Mandatory=$true)][String]$ServiceName
)

Set-Service "$($ServiceName)" -StartupType Automatic
