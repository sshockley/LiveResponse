Get-Service | where{$_.StartType -eq "Disabled"} | Select Name,DisplayName,StartType,Status,DependentServices,ServicesDependedOn | ft -AutoSize