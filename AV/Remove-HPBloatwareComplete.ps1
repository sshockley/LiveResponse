<#
.SYNOPSIS
    Silently removes HP bloatware (including HP Wolf Security) and McAfee
    WebAdvisor from a Windows client.

.DESCRIPTION
    Must run in SYSTEM / device context (Live Response, Intune Remediations,
    Configuration Manager). Nothing is shown to the logged-on user: no progress
    bars, no prompts, no reboot. Every external uninstaller runs hidden with a
    silent switch and a timeout, and an EXE uninstaller whose silent switch is
    unknown is skipped and logged rather than launched.

      1. Stop and disable HP telemetry / helper services.
      2. Stop running McAfee WebAdvisor processes so its uninstaller isn't blocked.
      3. Remove provisioned AppX packages FIRST, then per-user packages.
         Reversing this order means the apps return on the next new profile.
      4. Uninstall Win32 programs found in the registry Uninstall keys, in the
         order listed (HP Wolf Security components before HP Security Update
         Service).
      5. Sweep leftover scheduled tasks, folders, and Start menu shortcuts.

    Every removable component is one line in the lists below with a short
    comment naming it. To keep a component, comment out its line. If you keep
    any HP Store app, also comment out the 'AD2F1837.*' catch-all; if you keep
    any HP Wolf component, also comment out the 'HP Wolf Security*' catch-all.

    Logs to C:\ProgramData\Aras\Logs\Remove-HPBloatwareComplete.log

.NOTES
    - Based on https://gist.github.com/mark05e/a79221b4245962a477a49eb281d97388
      and its forks (cloudhal, tomesparon, ll4mat, loopyd, picanl, Teckinfor,
      siuburu).
    - Programs are found by DisplayName in the registry, so every
      version-specific MSI GUID (e.g. the many "HP Wolf Security Application
      Support for Chrome" builds) is covered without hardcoding GUIDs.
    - HP Wolf Security deployed with an uninstall password (Wolf Pro Security /
      managed) will refuse a silent uninstall; that shows up in the log.
    - Never reboots. Exit codes 3010/1641 are logged as "reboot required".
#>

[CmdletBinding()]
param(
    [switch]$WhatIfOnly,

    # Per-uninstaller timeout. A hung (hidden) uninstaller is killed after this.
    [int]$TimeoutMinutes = 20
)

# Re-launch as 64-bit if started from a 32-bit host, otherwise registry
# redirection hides 64-bit uninstall keys.
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $ps64 = "$env:windir\sysnative\WindowsPowerShell\v1.0\powershell.exe"
    $relaunchArgs = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,'-TimeoutMinutes', $TimeoutMinutes)
    if ($WhatIfOnly) { $relaunchArgs += '-WhatIfOnly' }
    & $ps64 @relaunchArgs
    exit $LASTEXITCODE
}

# Suppress every progress bar and confirmation prompt (Remove-AppxPackage etc.)
$ProgressPreference    = 'SilentlyContinue'
$ConfirmPreference     = 'None'
$ErrorActionPreference = 'Continue'

$logDir  = 'C:\ProgramData\Aras\Logs'
$logFile = Join-Path $logDir 'Remove-HPBloatwareComplete.log'
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $logFile -Value $line
    # Write-Host, not Write-Output, so log lines don't pollute function return values
    Write-Host $line
}

# ===========================================================================
# CONFIGURATION - comment out any line to keep that component
# ===========================================================================

