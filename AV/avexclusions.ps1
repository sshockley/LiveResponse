Write-Host `r`n Excluded Extensions
Get-MpPreference | select-object -Property ExclusionExtension -ExpandProperty ExclusionExtension

Write-Host `r`n Excluded IP Addresses
Get-MpPreference | select-object -Property ExclusionIpAddress -ExpandProperty ExclusionIpAddress

Write-Host `r`n Excluded Paths
Get-MpPreference | select-object -Property ExclusionPath -ExpandProperty ExclusionPath

Write-Host `r`n Excluded Processes
Get-MpPreference | select-object -Property ExclusionProcess -ExpandProperty ExclusionProcess