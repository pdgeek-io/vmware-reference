param(
    [string]$WindowsLocalIsoPath = $env:WINDOWS_SERVER_2025_LOCAL_ISO_PATH,
    [string]$WindowsIsoVspherePath = $env:WINDOWS_SERVER_2025_ISO_VSPHERE_PATH,
    [string]$ExpectedIsoSha256 = $(if ($env:WINDOWS_SERVER_2025_ISO_SHA256) { $env:WINDOWS_SERVER_2025_ISO_SHA256 } else { 'cf96e924b4e7551169e09ef2a42d81340cdef11eaadf4bd4ac7bf1cdad5178a4' }),
    [string]$ESXiHost = $env:ESXI_HOST,
    [string]$ESXiSshHost = $(if ($env:ESXI_SSH_HOST) { $env:ESXI_SSH_HOST } else { $env:ESXI_HOST }),
    [string]$GuestOsType = $(if ($env:WINDOWS_SERVER_2025_GUEST_OS_TYPE) { $env:WINDOWS_SERVER_2025_GUEST_OS_TYPE } else { 'windows2022srvNext_64Guest' }),
    [string]$FallbackGuestOsType = $(if ($env:WINDOWS_SERVER_2025_FALLBACK_GUEST_OS_TYPE) { $env:WINDOWS_SERVER_2025_FALLBACK_GUEST_OS_TYPE } else { 'windows2019srvNext_64Guest' }),
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

function Split-VsphereDatastorePath {
    param(
        [string]$VspherePath
    )

    if ($VspherePath -notmatch '^\[(?<datastore>[^\]]+)\]\s*(?<relative>.+)$') {
        return @{
            Passed = $false
            Detail = "Path is not a datastore path: $VspherePath"
        }
    }

    return @{
        Passed = $true
        Datastore = $Matches.datastore
        RelativePath = $Matches.relative.TrimStart('/')
    }
}

function Test-VsphereDatastoreFileWithPowerCli {
    param(
        [string]$VspherePath
    )

    $pathParts = Split-VsphereDatastorePath -VspherePath $VspherePath
    if (-not $pathParts.Passed) {
        return $pathParts
    }

    $datastoreName = $pathParts.Datastore
    $relativePath = $pathParts.RelativePath
    $fileName = Split-Path -Path $relativePath -Leaf
    $folder = Split-Path -Path $relativePath -Parent
    $searchRoot = if ([string]::IsNullOrWhiteSpace($folder)) {
        "[$datastoreName]"
    } else {
        "[$datastoreName] $folder"
    }

    $datastore = Get-Datastore -Name $datastoreName -ErrorAction Stop | Select-Object -First 1
    $browser = Get-View -Id $datastore.ExtensionData.Browser
    $spec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
    $spec.MatchPattern = @($fileName)
    $result = $browser.SearchDatastore($searchRoot, $spec)
    $found = $result.File | Where-Object { $_.Path -eq $fileName } | Select-Object -First 1

    return @{
        Passed = [bool]$found
        Detail = $VspherePath
    }
}

function Test-CommandAvailable {
    param(
        [string]$Name
    )

    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-GovcConfigured {
    return (($env:GOVC_URL -and $env:GOVC_USERNAME -and $env:GOVC_PASSWORD) -or
        ($env:VSPHERE_SERVER -and $env:VSPHERE_USER -and $env:VSPHERE_PASSWORD))
}

function Test-ESXiFile {
    param(
        [string]$SshHost,
        [string]$RemotePath
    )

    $sshArgs = @(
        '-o', 'ConnectTimeout=10',
        '-o', 'StrictHostKeyChecking=accept-new'
    )

    $command = "test -f '$RemotePath' && echo present || echo missing"
    if ($env:ESXI_ROOT_PASSWORD) {
        if (-not (Test-CommandAvailable -Name 'sshpass')) {
            return @{
                Passed = $false
                Detail = 'ESXI_ROOT_PASSWORD is set but sshpass is not available.'
            }
        }

        $previousSshpass = $env:SSHPASS
        try {
            $env:SSHPASS = $env:ESXI_ROOT_PASSWORD
            $sshResult = & sshpass -e ssh -o PubkeyAuthentication=no @sshArgs $SshHost $command 2>&1
            return @{
                Passed = ($LASTEXITCODE -eq 0 -and ($sshResult -join "`n") -match 'present')
                Detail = "${SshHost}:${RemotePath}"
            }
        } finally {
            $env:SSHPASS = $previousSshpass
        }
    }

    $sshResult = & ssh @sshArgs $SshHost $command 2>&1
    return @{
        Passed = ($LASTEXITCODE -eq 0 -and ($sshResult -join "`n") -match 'present')
        Detail = "${SshHost}:${RemotePath}"
    }
}

function Set-GovcEnvironmentFromVsphere {
    if (-not $env:GOVC_URL -and $env:VSPHERE_SERVER) {
        $env:GOVC_URL = $env:VSPHERE_SERVER
    }
    if (-not $env:GOVC_USERNAME -and $env:VSPHERE_USER) {
        $env:GOVC_USERNAME = $env:VSPHERE_USER
    }
    if (-not $env:GOVC_PASSWORD -and $env:VSPHERE_PASSWORD) {
        $env:GOVC_PASSWORD = $env:VSPHERE_PASSWORD
    }
    if (-not $env:GOVC_INSECURE) {
        $env:GOVC_INSECURE = 'true'
    }
}

function Test-VsphereDatastoreFileWithGovc {
    param(
        [string]$VspherePath
    )

    $pathParts = Split-VsphereDatastorePath -VspherePath $VspherePath
    if (-not $pathParts.Passed) {
        return $pathParts
    }

    Set-GovcEnvironmentFromVsphere
    $govcResult = & govc datastore.ls -ds $pathParts.Datastore $pathParts.RelativePath 2>&1

    return @{
        Passed = ($LASTEXITCODE -eq 0 -and (($govcResult -join "`n").Trim().Length -gt 0))
        Detail = $VspherePath
    }
}

Write-Host '==> Preflighting Windows Server 2025 template build inputs'

if (-not [string]::IsNullOrWhiteSpace($WindowsLocalIsoPath) -and -not [string]::IsNullOrWhiteSpace($WindowsIsoVspherePath)) {
    Write-Check 'Windows ISO source' $false 'Set either WINDOWS_SERVER_2025_ISO_VSPHERE_PATH or WINDOWS_SERVER_2025_LOCAL_ISO_PATH, not both.'
} elseif (-not [string]::IsNullOrWhiteSpace($WindowsLocalIsoPath)) {
    if (-not (Test-Path -LiteralPath $WindowsLocalIsoPath -PathType Leaf)) {
        Write-Check 'Windows local ISO path' $false "File not found: $WindowsLocalIsoPath"
    } else {
        $actualHash = (Get-FileHash -LiteralPath $WindowsLocalIsoPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $expectedHash = $ExpectedIsoSha256.ToLowerInvariant() -replace '^sha256:', ''
        Write-Check 'Windows local ISO checksum' ($actualHash -eq $expectedHash) "actual sha256:$actualHash"
    }
} elseif (-not [string]::IsNullOrWhiteSpace($WindowsIsoVspherePath)) {
    Write-Host "  [INFO] Windows datastore/content-library ISO path requested: $WindowsIsoVspherePath"
} else {
    Write-Check 'Windows ISO source' $false 'Set WINDOWS_SERVER_2025_ISO_VSPHERE_PATH for pipeline builds or WINDOWS_SERVER_2025_LOCAL_ISO_PATH for manual lab builds.'
}

$expectedHashForInfo = $ExpectedIsoSha256.ToLowerInvariant() -replace '^sha256:', ''
Write-Host "  [INFO] Expected Windows ISO checksum: sha256:$expectedHashForInfo"
Write-Host '  [INFO] Confirmed ISO image names:'
Write-Host '         Windows Server 2025 SERVERSTANDARDCORE'
Write-Host '         Windows Server 2025 SERVERSTANDARD'
Write-Host '         Windows Server 2025 SERVERDATACENTERCORE'
Write-Host '         Windows Server 2025 SERVERDATACENTER'

if (-not [string]::IsNullOrWhiteSpace($ESXiSshHost)) {
    $toolsIsoResult = Test-ESXiFile -SshHost $ESXiSshHost -RemotePath $ProductLockerToolsIso
    Write-Check 'VMware Tools productLocker ISO' $toolsIsoResult.Passed $toolsIsoResult.Detail
} else {
    Write-Host '  [INFO] VMware Tools productLocker ISO check skipped; set ESXI_SSH_HOST to check /usr/lib/vmware/isoimages/windows.iso over SSH.'
}

$hasVsphereCredentials = $env:VSPHERE_SERVER -and $env:VSPHERE_USER -and $env:VSPHERE_PASSWORD
$hasPowerCli = [bool](Get-Module -ListAvailable -Name VMware.PowerCLI)
$canConnectVsphere = $hasVsphereCredentials -or (Test-GovcConfigured)
if ($canConnectVsphere) {
    if (-not ($hasPowerCli -and $hasVsphereCredentials)) {
        if ($WindowsIsoVspherePath -match '^\[[^\]]+\]\s*.+$') {
            if (Test-CommandAvailable -Name 'govc') {
                $isoResult = Test-VsphereDatastoreFileWithGovc -VspherePath $WindowsIsoVspherePath
                Write-Check 'Windows datastore ISO path' $isoResult.Passed $isoResult.Detail
            } else {
                Write-Check 'Windows datastore ISO path' $false 'VMware.PowerCLI is not installed and govc is not available.'
            }
        } elseif (-not [string]::IsNullOrWhiteSpace($WindowsIsoVspherePath)) {
            Write-Host '  [INFO] Windows ISO path does not use datastore syntax. For content-library paths, verify with govc library.ls before building.'
        }

        Write-Host '  [INFO] vSphere guest OS descriptor query skipped; VMware.PowerCLI with VSPHERE_* credentials is not available.'
    } else {
        Import-Module VMware.PowerCLI -ErrorAction Stop
        Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
        $server = Connect-VIServer -Server $env:VSPHERE_SERVER -User $env:VSPHERE_USER -Password $env:VSPHERE_PASSWORD
        try {
            if ($WindowsIsoVspherePath -match '^\[[^\]]+\]\s*.+$') {
                $isoResult = Test-VsphereDatastoreFileWithPowerCli -VspherePath $WindowsIsoVspherePath
                Write-Check 'Windows datastore ISO path' $isoResult.Passed $isoResult.Detail
            } elseif (-not [string]::IsNullOrWhiteSpace($WindowsIsoVspherePath)) {
                Write-Host '  [INFO] Windows ISO path does not use datastore syntax. For content-library paths, verify with govc library.ls before building.'
            }

            if ($ESXiHost) {
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
            } else {
                Write-Host '  [INFO] vSphere guest OS descriptor query skipped; set ESXI_HOST.'
            }
        } finally {
            Disconnect-VIServer -Server $server -Confirm:$false | Out-Null
        }
    }
} else {
    if (-not [string]::IsNullOrWhiteSpace($WindowsIsoVspherePath)) {
        Write-Check 'Windows datastore ISO path' $false 'Set GOVC_URL, GOVC_USERNAME, and GOVC_PASSWORD or VSPHERE_SERVER, VSPHERE_USER, and VSPHERE_PASSWORD so preflight can verify the datastore ISO path.'
    } else {
        Write-Host '  [INFO] vSphere checks skipped; set GOVC_* or VSPHERE_* credentials and ESXI_HOST.'
    }
    Write-Host "  [INFO] Official Windows Server 2025 guest ID to verify: $GuestOsType; fallback to validate if absent: $FallbackGuestOsType."
}

if ($failed) {
    exit 1
}

Write-Host '  [PASS] Windows Server 2025 preflight completed'
