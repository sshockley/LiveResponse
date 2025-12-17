# enable-windowsupdate.ps1
# https://github.com/darianmiller/control-windows-updates

Write-Host ""
Write-Host "Removing Windows Update registry policy restrictions..."

$policyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

# Remove only the known values
$props = @(
    "NoAutoRebootWithLoggedOnUsers",
    "NoAutoUpdate",
    "AUOptions",
    "ScheduledInstallEveryWeek"
)

foreach ($prop in $props) {
    try {
        Remove-ItemProperty -Path $policyKey -Name $prop -ErrorAction Stop
        Write-Host "Removed: $prop"
    } catch {
        Write-Host "Skipped (not found): $prop"
    }
}

$uxKey = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\ux\Settings"
try {
	Remove-Item -Path $uxKey -Force
	Write-Host "Removed: $uxKey"
} catch {
	Write-Host "Skipped (not found): $uxKey"
}

Write-Host "Finished clearing Windows Update policy overrides."



Write-Host "Re-enabling Windows Update services..."

$services = @(
    @{ Name = "WaaSMedicSvc"; Desc = "Windows Update Medic Service" },
    @{ Name = "wuauserv";     Desc = "Windows Update Service" },
    @{ Name = "UsoSvc";       Desc = "Update Orchestrator Service" }
)

foreach ($svc in $services) {
    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)"
    try {
        Set-ItemProperty -Path $path -Name "Start" -Value 3 -Force  # 3 = Manual
        Write-Host "Re-enabled $($svc.Desc) ($($svc.Name)) [Start = 3]"
    } catch {
        Write-Host "Failed to re-enable $($svc.Desc). Run as Administrator."
        Write-Host $_.Exception.Message
    }
}

Write-Host ""
Write-Host "Removing Windows Update firewall rules..."

$ruleNamePrefix = "DM-ControlUpdates-Block-WindowsUpdateIP"
$knownRanges = @(
    "13.107.4.0/24",
    "13.107.8.0/24",
    "13.107.64.0/18",
    "20.190.128.0/18",
    "40.76.0.0/14",
    "40.92.0.0/15",
    "40.96.0.0/13",
    "40.104.0.0/15",
    "40.108.128.0/17",
    "52.96.0.0/14",
    "52.100.0.0/14",
    "52.104.0.0/14",
    "52.108.0.0/15",
    "52.112.0.0/14",
    "52.120.0.0/14"
)

foreach ($subnet in $knownRanges) {
    $ruleName = "$ruleNamePrefix-$subnet"
    try {
        $rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop
        Remove-NetFirewallRule -Name $rule.Name
        Write-Host "Removed firewall rule: $ruleName"
    } catch {
        Write-Host "No rule found or failed to remove: $ruleName"
    }
}

& C:\windows\system32\gpupdate.exe /force