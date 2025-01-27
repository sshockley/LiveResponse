#  ██████╗ ███████╗███╗   ███╗ ██████╗ ██╗   ██╗███████╗    ██╗  ██╗██████╗    
#  ██╔══██╗██╔════╝████╗ ████║██╔═══██╗██║   ██║██╔════╝    ██║  ██║██╔══██╗   
#  ██████╔╝█████╗  ██╔████╔██║██║   ██║██║   ██║█████╗      ███████║██████╔╝   
#  ██╔══██╗██╔══╝  ██║╚██╔╝██║██║   ██║╚██╗ ██╔╝██╔══╝      ██╔══██║██╔═══╝    
#  ██║  ██║███████╗██║ ╚═╝ ██║╚██████╔╝ ╚████╔╝ ███████╗    ██║  ██║██║        
#  ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝    ╚═╝  ╚═╝╚═╝        
#                                                                              
#  ██████╗ ██╗      ██████╗  █████╗ ████████╗██╗    ██╗ █████╗ ██████╗ ███████╗
#  ██╔══██╗██║     ██╔═══██╗██╔══██╗╚══██╔══╝██║    ██║██╔══██╗██╔══██╗██╔════╝
#  ██████╔╝██║     ██║   ██║███████║   ██║   ██║ █╗ ██║███████║██████╔╝█████╗  
#  ██╔══██╗██║     ██║   ██║██╔══██║   ██║   ██║███╗██║██╔══██║██╔══██╗██╔══╝  
#  ██████╔╝███████╗╚██████╔╝██║  ██║   ██║   ╚███╔███╔╝██║  ██║██║  ██║███████╗
#  ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝    ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝
#                                                                              
#   Remove HP bloatware / crapware - BETA version
#  
# -- source : https://gist.github.com/mark05e/a79221b4245962a477a49eb281d97388
# -- contrib: francishagyard2, mark05E, erottier, JoachimBerghmans, sikkepitje, Ithendyr
# -- note   : this script could use your improvements. contributions welcome!

# List of built-in apps to remove
$UninstallPackages = @(
    "AD2F1837.HPJumpStarts"
    "AD2F1837.HPPCHardwareDiagnosticsWindows"
    "AD2F1837.HPPowerManager"
    "AD2F1837.HPPrivacySettings"
    "AD2F1837.HPSupportAssistant"
    "AD2F1837.HPSureShieldAI"
    "AD2F1837.HPSystemInformation"
    "AD2F1837.HPQuickDrop"
    "AD2F1837.HPWorkWell"
    "AD2F1837.myHP"
    "AD2F1837.HPDesktopSupportUtilities"
    "AD2F1837.HPQuickTouch"
    "AD2F1837.HPEasyClean"
    "AD2F1837.HPSystemInformation"
)

# List of programs to uninstall
$UninstallPrograms = @(
	"HP Touchpoint Analytics"
	"HPAudioAnalytics"
	"HP Audio Analytics Service"
    "HP Device Access Manager"
    "HP Client Security Manager"
    "HP Connection Optimizer"
    "HP Documentation"
    "HP MAC Address Manager"
    "HP Notifications"
    "HP System Info HSA Service"
    "HP Security Update Service"
    "HP System Default Settings"
    "HP Sure Click"
    "HP Sure Click Security Browser"
    "HP Sure Run"
    "HP Sure Run Module"
    "HP Sure Recover"
    "HP Sure Sense"
    "HP Sure Sense Installer"
    "HP Wolf Security"
    "HP Wolf Security - Console"
    "HP Wolf Security Application Support for Sure Sense"
    "HP Wolf Security Application Support for Windows"
)

$HPidentifier = "AD2F1837"

$InstalledPackages = Get-AppxPackage -AllUsers `
            | Where-Object {($UninstallPackages -contains $_.Name) -or ($_.Name -match "^$HPidentifier")}

$ProvisionedPackages = Get-AppxProvisionedPackage -Online `
            | Where-Object {($UninstallPackages -contains $_.DisplayName) -or ($_.DisplayName -match "^$HPidentifier")}

$InstalledPrograms = Get-Package | Where-Object {$UninstallPrograms -contains $_.Name}

