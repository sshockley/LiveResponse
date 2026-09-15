<#
.SYNOPSIS
    Silently removes McAfee WebAdvisor / SiteAdvisor from a Windows client.

.DESCRIPTION
    Must run in SYSTEM / device context (Intune Remediations, Configuration
    Manager, or a startup GPO script). Order of operations matters:

      1. Stop running WebAdvisor processes so the uninstaller isn't blocked.
      2. Remove the provisioned AppX package FIRST, then per-user packages.
         Reversing this order means the app returns on the next new profile.
      3. Drive the Win32 uninstaller with a candidate switch list, verifying
         after each attempt. McAfee does not document silent switches for the
         consumer products, so the switch that works varies by build.
      4. Sweep leftover services, scheduled tasks, and folders.

    Logs to C:\ProgramData\Aras\Logs\Remove-McAfeeWebAdvisor.log

.NOTES
    - Does NOT touch enterprise McAfee/Trellix ENS. Name matching is scoped to
      WebAdvisor/SiteAdvisor plus McAfee consumer AppX packages. Review the
      $appxPattern and $uninstallPattern values against your estate first.
    - Some builds hold file locks that only clear on reboot; the script reports
      this rather than forcing a restart.
    - Test on a pilot ring. AI-assisted; review and validate before use.
#>

[CmdletBinding()]
param(
    [switch]$WhatIfOnly
)

$ErrorActionPreference = 'Continue'

$logDir  = 'C:\ProgramData\Aras\Logs'
$logFile = Join-Path $logDir 'Remove-McAfeeWebAdvisor.log'
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $logFile -Value $line
    Write-Output $line
}

# Scope patterns - review these before deploying
$uninstallPattern = 'Web\s?Advisor|SiteAdvisor'
$appxPattern      = 'McAfee'

Write-Log '=== Starting McAfee WebAdvisor removal ==='
if ($WhatIfOnly) { Write-Log 'Running in WhatIfOnly mode - no changes will be made.' 'WARN' }

# ---------------------------------------------------------------------------
# 1. Stop processes
# ---------------------------------------------------------------------------
$procNames = @('McAfeeWebAdvisor','mcafeewebadvisor','uihost','McAPExe','servicehost','McCSPServiceHost')
foreach ($name in $procNames) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Path -match 'McAfee') {
            Write-Log "Stopping process $($_.ProcessName) (PID $($_.Id))"
            if (-not $WhatIfOnly) { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
        }
    }
}

# ---------------------------------------------------------------------------
# 2. AppX: provisioned first, then per-user
# ---------------------------------------------------------------------------
Get-AppxProvisionedPackage -Online |
    Where-Object { $_.DisplayName -match $appxPattern } |
    ForEach-Object {
        Write-Log "Removing provisioned package: $($_.DisplayName)"
        if (-not $WhatIfOnly) {
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -AllUsers -ErrorAction Stop | Out-Null
                Write-Log "  Removed provisioned package: $($_.DisplayName)"
            } catch {
                Write-Log "  FAILED provisioned removal: $($_.Exception.Message)" 'ERROR'
            }
        }
    }

Get-AppxPackage -AllUsers |
    Where-Object { $_.Name -match $appxPattern -or $_.PublisherDisplayName -match $appxPattern } |
    ForEach-Object {
        Write-Log "Removing AppX package: $($_.PackageFullName)"
        if (-not $WhatIfOnly) {
            try {
                Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
                Write-Log "  Removed: $($_.Name)"
            } catch {
                Write-Log "  FAILED AppX removal: $($_.Exception.Message)" 'ERROR'
            }
        }
    }

# ---------------------------------------------------------------------------
# 3. Win32 uninstall
# ---------------------------------------------------------------------------
function Get-WebAdvisorUninstallEntries {
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $roots) {
        # -LiteralPath is required: some vendors (e.g. BeyondTrust Jump Client)
        # register uninstall keys containing [ ] characters, which -Path treats
        # as wildcard character classes. That raises a parameter-binding
        # exception that -ErrorAction cannot suppress and which terminates the
        # enclosing pipeline, silently skipping every key after it.
        $subKeys = Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue
        foreach ($key in $subKeys) {
            try {
                $p = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
            } catch {
                Write-Log "  Could not read uninstall key '$($key.PSChildName)': $($_.Exception.Message)" 'WARN'
                continue
            }
            if ($p.DisplayName -match $uninstallPattern) {
                [pscustomobject]@{
                    DisplayName       = $p.DisplayName
                    KeyName           = $key.PSChildName
                    KeyPath           = $key.PSPath
                    UninstallString   = $p.UninstallString
                    QuietUninstall    = $p.QuietUninstallString
                }
            }
        }
    }
}