# Services to stop and disable. Matched on service Name or DisplayName.
$Services = @(
    'HPAppHelperCap'                   # HP App Helper HSA Service
    'HPDiagsCap'                       # HP Diagnostics HSA Service
    'HPNetworkCap'                     # HP Network HSA Service
    'HPSysInfoCap'                     # HP System Info HSA Service
    'HP Comm Recover'                  # HP Comm Recovery (network recovery helper)
    'HP TechPulse Core'                # HP TechPulse telemetry
    'HpTouchpointAnalyticsService'     # HP Touchpoint Analytics telemetry
    'HPAudioAnalytics'                 # HP Audio Analytics telemetry
    'HP Audio Analytics Service'       # HP Audio Analytics telemetry (alternate name)
    'HP Insights Agent'                # HP Insights telemetry agent
    'HP Insights WatchDog Service'     # HP Insights watchdog
    'hptpsmarthealthservice'           # HP Smart Health telemetry
    'hpsvcsscan'                       # HP Services Scan (silently installs HP apps)
    'SFUService'                       # SFUService (HP helper service listed in upstream script)
    'SecurityUpdateService'            # HP Security Update Service (Wolf / Sure updater)
    #'HotKeyServiceUWP'                # HP Hotkey UWP Service - kept: needed for Fn hotkeys on many models
    #'LanWlanWwanSwitchingServiceUWP'  # HP LAN/WLAN/WWAN Switching - kept: auto Wi-Fi off when docked
)

# McAfee WebAdvisor processes to stop before uninstalling (only if path is under McAfee).
$McAfeeProcesses = @(
    'McAfeeWebAdvisor'                 # WebAdvisor main process
    'UIHost'                           # WebAdvisor UI host
    'ServiceHost'                      # WebAdvisor service host
    'McAPExe'                          # McAfee app helper
    'McCSPServiceHost'                 # McAfee CSP service host
)

# AppX packages (Store apps). Matched with -like against package Name /
# provisioned DisplayName. Provisioned copies are removed first.
$AppxPackages = @(
    'AD2F1837.HPJumpStarts'                     # HP JumpStarts (first-run tour / offers)
    'AD2F1837.HPPCHardwareDiagnosticsWindows'   # HP PC Hardware Diagnostics Windows (Store)
    'AD2F1837.HPPowerManager'                   # HP Power Manager
    'AD2F1837.HPPrivacySettings'                # HP Privacy Settings (telemetry consent)
    'AD2F1837.HPSupportAssistant'               # HP Support Assistant (Store)
    'AD2F1837.HPSureShieldAI'                   # HP Sure Sense / Sure Shield AI UI
    'AD2F1837.HPSystemInformation'              # HP System Information
    'AD2F1837.HPQuickDrop'                      # HP QuickDrop (phone-to-PC transfer)
    'AD2F1837.HPWorkWell'                       # HP WorkWell (wellness reminders)
    'AD2F1837.myHP'                             # myHP
    'AD2F1837.HPDesktopSupportUtilities'        # HP Desktop Support Utilities
    'AD2F1837.HPQuickTouch'                     # HP QuickTouch
    'AD2F1837.HPEasyClean'                      # HP Easy Clean
    'AD2F1837.HPProgrammableKey'                # HP Programmable Key
    'AD2F1837.HPPrinterControl'                 # HP Smart (printer app)
    'AD2F1837.11510256BE195'                    # HP Store app with opaque ID on 2025+ images (from cloudhal fork)
    #'AD2F1837.*'                                # Catch-all: any other HP-published Store app
    #'RealtekSemiconductorCorp.HPAudioControl'   # HP Audio Control (Realtek/B&O tuning UI)
    '*McAfee*'                                  # McAfee consumer Store apps (Personal Security / WebAdvisor)
)

