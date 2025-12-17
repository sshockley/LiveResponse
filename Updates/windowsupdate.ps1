Install-Module PSWindowsUpdate -Force
Import-Module PSWindowsUpdate -Force
Add-WUServiceManager -MicrosoftUpdate -Confirm:$false
Get-WindowsUpdate
Install-WindowsUpdate -MicrosoftUpdate -Confirm:$false
