
Stop-Service "wuauserv"

$WindowsUpdatePath = "HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\"
$AutoUpdatePath = "HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

New-Item -Path $WindowsUpdatePath
New-Item -Path $AutoUpdatePath

Set-ItemProperty -Path $AutoUpdatePath -Name NoAutoUpdate -Value 1

Set-ItemProperty -Path $AutoUpdatePath -Name NoAutoUpdate -Value 0
Set-ItemProperty -Path $AutoUpdatePath -Name AUOptions -Value 2
Set-ItemProperty -Path $AutoUpdatePath -Name ScheduledInstallDay -Value 0
Set-ItemProperty -Path $AutoUpdatePath -Name ScheduledInstallTime -Value 3

Set-ItemProperty -Path $AutoUpdatePath -Name NoAutoUpdate -Value 0
Set-ItemProperty -Path $AutoUpdatePath -Name AUOptions -Value 3
Set-ItemProperty -Path $AutoUpdatePath -Name ScheduledInstallDay -Value 0
Set-ItemProperty -Path $AutoUpdatePath -Name ScheduledInstallTime -Value 3

Set-ItemProperty -Path $AutoUpdatePath -Name NoAutoUpdate -Value 0
Set-ItemProperty -Path $AutoUpdatePath -Name AUOptions -Value 4
Set-ItemProperty -Path $AutoUpdatePath -Name ScheduledInstallDay -Value 0
Set-ItemProperty -Path $AutoUpdatePath -Name ScheduledInstallTime -Value 3

Start-Service "wuauserv"