# Win32 programs, uninstalled in this order. Matched with -like against
# DisplayName in the HKLM Uninstall keys (64- and 32-bit).
$Win32Programs = @(
    # --- HP Wolf Security (remove before HP Security Update Service) ---
    'HP Wolf Security'                                     # HP Wolf Security main suite
    'HP Wolf Security - Console'                           # HP Wolf Security local console
    'HP Wolf Security Application Support for Sure Sense'  # Wolf support module: Sure Sense
    'HP Wolf Security Application Support for Windows'     # Wolf support module: Windows
    'HP Wolf Security Application Support for Chrome*'     # Wolf support module: Chrome (many versions)
    'HP Wolf Security*'                                    # Catch-all: any other Wolf component
    'HP Sure Click Security Browser'                       # HP Sure Click isolated browser
    'HP Sure Click'                                        # HP Sure Click (micro-VM isolation)
    'HP Sure Sense Installer'                              # HP Sure Sense installer stub
    'HP Sure Sense'                                        # HP Sure Sense (AI anti-malware)
    'HP Sure Run Module'                                   # HP Sure Run module
    'HP Sure Run'                                          # HP Sure Run (process protection)
    'HP Sure Recover'                                      # HP Sure Recover (network OS recovery agent)
    'HP Client Security Manager'                           # HP Client Security Manager (legacy security suite)
    'HP Device Access Manager'                             # HP Device Access Manager (legacy)
    'HP Security Update Service'                           # HP Security Update Service (Wolf / Sure updater)

    # --- HP telemetry / analytics ---
    'HP Insights'                                          # HP Insights
    'HP Insights Agent'                                    # HP Insights agent
    'HP Insights Analytics'                                # HP Insights analytics
    'HP Insights WatchDog Service'                         # HP Insights watchdog
    'HP Touchpoint Analytics Client'                       # HP Touchpoint Analytics
    'HP System Info HSA Service'                           # HP System Info HSA Service

    # --- HP utilities ---
    'HP Support Assistant'                                 # HP Support Assistant (Win32)
    'HP PC Hardware Diagnostics Windows'                   # HP PC Hardware Diagnostics Windows (Win32)
    'HP Connection Optimizer'                              # HP Connection Optimizer (Wi-Fi tuner)
    'HP Documentation'                                     # HP Documentation (offline manuals)
    'HP Notifications'                                     # HP Notifications (pop-up messages)
    'HP System Default Settings'                           # HP System Default Settings
    'HP MAC Address Manager'                               # HP MAC Address Manager (dock MAC pass-through)
    'HP Audio Control'                                     # HP Audio Control (Win32)
    'Poly Lens'                                            # Poly Lens (HP/Poly headset manager)

    # --- McAfee ---
    '*WebAdvisor*'                                         # McAfee WebAdvisor ("WebAdvisor by McAfee")
    '*SiteAdvisor*'                                        # McAfee SiteAdvisor (older WebAdvisor name)
)

# Scheduled tasks to remove. Matched with -like against "TaskPath + TaskName".
# HP / McAfee tasks whose program no longer exists are also removed afterwards.
$ScheduledTasks = @(
    '\Hewlett-Packard\HP Wolf Security\*'   # HP Wolf Security tasks
    '*\Consent Manager Launcher'            # HP telemetry consent pop-up at logon
    '*Touchpoint*'                          # HP Touchpoint Analytics tasks
    '*HP Insights*'                         # HP Insights tasks
    '*WebAdvisor*'                          # McAfee WebAdvisor tasks
)

# Leftover folders / files to delete.
$LeftoverPaths = @(
    "$env:ProgramFiles\HP\Security Update Service"     # HP Security Update Service leftovers
    "$env:ProgramFiles\McAfee\WebAdvisor"              # McAfee WebAdvisor leftovers
    "${env:ProgramFiles(x86)}\McAfee\WebAdvisor"       # McAfee WebAdvisor leftovers (x86)
    "${env:ProgramFiles(x86)}\McAfee\SiteAdvisor"      # McAfee SiteAdvisor leftovers
    "$env:ProgramData\McAfee\WebAdvisor"               # McAfee WebAdvisor data
    "$env:SystemDrive\Recovery\Customizations\FactoryApps_TU.ppkg"  # HP factory-apps package re-applied by "Reset this PC"
)

# Start menu / public desktop shortcuts (and folders) to delete, by base name.
$Shortcuts = @(
    'HP Documentation'                 # HP Documentation shortcut
    'Miro Offer'                       # Miro trial offer
    'TCO Certified'                    # TCO Certified info link
)

# ===========================================================================
# HELPERS
# ===========================================================================

