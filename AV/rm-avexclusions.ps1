Write-Host `r`n Removing Excluded Extensions
Remove-MpPreference -ExclusionExtension (Get-MpPreference).ExclusionExtension -Verbose:$false

Write-Host `r`n Removing Excluded IP Addresses
Remove-MpPreference -ExclusionIpAddress (Get-MpPreference).ExclusionIpAddress -Verbose:$false

Write-Host `r`n Removing Excluded Paths
Remove-MpPreference -ExclusionPath (Get-MpPreference).ExclusionPath -Verbose:$false

Write-Host `r`n Removing Excluded Processes
Remove-MpPreference -ExclusionProcess (Get-MpPreference).ExclusionProcess -Verbose:$false
