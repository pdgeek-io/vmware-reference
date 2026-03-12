function Get-VMChargeback {
    <#
    .SYNOPSIS
        Generate chargeback/showback reports for VMs by department, project, or folder.
    .DESCRIPTION
        Pulls vCenter metrics (CPU, memory, storage) for all VMs and calculates costs
        based on configurable rates. Uses vSphere tags for cost center assignment.
        Outputs per-VM and per-department summaries.
    .EXAMPLE
        Get-VMChargeback
    .EXAMPLE
        Get-VMChargeback -Department "Engineering" -OutputFormat CSV -OutputPath ./reports/
    .EXAMPLE
        Get-VMChargeback -DateRange 30 -ShowSummaryOnly
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Department,

        [Parameter()]
        [string]$Project,

        [Parameter()]
        [ValidateSet("Table", "CSV", "JSON")]
        [string]$OutputFormat = "Table",

        [Parameter()]
        [string]$OutputPath = "./chargeback/reports",

        [Parameter()]
        [int]$DateRange = 30,

        [Parameter()]
        [switch]$ShowSummaryOnly,

        [Parameter()]
        [string]$RateConfigPath = "./chargeback/templates/rates.yml"
    )

    Connect-RefEnvironment

    # Load cost rates
    $defaultRates = @{
        CpuPerVCpuMonth    = 15.00   # $ per vCPU per month
        MemoryPerGBMonth   = 5.00    # $ per GB RAM per month
        StoragePerGBMonth  = 0.10    # $ per GB disk per month
        PowerStorePerGBMonth = 0.15  # $ per GB PowerStore-backed disk per month
        NetworkPerVNICMonth = 2.00   # $ per vNIC per month
    }

    if (Test-Path $RateConfigPath) {
        $customRates = Get-Content $RateConfigPath -Raw | ConvertFrom-Yaml
        foreach ($key in $customRates.Keys) {
            $defaultRates[$key] = $customRates[$key]
        }
    }

    $rates = $defaultRates

    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        pdgeek.io — Chargeback / Showback Report            ║" -ForegroundColor Cyan
    Write-Host "║        Period: Last $DateRange days                                  ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # Get all VMs (filter by department tag if specified)
    $allVMs = Get-VM
    if ($Department) {
        $tagCategory = Get-TagCategory -Name "Department" -ErrorAction SilentlyContinue
        if ($tagCategory) {
            $tag = Get-Tag -Category $tagCategory -Name $Department -ErrorAction SilentlyContinue
            if ($tag) {
                $allVMs = $allVMs | Where-Object {
                    ($_ | Get-TagAssignment -Category $tagCategory).Tag.Name -eq $Department
                }
            }
        }
    }

    if ($Project) {
        $tagCategory = Get-TagCategory -Name "Project" -ErrorAction SilentlyContinue
        if ($tagCategory) {
            $tag = Get-Tag -Category $tagCategory -Name $Project -ErrorAction SilentlyContinue
            if ($tag) {
                $allVMs = $allVMs | Where-Object {
                    ($_ | Get-TagAssignment -Category $tagCategory).Tag.Name -eq $Project
                }
            }
        }
    }

    # Calculate costs per VM
    $chargebackData = @()
    foreach ($vm in $allVMs) {
        $disks = Get-HardDisk -VM $vm
        $totalDiskGB = ($disks | Measure-Object -Property CapacityGB -Sum).Sum
        $vmNics = Get-NetworkAdapter -VM $vm

        # Check if VM is on a PowerStore datastore
        $datastore = Get-Datastore -VM $vm | Select-Object -First 1
        $isPowerStore = $datastore.Name -like "PowerStore*"
        $storageRate = if ($isPowerStore) { $rates.PowerStorePerGBMonth } else { $rates.StoragePerGBMonth }

        # Get tags for cost center tracking
        $deptTag = ($vm | Get-TagAssignment -Category "Department" -ErrorAction SilentlyContinue).Tag.Name
        $projTag = ($vm | Get-TagAssignment -Category "Project" -ErrorAction SilentlyContinue).Tag.Name
        $ownerTag = ($vm | Get-TagAssignment -Category "Owner" -ErrorAction SilentlyContinue).Tag.Name

        # Calculate monthly cost
        $cpuCost = $vm.NumCpu * $rates.CpuPerVCpuMonth
        $memCost = $vm.MemoryGB * $rates.MemoryPerGBMonth
        $storageCost = $totalDiskGB * $storageRate
        $networkCost = $vmNics.Count * $rates.NetworkPerVNICMonth
        $totalCost = $cpuCost + $memCost + $storageCost + $networkCost

        # Get average CPU/memory usage over the period
        $cpuStat = Get-Stat -Entity $vm -Stat "cpu.usage.average" -Start (Get-Date).AddDays(-$DateRange) -ErrorAction SilentlyContinue |
            Measure-Object -Property Value -Average
        $memStat = Get-Stat -Entity $vm -Stat "mem.usage.average" -Start (Get-Date).AddDays(-$DateRange) -ErrorAction SilentlyContinue |
            Measure-Object -Property Value -Average

        $chargebackData += [PSCustomObject]@{
            VMName          = $vm.Name
            PowerState      = $vm.PowerState
            Department      = $deptTag ?? "Unassigned"
            Project         = $projTag ?? "Unassigned"
            Owner           = $ownerTag ?? "Unassigned"
            vCPU            = $vm.NumCpu
            MemoryGB        = $vm.MemoryGB
            StorageGB       = [math]::Round($totalDiskGB, 1)
            StorageTier     = if ($isPowerStore) { "PowerStore" } else { "Standard" }
            AvgCpuPct       = [math]::Round($cpuStat.Average, 1)
            AvgMemPct       = [math]::Round($memStat.Average, 1)
            CpuCost         = [math]::Round($cpuCost, 2)
            MemoryCost      = [math]::Round($memCost, 2)
            StorageCost     = [math]::Round($storageCost, 2)
            NetworkCost     = [math]::Round($networkCost, 2)
            MonthlyTotal    = [math]::Round($totalCost, 2)
            Folder          = $vm.Folder.Name
            Datastore       = $datastore.Name
        }
    }

    # Department summary
    if (-not $ShowSummaryOnly) {
        Write-Host "`n── Per-VM Breakdown ──" -ForegroundColor Yellow
        $chargebackData | Sort-Object Department, VMName |
            Format-Table VMName, Department, Project, vCPU, MemoryGB, StorageGB, StorageTier, MonthlyTotal -AutoSize
    }

    Write-Host "── Department Summary ──" -ForegroundColor Yellow
    $deptSummary = $chargebackData | Group-Object Department | ForEach-Object {
        [PSCustomObject]@{
            Department  = $_.Name
            VMCount     = $_.Count
            TotalvCPU   = ($_.Group | Measure-Object vCPU -Sum).Sum
            TotalMemGB  = ($_.Group | Measure-Object MemoryGB -Sum).Sum
            TotalDiskGB = [math]::Round(($_.Group | Measure-Object StorageGB -Sum).Sum, 1)
            MonthlyCost = [math]::Round(($_.Group | Measure-Object MonthlyTotal -Sum).Sum, 2)
        }
    }
    $deptSummary | Sort-Object MonthlyCost -Descending | Format-Table -AutoSize

    $grandTotal = ($chargebackData | Measure-Object MonthlyTotal -Sum).Sum
    Write-Host "  Grand Total: `$$([math]::Round($grandTotal, 2)) / month" -ForegroundColor Green
    Write-Host "  VMs Tracked: $($chargebackData.Count)" -ForegroundColor Green

    # Export
    if ($OutputFormat -ne "Table") {
        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
        $filename = "chargeback-${timestamp}"

        switch ($OutputFormat) {
            "CSV" {
                $filePath = Join-Path $OutputPath "${filename}.csv"
                $chargebackData | Export-Csv -Path $filePath -NoTypeInformation
            }
            "JSON" {
                $filePath = Join-Path $OutputPath "${filename}.json"
                $chargebackData | ConvertTo-Json -Depth 3 | Out-File $filePath
            }
        }
        Write-Host "`n  Report exported: $filePath" -ForegroundColor Cyan
    }

    return $chargebackData
}