# Runs a process hidden, waits up to $TimeoutMinutes, returns the exit code
# (or $null if it could not start / was killed).
function Invoke-Silent {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$Arguments,
        [string]$Description = $FilePath,
        [int]$Minutes = $TimeoutMinutes
    )
    Write-Log "  Running: `"$FilePath`" $Arguments"
    if ($WhatIfOnly) { return 0 }

    $spArgs = @{ FilePath = $FilePath; WindowStyle = 'Hidden'; PassThru = $true; ErrorAction = 'Stop' }
    if ($Arguments) { $spArgs.ArgumentList = $Arguments }
    try {
        $proc = Start-Process @spArgs
    } catch {
        Write-Log "  $Description failed to start: $($_.Exception.Message)" 'ERROR'
        return $null
    }
    $null = $proc.Handle   # cache the handle so ExitCode is available after WaitForExit
    if (-not $proc.WaitForExit($Minutes * 60 * 1000)) {
        Write-Log "  $Description still running after $Minutes min; killing it." 'ERROR'
        try { $proc.Kill() } catch {}
        return $null
    }

    $code = $proc.ExitCode
    switch ($code) {
        0       { Write-Log "  $Description succeeded." }
        3010    { Write-Log "  $Description succeeded; reboot required." 'WARN' }
        1641    { Write-Log "  $Description succeeded; reboot required." 'WARN' }
        1605    { Write-Log "  $Description not installed (1605)." }
        1614    { Write-Log "  $Description already uninstalled (1614)." }
        default { Write-Log "  $Description returned exit code $code." 'WARN' }
    }
    return $code
}

function Invoke-MsiUninstall {
    param([string]$ProductCode, [string]$Description)
    # MSIRESTARTMANAGERCONTROL=Disable stops Windows Installer closing the
    # user's apps (e.g. browsers hooked by Sure Click); locked files clear on reboot.
    $msiArgs = "/x $ProductCode /qn /norestart REBOOT=ReallySuppress MSIRESTARTMANAGERCONTROL=Disable"
    for ($i = 1; $i -le 5; $i++) {
        $code = Invoke-Silent -FilePath "$env:windir\System32\msiexec.exe" -Arguments $msiArgs -Description $Description
        if ($code -ne 1618) { return $code }
        Write-Log '  Another installation is in progress (1618); retrying in 30s.' 'WARN'
        Start-Sleep -Seconds 30
    }
    return $code
}

# Splits an uninstall command line into executable and arguments.
function Split-CommandLine {
    param([string]$Command)
    if ($Command -match '^\s*"([^"]+)"\s*(.*)$')               { return $matches[1], $matches[2] }
    if ($Command -match '^\s*(.+?\.(exe|cmd|bat))\s*(.*)$')    { return $matches[1], $matches[3] }
    return $Command.Trim(), ''
}

function Get-UninstallEntries {
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $roots) {
        # -LiteralPath is required: some vendors register uninstall keys
        # containing [ ] characters, which -Path treats as wildcards. That
        # raises a terminating error that skips every key after it.
        foreach ($key in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue) {
            try { $p = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop } catch { continue }
            if (-not $p.DisplayName) { continue }
            [pscustomobject]@{
                DisplayName      = $p.DisplayName
                KeyName          = $key.PSChildName
                KeyPath          = $key.PSPath
                UninstallString  = $p.UninstallString
                QuietUninstall   = $p.QuietUninstallString
                WindowsInstaller = ($p.WindowsInstaller -eq 1)
            }
        }
    }
}

function Uninstall-Win32Entry {
    param($Entry)
    $name = $Entry.DisplayName
    $cmd  = $Entry.UninstallString

    # 1. Windows Installer product: msiexec /x by product code
    $productCode = $null
    if ($cmd -match 'msiexec' -and $cmd -match '\{[0-9A-Fa-f\-]{36}\}') {
        $productCode = $matches[0]
    } elseif ($Entry.WindowsInstaller -and $Entry.KeyName -match '^\{[0-9A-Fa-f\-]{36}\}$') {
        $productCode = $Entry.KeyName
    }
    if ($productCode) { return Invoke-MsiUninstall -ProductCode $productCode -Description $name }

    # 2. Vendor-supplied quiet uninstall string
    if ($Entry.QuietUninstall) {
        $exe, $exeArgs = Split-CommandLine $Entry.QuietUninstall
        return Invoke-Silent -FilePath $exe -Arguments $exeArgs -Description $name
    }

    if (-not $cmd) { Write-Log "  No uninstall string for $name; skipping." 'WARN'; return }
    $exe, $baseArgs = Split-CommandLine $cmd
    if (-not (Test-Path -LiteralPath $exe)) { Write-Log "  Uninstaller not found on disk: $exe" 'WARN'; return }

    # 3. Known EXE uninstallers with known silent switches
    if ($exe -match 'UninstallHPSA\.exe$') {
        # HP Support Assistant
        return Invoke-Silent -FilePath $exe -Arguments '/s /v/qn UninstallKeepPreferences=FALSE' -Description $name
    }

    if ($exe -match 'InstallShield Installation Information\\(\{[0-9A-Fa-f\-]{36}\})\\') {
        # InstallScript setup (e.g. HP Connection Optimizer): needs a response file
        # answering the maintenance dialogs, otherwise -s does nothing.
        $guid = $matches[1]
        $iss  = "$env:windir\Temp\$guid-uninstall.iss"
        $log  = "$env:windir\Temp\$guid-uninstall.log"
        @"
[InstallShield Silent]
Version=v7.00
File=Response File
[File Transfer]
OverwrittenReadOnly=NoToAll
[$guid-DlgOrder]
Dlg0=$guid-SdWelcomeMaint-0
Count=3
Dlg1=$guid-MessageBox-0
Dlg2=$guid-SdFinishReboot-0
[$guid-SdWelcomeMaint-0]
Result=303
[$guid-MessageBox-0]
Result=6
[$guid-SdFinishReboot-0]
Result=1
BootOption=0
"@ | Set-Content -LiteralPath $iss -Encoding ASCII
        if ($baseArgs -notmatch 'removeonly') { $baseArgs = "$baseArgs -removeonly" }
        $code = Invoke-Silent -FilePath $exe -Arguments ("$baseArgs -s -f1`"$iss`" -f2`"$log`"".Trim()) -Description $name
        Remove-Item -LiteralPath $iss -Force -ErrorAction SilentlyContinue
        return $code
    }

    if ($exe -match '\.(cmd|bat)$') {
        # Script uninstaller (e.g. HP Documentation's Doc_Uninstall.cmd)
        return Invoke-Silent -FilePath "$env:windir\System32\cmd.exe" -Arguments "/c `"`"$exe`" $baseArgs`"" -Description $name
    }

    if ($name -match 'WebAdvisor|SiteAdvisor' -or $exe -match '\\McAfee\\') {
        # McAfee does not document silent switches for consumer products and the
        # working one varies by build: try each, verifying the key disappears.
        foreach ($sw in @('/s', '/S', '/silent', '/quiet', '/S /v/qn', '--silent')) {
            $null = Invoke-Silent -FilePath $exe -Arguments ("$baseArgs $sw").Trim() -Description $name -Minutes 5
            if ($WhatIfOnly) { return }
            Start-Sleep -Seconds 10
            if (-not (Test-Path -LiteralPath $Entry.KeyPath)) { return }
        }
        Write-Log "  Could not silently remove $name. Consider MCPR fallback." 'ERROR'
        return
    }

    # 4. Unknown EXE: don't guess, a wrong switch could show UI
    Write-Log "  No known silent switch for '$cmd'; skipped." 'WARN'
}

