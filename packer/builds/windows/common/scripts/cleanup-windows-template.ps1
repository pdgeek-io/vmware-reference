# Clean and minimize Windows Server before Sysprep/template conversion.
#
# This intentionally stays conservative: remove consumer/provisioned app bloat
# when present, disable services that are not expected on base server templates,
# clear transient build artifacts, and write evidence for downstream review.
$ErrorActionPreference = "Stop"

Write-Host "==> Starting Windows template cleanup..."

$evidenceDir = "C:\ProgramData\PDGeek\TemplateHardening"
$evidenceFile = Join-Path $evidenceDir "windows-template-cleanup.json"
New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null

$removedCapabilities = @()
$removedAppxPackages = @()
$disabledServices = @()
$disabledFeatures = @()
$removedGhostNetworkDevices = @()
$removedNetworkProfiles = @()

Write-Host "==> Removing optional Windows capabilities when present..."
$capabilityPatterns = @(
    "App.StepsRecorder*",
    "Browser.InternetExplorer*",
    "Hello.Face*",
    "MathRecognizer*",
    "Media.WindowsMediaPlayer*",
    "OneCoreUAP.OneSync*",
    "Print.Fax.Scan*"
)
foreach ($pattern in $capabilityPatterns) {
    Get-WindowsCapability -Online |
        Where-Object { $_.Name -like $pattern -and $_.State -eq "Installed" } |
        ForEach-Object {
            Write-Host "  Removing capability $($_.Name)"
            Remove-WindowsCapability -Online -Name $_.Name -ErrorAction SilentlyContinue | Out-Null
            $removedCapabilities += $_.Name
        }
}

Write-Host "==> Removing provisioned consumer AppX packages when present..."
$appxPatterns = @(
    "*Bing*",
    "*Clipchamp*",
    "*Consumer*",
    "*GetHelp*",
    "*Getstarted*",
    "*MicrosoftTeams*",
    "*MixedReality*",
    "*News*",
    "*OfficeHub*",
    "*People*",
    "*SkypeApp*",
    "*Solitaire*",
    "*Todos*",
    "*Wallet*",
    "*Weather*",
    "*Xbox*",
    "*Zune*"
)
foreach ($pattern in $appxPatterns) {
    Get-AppxProvisionedPackage -Online |
        Where-Object { $_.DisplayName -like $pattern } |
        ForEach-Object {
            Write-Host "  Removing provisioned package $($_.DisplayName)"
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
            $removedAppxPackages += $_.DisplayName
        }
}

Write-Host "==> Disabling optional server features when present..."
$featureNames = @(
    "FaxServicesClientPackage",
    "Printing-XPSServices-Features",
    "WorkFolders-Client"
)
foreach ($featureName in $featureNames) {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName -ErrorAction SilentlyContinue
    if ($feature -and $feature.State -eq "Enabled") {
        Write-Host "  Disabling feature ${featureName}"
        Disable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart -ErrorAction SilentlyContinue | Out-Null
        $disabledFeatures += $featureName
    }
}

Write-Host "==> Disabling nonessential base-template services when present..."
$serviceNames = @(
    "DiagTrack",
    "MapsBroker",
    "RetailDemo",
    "SharedAccess",
    "WerSvc",
    "WMPNetworkSvc",
    "XblAuthManager",
    "XblGameSave",
    "XboxGipSvc",
    "XboxNetApiSvc"
)
foreach ($serviceName in $serviceNames) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "  Disabling service ${serviceName}"
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
        $disabledServices += $serviceName
    }
}

Write-Host "==> Removing ghost NICs and stale network profiles..."
Get-PnpDevice -Class Net -ErrorAction SilentlyContinue |
    Where-Object { $_.Status -eq "Unknown" -or $_.Present -eq $false } |
    ForEach-Object {
        Write-Host "  Removing ghost network device $($_.InstanceId)"
        pnputil /remove-device $_.InstanceId 2>$null | Out-Null
        $removedGhostNetworkDevices += $_.InstanceId
    }

Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles" -ErrorAction SilentlyContinue |
    ForEach-Object {
        $profileName = (Get-ItemProperty -Path $_.PsPath -ErrorAction SilentlyContinue).ProfileName
        Write-Host "  Removing stale network profile ${profileName}"
        Remove-Item -Path $_.PsPath -Recurse -Force -ErrorAction SilentlyContinue
        $removedNetworkProfiles += $profileName
    }

Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\Unmanaged" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\NetworkSetup2\Interfaces" -ErrorAction SilentlyContinue |
    Where-Object {
        $properties = Get-ItemProperty -Path $_.PsPath -ErrorAction SilentlyContinue
        $properties.PnpInstanceID -and -not (Get-PnpDevice -InstanceId $properties.PnpInstanceID -ErrorAction SilentlyContinue)
    } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "==> Clearing transient build artifacts..."
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Panther\UnattendGC\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\System32\Sysprep\Panther\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "==> Clearing event logs..."
wevtutil el | ForEach-Object {
    wevtutil cl "$_" 2>$null
}

Write-Host "==> Reclaiming component store where supported..."
Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null

$evidence = [ordered]@{
    cleanup              = "windows-template-cleanup"
    managed_by           = "VMware Automation"
    removedCapabilities  = $removedCapabilities
    removedAppxPackages  = $removedAppxPackages
    disabledFeatures     = $disabledFeatures
    disabledServices     = $disabledServices
    ghostNetworkDevices  = $removedGhostNetworkDevices
    staleNetworkProfiles = $removedNetworkProfiles
    artifactCleanup      = "enabled"
    componentStoreRebase = "enabled"
    sysprepRequired      = $true
}
$evidence | ConvertTo-Json -Depth 5 | Set-Content -Path $evidenceFile -Encoding UTF8
Write-Host "==> Windows template cleanup evidence written to ${evidenceFile}"
