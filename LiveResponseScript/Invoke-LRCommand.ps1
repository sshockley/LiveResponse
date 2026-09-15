<#
    Invoke-LRCommand.ps1
    Live Response library wrapper that gives the API a general command channel.

    Upload once per tenant, then Invoke-MdeLiveResponse.ps1's "cmd" verb routes through it:
        library upload ./Invoke-LRCommand.ps1 "Analyst command channel"
        cmd Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name,Id,CPU

    Review before you upload. It executes whatever string an authorized caller passes,
    under SYSTEM on the endpoint, so it widens what any holder of Machine.LiveResponse can
    do compared with a library of narrow, purpose-built scripts. Some teams deliberately
    keep only curated scripts for exactly that reason. It also requires
    "Live response unsigned script execution" to be enabled, unless you sign it.

    Runs are bounded by the platform's 10 minute RunScript timeout.
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandParts
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

$command = ($CommandParts -join ' ').Trim()

if (-not $command) {
    Write-Output 'No command supplied. Usage: Invoke-LRCommand.ps1 <powershell expression>'
    exit 2
}

Write-Output "=== Invoke-LRCommand ==="
Write-Output "host    : $env:COMPUTERNAME"
Write-Output "user    : $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Output "utc     : $((Get-Date).ToUniversalTime().ToString('o'))"
Write-Output "command : $command"
Write-Output "------------------------"

$sw = [Diagnostics.Stopwatch]::StartNew()
$exit = 0

try {
    # Capture both success and error streams so failures surface in the LR result.
    $output = Invoke-Expression -Command $command 2>&1
    if ($null -ne $output) {
        $output | Out-String -Width 4096 | Write-Output
    }
    if ($Error.Count -gt 0) { $exit = 1 }
} catch {
    Write-Output "EXCEPTION: $($_.Exception.GetType().FullName)"
    Write-Output $_.Exception.Message
    if ($_.ScriptStackTrace) { Write-Output $_.ScriptStackTrace }
    $exit = 1
}

$sw.Stop()
Write-Output "------------------------"
Write-Output "elapsed : $([math]::Round($sw.Elapsed.TotalSeconds,2))s"
Write-Output "exit    : $exit"

exit $exit