# Stop HP Services
Function StopDisableService($name) {
    if (Get-Service -Name $name -ea SilentlyContinue) {
        Stop-Service -Name $name -Force -Confirm:$False
        Set-Service -Name $name -StartupType Disabled
    }
}

StopDisableService -name "HotKeyServiceUWP"
StopDisableService -name "HPAppHelperCap"
StopDisableService -name "HP Comm Recover"
StopDisableService -name "HPDiagsCap"
StopDisableService -name "HotKeyServiceUWP"
#StopDisableService -name "LanWlanWwanSwitchgingServiceUWP" # do we need to stop this?
StopDisableService -name "HPNetworkCap"
StopDisableService -name "HPSysInfoCap"
StopDisableService -name "HP TechPulse Core"
StopDisableService -name "HpTouchpointAnalyticsService"
StopDisableService -name "SFUService"
StopDisableService -name "HPAudioAnalytics"
StopDisableService -name "SecurityUpdateService"
StopDisableService -name "hpsvcsscan"
StopDisableService -name "HPAudioAnalytics"
StopDisableService -name "SFUService"
StopDisableService -name "HPSysInfoCap"
StopDisableService -name "hptpsmarthealthservice"

#Remove-Service -name "SecurityUpdateService"
#Stop-Process -Name "HP.myHP.exe" -Force

# Remove installed programs
$InstalledPrograms | ForEach-Object {

  Write-Host -Object "Attempting to uninstall: [$($_.Name)]..."

  Try {
      $Null = $_ | Uninstall-Package -AllVersions -Force -ErrorAction Stop
      Write-Host -Object "Successfully uninstalled: [$($_.Name)]"
  }
  Catch {
    Write-Warning -Message "Failed to uninstall: [$($_.Name)]"
    
    Write-Host -Object "Attempting to uninstall as MSI package: [$($_.Name)]..."
    Try {
      $product = Get-WmiObject win32_product | where { $_.name -like "$($_.Name)" }
      if ($_ -ne $null) {
        msiexec /x $product.IdentifyingNumber /quiet /noreboot
      }
      else { Write-Warning -Message "Can't find MSI package: [$($_.Name)]" }
    }
    Catch { Write-Warning -Message "Failed to uninstall MSI package: [$($_.Name)]" }
    }
}

# Fallback attempt 1 to remove HP Wolf Security using msiexec
Try {
    MsiExec /x "{0E2E04B0-9EDD-11EB-B38C-10604B96B11E}" /qn /norestart
    Write-Host -Object "Fallback to MSI uninistall for HP Wolf Security initiated"
}
Catch {
    Write-Warning -Object "Failed to uninstall HP Wolf Security using MSI - Error message: $($_.Exception.Message)"
}

# Fallback attempt 2 to remove HP Wolf Security using msiexec
Try {
    MsiExec /x "{4DA839F0-72CF-11EC-B247-3863BB3CB5A8}" /qn /norestart
    Write-Host -Object "Fallback to MSI uninistall for HP Wolf 2 Security initiated"
}
Catch {
    Write-Warning -Object  "Failed to uninstall HP Wolf Security 2 using MSI - Error message: $($_.Exception.Message)"
}

