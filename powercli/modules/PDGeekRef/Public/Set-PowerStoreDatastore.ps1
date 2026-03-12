function Set-PowerStoreDatastore {
    <#
    .SYNOPSIS
        Create a PowerStore volume and present it as a VMFS datastore.
    .EXAMPLE
        Set-PowerStoreDatastore -Name "NewDS" -SizeGB 500 -ESXiHost "esxi01.lab.example.com"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [int]$SizeGB,

        [Parameter(Mandatory)]
        [string]$ESXiHost
    )

    Connect-RefEnvironment

    # Create PowerStore volume
    Write-Host "Creating PowerStore volume: $Name ($SizeGB GB)..." -ForegroundColor Cyan
    $body = @{
        name = $Name
        size = $SizeGB * 1073741824
        description = "VMFS datastore volume created by pdgeek.io PDGeekRef module"
    } | ConvertTo-Json

    $volume = Invoke-RestMethod -Uri "https://$($script:PowerStoreEndpoint)/api/version/volume" `
        -Method Post -Headers $script:PowerStoreHeaders -Body $body -SkipCertificateCheck

    Write-Host "  Volume created. WWN: $($volume.wwn)" -ForegroundColor Green

    # Rescan storage on ESXi host
    Write-Host "Rescanning storage on $ESXiHost..." -ForegroundColor Yellow
    $vmHost = Get-VMHost -Name $ESXiHost -ErrorAction Stop
    $vmHost | Get-VMHostStorage -RescanAllHba | Out-Null

    # Create VMFS datastore
    Write-Host "Creating VMFS datastore..." -ForegroundColor Yellow
    $lunPath = $vmHost | Get-ScsiLun | Where-Object { $_.CanonicalName -like "*$($volume.wwn)*" } | Select-Object -First 1
    if ($lunPath) {
        New-Datastore -VMHost $vmHost -Name $Name -Path $lunPath.CanonicalName -Vmfs -ErrorAction Stop | Out-Null
        Write-Host "  Datastore '$Name' created successfully." -ForegroundColor Green
    } else {
        Write-Warning "LUN not found after rescan. You may need to manually rescan or check zoning."
    }
}