# Candidate silent switches, most-likely first. NSIS-based builds take /S;
# InstallShield/MSI-wrapped builds take the others.
$switchCandidates = @('/S', '/silent', '/quiet', '/S /v/qn', '--silent')

foreach ($entry in Get-WebAdvisorUninstallEntries) {
    Write-Log "Found: $($entry.DisplayName)"

    # Prefer the vendor-supplied quiet string if present
    $command = if ($entry.QuietUninstall) { $entry.QuietUninstall } else { $entry.UninstallString }
    if (-not $command) { Write-Log '  No uninstall string present; skipping.' 'WARN'; continue }

    # MSI products: use msiexec directly
    if ($entry.KeyName -match '^\{[0-9A-Fa-f\-]{36}\}$') {
        Write-Log "  MSI product; running msiexec /x $($entry.KeyName) /qn /norestart"
        if (-not $WhatIfOnly) {
            Start-Process msiexec.exe -ArgumentList "/x $($entry.KeyName) /qn /norestart" -Wait -NoNewWindow
        }
        continue
    }

    # Split executable from any baked-in arguments
    if ($command -match '^\s*"([^"]+)"\s*(.*)$') {
        $exe      = $matches[1]
        $baseArgs = $matches[2]
    } elseif ($command -match '^\s*(\S+\.exe)\s*(.*)$') {
        $exe      = $matches[1]
        $baseArgs = $matches[2]
    } else {
        $exe      = $command.Trim()
        $baseArgs = ''
    }

    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Log "  Uninstaller not found on disk: $exe" 'WARN'
        continue
    }

    $removed = $false
    foreach ($sw in $switchCandidates) {
        $argString = ("$baseArgs $sw").Trim()
        Write-Log "  Attempting: `"$exe`" $argString"
        if ($WhatIfOnly) { $removed = $true; break }

        try {
            $proc = Start-Process -FilePath $exe -ArgumentList $argString -Wait -PassThru -NoNewWindow -ErrorAction Stop
            Write-Log "    Exit code: $($proc.ExitCode)"
        } catch {
            Write-Log "    Launch failed: $($_.Exception.Message)" 'WARN'
            continue
        }

        Start-Sleep -Seconds 10

        # Verify: did the uninstall entry actually disappear?
        if (-not (Test-Path -LiteralPath $entry.KeyPath)) {
            Write-Log "    Verified removed with switch '$sw'"
            $removed = $true
            break
        }
        Write-Log "    Registry key still present; trying next switch." 'WARN'
    }

    if (-not $removed) {
        Write-Log "  Could not silently remove $($entry.DisplayName). Consider MCPR fallback." 'ERROR'
    }
}

# ---------------------------------------------------------------------------
# 4. Sweep leftovers
# ---------------------------------------------------------------------------
Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskName -match 'WebAdvisor' -or $_.TaskPath -match 'McAfee' } |
    ForEach-Object {
        Write-Log "Removing scheduled task: $($_.TaskPath)$($_.TaskName)"
        if (-not $WhatIfOnly) {
            Unregister-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

$leftoverPaths = @(
    "$env:ProgramFiles\McAfee\WebAdvisor",
    "${env:ProgramFiles(x86)}\McAfee\WebAdvisor",
    "${env:ProgramFiles(x86)}\McAfee\SiteAdvisor",
    "$env:ProgramData\McAfee\WebAdvisor"
)
foreach ($path in $leftoverPaths) {
    if (Test-Path -LiteralPath $path) {
        Write-Log "Removing leftover folder: $path"
        if (-not $WhatIfOnly) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $path) {
                Write-Log "  Still present (likely file lock) - clears after reboot." 'WARN'
            }
        }
    }
}

Write-Log '=== Removal run complete ==='
exit 0