# ===========================================================================
# MAIN
# ===========================================================================

Write-Log '=== Starting HP bloatware / McAfee WebAdvisor removal ==='
if ($WhatIfOnly) { Write-Log 'Running in WhatIfOnly mode - no changes will be made.' 'WARN' }

# ---------------------------------------------------------------------------
# 1. Services
# ---------------------------------------------------------------------------
$allServices = Get-Service -ErrorAction SilentlyContinue
foreach ($svcName in $Services) {
    foreach ($svc in $allServices | Where-Object { $_.Name -eq $svcName -or $_.DisplayName -eq $svcName }) {
        Write-Log "Stopping and disabling service: $($svc.DisplayName) [$($svc.Name)]"
        if ($WhatIfOnly) { continue }
        Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
        Set-Service  -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# 2. McAfee WebAdvisor processes
# ---------------------------------------------------------------------------
foreach ($procName in $McAfeeProcesses) {
    Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -match '\\McAfee\\' } |
        ForEach-Object {
            Write-Log "Stopping process $($_.ProcessName) (PID $($_.Id))"
            if (-not $WhatIfOnly) { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
        }
}

# ---------------------------------------------------------------------------
# 3. AppX: provisioned first, then per-user
# ---------------------------------------------------------------------------
$provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
foreach ($pattern in $AppxPackages) {
    foreach ($pkg in $provisioned | Where-Object { $_.DisplayName -like $pattern }) {
        Write-Log "Removing provisioned package: $($pkg.DisplayName)"
        if ($WhatIfOnly) { continue }
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -AllUsers -ErrorAction Stop | Out-Null
        } catch {
            Write-Log "  FAILED provisioned removal: $($_.Exception.Message)" 'ERROR'
        }
    }
}

$installed = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
foreach ($pattern in $AppxPackages) {
    foreach ($pkg in $installed | Where-Object { $_.Name -like $pattern }) {
        Write-Log "Removing AppX package: $($pkg.PackageFullName)"
        if ($WhatIfOnly) { continue }
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
        } catch {
            Write-Log "  FAILED AppX removal: $($_.Exception.Message)" 'ERROR'
        }
    }
}

