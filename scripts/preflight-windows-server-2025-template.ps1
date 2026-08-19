param(
    [string]$WindowsIsoPath = $env:WINDOWS_SERVER_2025_ISO_PATH,
    [string]$ExpectedIsoSha256 = $(if ($env:WINDOWS_SERVER_2025_ISO_SHA256) { $env:WINDOWS_SERVER_2025_ISO_SHA256 } else { 'cf96e924b4e7551169e09ef2a42d81340cdef11eaadf4bd4ac7bf1cdad5178a4' }),
    [string]$ESXiHost = $env:ESXI_HOST,
    [string]$GuestOsType = $(if ($env:WINDOWS_SERVER_2025_GUEST_OS_TYPE) { $env:WINDOWS_SERVER_2025_GUEST_OS_TYPE } else { 'windows2022srvNext_64Guest' }),
    [string]$FallbackGuestOsType = $(if ($env:WINDOWS_SERVER_2025_FALLBACK_GUEST_OS_TYPE) { $env:WINDOWS_SERVER_2025_FALLBACK_GUEST_OS_TYPE } else { 'windows2022srv_64Guest' }),
    [string]$ProductLockerToolsIso = $(if ($env:VMWARE_TOOLS_PRODUCTLOCKER_ISO) { $env:VMWARE_TOOLS_PRODUCTLOCKER_ISO } else { '/usr/lib/vmware/isoimages/windows.iso' })
)

$ErrorActionPreference = 'Stop'
$failed = $false

function Write-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail
    )

    if ($Passed) {
        Write-Host "  [PASS] $Name - $Detail"
    } else {
        Write-Host "  [FAIL] $Name - $Detail"
        $script:failed = $true
    }
}

Write-Host '==> Preflighting Windows Server 2025 template build inputs'

if ([string]::IsNullOrWhiteSpace($WindowsIsoPath)) {
    Write-Check 'Windows ISO path' $false 'Set WINDOWS_SERVER_2025_ISO_PATH to the local ISO path before building.'
} elseif (-not (Test-Path -LiteralPath $WindowsIsoPath -PathType Leaf)) {
    Write-Check 'Windows ISO path' $false "File not found: $WindowsIsoPath"
} else {
    $actualHash = (Get-FileHash -LiteralPath $WindowsIsoPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = $ExpectedIsoSha256.ToLowerInvariant() -replace '^sha256:', ''
    Write-Check 'Windows ISO checksum' ($actualHash -eq $expectedHash) "actual sha256:$actualHash"
}

Write-Host '  [INFO] Confirmed ISO image names:'
Write-Host '         Windows Server 2025 SERVERSTANDARDCORE'
Write-Host '         Windows Server 2025 SERVERSTANDARD'
Write-Host '         Windows Server 2025 SERVERDATACENTERCORE'
Write-Host '         Windows Server 2025 SERVERDATACENTER'

if (-not [string]::IsNullOrWhiteSpace($ESXiHost)) {
    $sshResult = & ssh $ESXiHost "test -f '$ProductLockerToolsIso' && echo present || echo missing" 2>&1
    Write-Check 'VMware Tools productLocker ISO' ($LASTEXITCODE -eq 0 -and ($sshResult -join "`n") -match 'present') "${ESXiHost}:${ProductLockerToolsIso}"
} else {
    Write-Host '  [INFO] VMware Tools productLocker ISO check skipped; set ESXI_HOST to check /usr/lib/vmware/isoimages/windows.iso over SSH.'
}

$canCheckGuestOs = $env:VSPHERE_SERVER -and $env:VSPHERE_USER -and $env:VSPHERE_PASSWORD -and $ESXiHost
if ($canCheckGuestOs) {
    if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
        Write-Check 'vSphere guest OS descriptor query' $false 'VMware.PowerCLI is not installed.'
    } else {
        Import-Module VMware.PowerCLI -ErrorAction Stop
        Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
        $server = Connect-VIServer -Server $env:VSPHERE_SERVER -User $env:VSPHERE_USER -Password $env:VSPHERE_PASSWORD
        try {
            $vmHost = Get-VMHost -Name $ESXiHost
            $computeResource = Get-View -Id $vmHost.ExtensionData.Parent
            $environmentBrowser = Get-View -Id $computeResource.ConfigManager.EnvironmentBrowser
            $vmxVersion = ($environmentBrowser.QueryConfigOptionDescriptor() | Where-Object DefaultConfigOption).Key
            $descriptors = $environmentBrowser.QueryConfigOption($vmxVersion, $null).GuestOSDescriptor
            $supportedIds = $descriptors | Select-Object -ExpandProperty Id

            if ($supportedIds -contains $GuestOsType) {
                Write-Check 'Windows Server 2025 guest_os_type' $true "$GuestOsType is supported by $ESXiHost for $vmxVersion."
            } elseif ($supportedIds -contains $FallbackGuestOsType) {
                Write-Check 'Windows Server 2025 guest_os_type' $false "$GuestOsType is unavailable; fallback $FallbackGuestOsType is available but must be explicitly validated."
            } else {
                Write-Check 'Windows Server 2025 guest_os_type' $false "Neither $GuestOsType nor $FallbackGuestOsType is listed for $ESXiHost."
            }
        } finally {
            Disconnect-VIServer -Server $server -Confirm:$false | Out-Null
        }
    }
} else {
    Write-Host '  [INFO] vSphere guest OS descriptor query skipped; set VSPHERE_SERVER, VSPHERE_USER, VSPHERE_PASSWORD, and ESXI_HOST.'
    Write-Host "  [INFO] Official Windows Server 2025 guest ID to verify: $GuestOsType; fallback to validate if absent: $FallbackGuestOsType."
}

if ($failed) {
    exit 1
}

Write-Host '  [PASS] Windows Server 2025 preflight completed'
