function New-RefVM {
    <#
    .SYNOPSIS
        Deploy a VM from the self-service catalog.
    .DESCRIPTION
        Reads a catalog YAML definition and provisions a VM by cloning from a
        Packer-built template. Optionally provisions PowerStore data volumes.
    .EXAMPLE
        New-RefVM -Name "dev-web-01" -CatalogItem "small-linux" -IPAddress "10.0.200.50"
    .EXAMPLE
        New-RefVM -Name "prod-db-01" -CatalogItem "large-database" -IPAddress "10.0.200.60"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet("small-linux", "medium-linux", "large-database", "windows-standard",
                     "windows-web-server", "windows-database", "windows-app-server", "windows-domain-controller")]
        [string]$CatalogItem,

        [Parameter(Mandatory)]
        [string]$IPAddress,

        [Parameter()]
        [string]$Gateway = "10.0.200.1",

        [Parameter()]
        [string[]]$DNSServers = @("10.0.0.10"),

        [Parameter()]
        [string]$CatalogPath = "$PSScriptRoot/../../self-service/catalog"
    )

    # Ensure connected
    Connect-RefEnvironment

    # Load catalog definition
    $catalogFile = Join-Path $CatalogPath "${CatalogItem}.yml"
    if (-not (Test-Path $catalogFile)) {
        throw "Catalog item not found: $catalogFile"
    }

    # Parse YAML (PowerShell 7+ has ConvertFrom-Yaml via powershell-yaml module)
    $catalog = Get-Content $catalogFile -Raw | ConvertFrom-Yaml

    Write-Host "`n=== Deploying VM from Catalog ===" -ForegroundColor Cyan
    Write-Host "  Name:     $Name"
    Write-Host "  Catalog:  $($catalog.name)"
    Write-Host "  Template: $($catalog.template)"
    Write-Host "  CPU:      $($catalog.compute.cpu) vCPU"
    Write-Host "  Memory:   $($catalog.compute.memory_mb) MB"
    Write-Host "  OS Disk:  $($catalog.storage.os_disk_gb) GB"
    Write-Host "  IP:       $IPAddress"
    Write-Host ""

    # Get template
    $template = Get-Template -Name $catalog.template -ErrorAction Stop

    # Get target objects
    $resourcePool = Get-ResourcePool -Name $catalog.resource_pool -ErrorAction Stop
    $folder = Get-Folder -Name ($catalog.folder -split '/' | Select-Object -Last 1) -Type VM -ErrorAction Stop
    $datastore = Get-Datastore -Name "PowerStore-DS01" -ErrorAction Stop

    # Build OS customization spec
    if ($catalog.os_family -eq "linux") {
        $osSpec = New-OSCustomizationSpec -Name "temp-$Name" -Type NonPersistent `
            -OSType Linux -DnsServer $DNSServers -Domain "lab.example.com" `
            -NamingScheme Fixed -NamingPrefix $Name
        $osSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping `
            -IpMode UseStaticIP -IpAddress $IPAddress -SubnetMask "255.255.255.0" `
            -DefaultGateway $Gateway | Out-Null
    }
    elseif ($catalog.os_family -eq "windows") {
        $osSpec = New-OSCustomizationSpec -Name "temp-$Name" -Type NonPersistent `
            -OSType Windows -FullName "Administrator" -OrgName "lab.example.com" `
            -ChangeSid -AdminPassword $env:WINDOWS_ADMIN_PASSWORD `
            -NamingScheme Fixed -NamingPrefix $Name `
            -DnsServer $DNSServers -Domain "lab.example.com"
        $osSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping `
            -IpMode UseStaticIP -IpAddress $IPAddress -SubnetMask "255.255.255.0" `
            -DefaultGateway $Gateway | Out-Null
    }

    # Clone VM from template
    Write-Host "Cloning VM from template..." -ForegroundColor Yellow
    $vm = New-VM -Name $Name -Template $template -ResourcePool $resourcePool `
        -Datastore $datastore -Location $folder -OSCustomizationSpec $osSpec `
        -ErrorAction Stop

    # Resize CPU/Memory if different from template
    Set-VM -VM $vm -NumCpu $catalog.compute.cpu -MemoryMB $catalog.compute.memory_mb `
        -Confirm:$false | Out-Null

    # Add data disks if specified
    foreach ($disk in $catalog.storage.data_disks) {
        Write-Host "  Adding data disk: $($disk.label) ($($disk.size_gb) GB)" -ForegroundColor Yellow
        New-HardDisk -VM $vm -CapacityGB $disk.size_gb -StorageFormat Thin `
            -Datastore $datastore | Out-Null

        # If PowerStore-backed, create a dedicated volume via REST API
        if ($disk.powerstore_volume) {
            $body = @{
                name        = "${Name}-data"
                size        = $disk.size_gb * 1073741824
                description = $disk.description
            } | ConvertTo-Json

            Invoke-RestMethod -Uri "https://$($script:PowerStoreEndpoint)/api/version/volume" `
                -Method Post -Headers $script:PowerStoreHeaders -Body $body `
                -SkipCertificateCheck | Out-Null
            Write-Host "  PowerStore volume created: ${Name}-data" -ForegroundColor Green
        }
    }

    # Power on
    Write-Host "Powering on VM..." -ForegroundColor Yellow
    Start-VM -VM $vm -Confirm:$false | Out-Null

    # Cleanup temp spec
    if ($osSpec) {
        Remove-OSCustomizationSpec -OSCustomizationSpec "temp-$Name" -Confirm:$false -ErrorAction SilentlyContinue
    }

    Write-Host "`n=== VM Deployed Successfully ===" -ForegroundColor Green
    Write-Host "  Name:  $Name"
    Write-Host "  IP:    $IPAddress"
    Write-Host "  State: Powered On"

    return $vm
}