# Uninstall HP Wolf Security Application Support for Chrome
Try {
	MsiExec /x "{B05FF260-E8D9-437D-9C02-04A23AC5E8F9}" /qn /norestart
	MsiExec /x "{1CAA9714-DDCF-4D91-B1E6-D7E98628883F}" /qn /norestart
	MsiExec /x "{AA5BFBE6-BDD8-4383-9C46-0DB84FE59A20}" /qn /norestart
	MsiExec /x "{567C0987-AC45-4E4C-ADDF-C8A611C15DA1}" /qn /norestart
	MsiExec /x "{9CE00609-C9E6-4241-B327-52E47302DD23}" /qn /norestart
    MsiExec /x "{665CC439-C0CF-45ED-97AE-B8D6FA32020E}" /qn /norestart
	MsiExec /x "{ECE0A1EF-4AF5-469E-9CB8-29FCFAE6BA1D}" /qn /norestart
	MsiExec /x "{AF1426F4-B847-4EF0-B8E0-B37B49FE93C2}" /qn /norestart
	MsiExec /x "{ECE0A1EF-4AF5-469E-9CB8-29FCFAE6BA1D}" /qn /norestart
	MsiExec /x "{8A8FEEA3-21F4-417E-AD07-F4F353C846CE}" /qn /norestart
	MsiExec /x "{64840480-3A21-11EF-A510-3863BB3CB5A8}" /qn /norestart
	MsiExec /x "{941D3468-6121-450A-8A44-CAC267B0ED42}" /qn /norestart
	MsiExec /x "{BD1E4726-7D5C-4E27-B6BF-36B59F0C3708}" /qn /norestart
	MsiExec /x "{8A8FEEA3-21F4-417E-AD07-F4F353C846CE}" /qn /norestart
	MsiExec /x "{9425676F-7DBD-40A1-8033-BAC0A9E67101}" /qn /norestart
	MsiExec /x "{9D695330-183A-11EF-AC7E-3863BB3CB5A8}" /qn /norestart
	MsiExec /x "{727F12C9-4D97-4F23-8451-927D1DE8E58C}" /qn /norestart
	MsiExec /x "{A34EDE79-0A76-409F-B258-FF5D1CAE6B8F}" /qn /norestart
	MsiExec /x "{68E3C76B-6FC8-4993-A424-A92FD5A5F3FB}" /qn /norestart
	MsiExec /x "{534705EB-028B-4330-8DE5-1BC7C7A0A7B8}" /qn /norestart
	Write-Host -Object "Fallback to MSI uninistall for HP Wolf Security Application Support for Chrome"
}
Catch {
    Write-Warning -Object  "Failed to uninstall HP Wolf Security Application Support for Chrome using MSI - Error message: $($_.Exception.Message)"
}


# Remove appx provisioned packages - AppxProvisionedPackage
ForEach ($ProvPackage in $ProvisionedPackages) {

    Write-Host -Object "Attempting to remove provisioned package: [$($ProvPackage.DisplayName)]..."

    Try {
        $Null = Remove-AppxProvisionedPackage -PackageName $ProvPackage.PackageName -Online -ErrorAction Stop
        Write-Host -Object "Successfully removed provisioned package: [$($ProvPackage.DisplayName)]"
    }
    Catch {Write-Warning -Message "Failed to remove provisioned package: [$($ProvPackage.DisplayName)]"}
}

# Remove appx packages - AppxPackage
ForEach ($AppxPackage in $InstalledPackages) {
                                            
    Write-Host -Object "Attempting to remove Appx package: [$($AppxPackage.Name)]..."

    Try {
        $Null = Remove-AppxPackage -Package $AppxPackage.PackageFullName -AllUsers -ErrorAction Stop
        Write-Host -Object "Successfully removed Appx package: [$($AppxPackage.Name)]"
    }
    Catch {Write-Warning -Message "Failed to remove Appx package: [$($AppxPackage.Name)]"}
}

# Uncomment this section to see what is left behind
Write-Host "Checking stuff after running script"
Write-Host "For Get-AppxPackage -AllUsers"
Get-AppxPackage -AllUsers | where {$_.Name -like "*HP*"}
Write-Host "For Get-AppxProvisionedPackage -Online"
Get-AppxProvisionedPackage -Online | where {$_.DisplayName -like "*HP*"}
Write-Host "For Get-Package"
Get-Package | select Name, FastPackageReference, ProviderName, Summary | Where {$_.Name -like "*HP*"} | Where {$_.Summary -notlike "*driver update*"} | Format-List

Write-Host Try to force-remove some packages by deleting
rm -Recurse -Force "c:\Recovery\Customizations\FactoryApps_TU.ppkg"
rm -Recurse -Force "c:\program files\hp\security update service"

# Feature - Ask for reboot after running the script
# $input = Read-Host "Restart computer now [y/n]"
# switch($input){
          # y{Restart-computer -Force -Confirm:$false}
          # n{exit}
    # default{write-warning "Skipping reboot."}
# }

Write-Output "Finished."