# ---------------------------------------------------------------------------
# 4. Win32 programs, in list order
# ---------------------------------------------------------------------------
$entries = @(Get-UninstallEntries)
$handled = @{}
foreach ($pattern in $Win32Programs) {
    foreach ($entry in $entries | Where-Object { $_.DisplayName -like $pattern }) {
        if ($handled.ContainsKey($entry.KeyPath)) { continue }
        $handled[$entry.KeyPath] = $true

        # An earlier uninstall (e.g. HP Wolf Security) may have removed this one already
        if (-not (Test-Path -LiteralPath $entry.KeyPath)) { continue }

        Write-Log "Uninstalling: $($entry.DisplayName)"
        $null = Uninstall-Win32Entry -Entry $entry
        if (-not $WhatIfOnly -and (Test-Path -LiteralPath $entry.KeyPath)) {
            Write-Log "  Uninstall entry still present for $($entry.DisplayName)." 'WARN'
        }
    }
}

# ---------------------------------------------------------------------------
# 5. Leftovers: scheduled tasks, folders, shortcuts
# ---------------------------------------------------------------------------
foreach ($task in Get-ScheduledTask -ErrorAction SilentlyContinue) {
    $fullName = "$($task.TaskPath)$($task.TaskName)"
    $remove   = [bool]($ScheduledTasks | Where-Object { $fullName -like $_ })

    # Orphaned HP / McAfee task: its program was uninstalled above
    if (-not $remove -and $task.TaskPath -match '^\\(HP|Hewlett-Packard|McAfee)\\') {
        $exec = @($task.Actions | Where-Object { $_.Execute })
        if ($exec.Count -gt 0) {
            # Only full paths count; bare names like cmd.exe are resolved via PATH
            $missing = @($exec | Where-Object {
                $exePath = [Environment]::ExpandEnvironmentVariables($_.Execute.Trim('"'))
                [IO.Path]::IsPathRooted($exePath) -and -not (Test-Path -LiteralPath $exePath)
            })
            $remove = ($missing.Count -eq $exec.Count)
        }
    }
    if (-not $remove) { continue }

    Write-Log "Removing scheduled task: $fullName"
    if (-not $WhatIfOnly) {
        Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction SilentlyContinue
    }
}

foreach ($path in $LeftoverPaths) {
    if (-not (Test-Path -LiteralPath $path)) { continue }
    Write-Log "Removing leftover: $path"
    if ($WhatIfOnly) { continue }
    Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $path) {
        Write-Log '  Still present (likely file lock) - clears after reboot.' 'WARN'
    }
}

$shortcutRoots = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:PUBLIC\Desktop")
foreach ($name in $Shortcuts) {
    Get-ChildItem -LiteralPath $shortcutRoots -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -like "$name*" -and ($_.PSIsContainer -or $_.Extension -in '.lnk', '.url') } |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            if (-not (Test-Path -LiteralPath $_.FullName)) { return }
            Write-Log "Removing shortcut: $($_.FullName)"
            if (-not $WhatIfOnly) { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
        }
}

Write-Log '=== Removal run complete ==='
exit 0
