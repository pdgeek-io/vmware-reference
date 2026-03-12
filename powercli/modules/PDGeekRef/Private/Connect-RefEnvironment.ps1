function Connect-RefEnvironment {
    <#
    .SYNOPSIS
        Establishes connections to vCenter and PowerStore for the reference lab.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$VCenterServer = $env:VSPHERE_SERVER,

        [Parameter()]
        [string]$VCenterUser = $env:VSPHERE_USER,

        [Parameter()]
        [string]$VCenterPassword = $env:VSPHERE_PASSWORD,

        [Parameter()]
        [string]$PowerStoreEndpoint = $env:POWERSTORE_ENDPOINT,

        [Parameter()]
        [string]$PowerStoreUser = $env:POWERSTORE_USERNAME,

        [Parameter()]
        [string]$PowerStorePassword = $env:POWERSTORE_PASSWORD
    )

    # Connect to vCenter
    if (-not $global:DefaultVIServer -or -not $global:DefaultVIServer.IsConnected) {
        Write-Host "Connecting to vCenter: $VCenterServer" -ForegroundColor Cyan
        $securePwd = ConvertTo-SecureString $VCenterPassword -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential($VCenterUser, $securePwd)
        Connect-VIServer -Server $VCenterServer -Credential $cred -ErrorAction Stop | Out-Null
        Write-Host "  Connected to vCenter." -ForegroundColor Green
    }

    # Store PowerStore connection info in script scope
    $script:PowerStoreEndpoint = $PowerStoreEndpoint
    $script:PowerStoreAuth = [Convert]::ToBase64String(
        [Text.Encoding]::ASCII.GetBytes("${PowerStoreUser}:${PowerStorePassword}")
    )
    $script:PowerStoreHeaders = @{
        "Authorization" = "Basic $($script:PowerStoreAuth)"
        "Content-Type"  = "application/json"
    }

    Write-Host "  PowerStore endpoint configured: $PowerStoreEndpoint" -ForegroundColor Green
}
