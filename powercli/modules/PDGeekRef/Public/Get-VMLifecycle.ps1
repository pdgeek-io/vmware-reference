function Get-VMLifecycle {
    <#
    .SYNOPSIS
        Track VM lifecycle status — age, last powered on, resource utilization, and rightsizing recommendations.
    .DESCRIPTION
        Identifies VMs that are idle, oversized, orphaned, or approaching end-of-life.
        Useful for governance and cost optimization alongside chargeback reports.
    .EXAMPLE
        Get-VMLifecycle
    .EXAMPLE
        Get-VMLifecycle -StaleThresholdDays 60 -ShowIdleOnly
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$StaleThresholdDays = 30,

        [Parameter()]
        [switch]$ShowIdleOnly,

        [Parameter()]
        [switch]$ShowRightsizing
    )

    Connect-RefEnvironment

    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          pdgeek.io — VM Lifecycle Report                    ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    $allVMs = Get-VM
    $lifecycleData = @()

    foreach ($vm in $allVMs) {
        # VM age (from creation event)
        $createdEvent = Get-VIEvent -Entity $vm -MaxSamples 1000 |
            Where-Object { $_ -is [VMware.Vim.VmCreatedEvent] -or $_ -is [VMware.Vim.VmClonedEvent] -or $_ -is [VMware.Vim.VmDeployedEvent] } |
            Sort-Object CreatedTime | Select-Object -First 1
        $createdDate = if ($createdEvent) { $createdEvent.CreatedTime } else { $null }
        $ageInDays = if ($createdDate) { ((Get-Date) - $createdDate).Days } else { -1 }

        # Utilization stats (last 7 days)
        $cpuAvg = (Get-Stat -Entity $vm -Stat "cpu.usage.average" -Start (Get-Date).AddDays(-7) -ErrorAction SilentlyContinue |
            Measure-Object -Property Value -Average).Average
        $memAvg = (Get-Stat -Entity $vm -Stat "mem.usage.average" -Start (Get-Date).AddDays(-7) -ErrorAction SilentlyContinue |
            Measure-Object -Property Value -Average).Average

        # Determine status
        $status = "Active"
        $recommendation = "None"

        if ($vm.PowerState -ne "PoweredOn") {
            $status = "Powered Off"
            $recommendation = "Review — VM is not running"
        } elseif ($cpuAvg -lt 5 -and $memAvg -lt 10) {
            $status = "Idle"
            $recommendation = "Consider decommission — CPU <5%, Memory <10%"
        } elseif ($cpuAvg -lt 15 -and $memAvg -lt 20) {
            $status = "Low Usage"
            $recommendation = "Review sizing — may be over-provisioned"
        }

        # Rightsizing recommendations
        if ($ShowRightsizing -and $vm.PowerState -eq "PoweredOn") {
            if ($cpuAvg -lt 20 -and $vm.NumCpu -gt 2) {
                $recommendation = "Rightsize CPU: $($vm.NumCpu) -> $([math]::Max(2, [math]::Ceiling($vm.NumCpu / 2))) vCPU"
            }
            if ($memAvg -lt 20 -and $vm.MemoryGB -gt 4) {
                $memRec = [math]::Max(4, [math]::Ceiling($vm.MemoryGB / 2))
                $recommendation += " | Rightsize Memory: $($vm.MemoryGB) -> $memRec GB"
            }
        }

        $lifecycleData += [PSCustomObject]@{
            VMName         = $vm.Name
            PowerState     = $vm.PowerState
            Status         = $status
            AgeDays        = $ageInDays
            vCPU           = $vm.NumCpu
            MemoryGB       = $vm.MemoryGB
            AvgCpuPct      = [math]::Round($cpuAvg, 1)
            AvgMemPct      = [math]::Round($memAvg, 1)
            Folder         = $vm.Folder.Name
            Recommendation = $recommendation
        }
    }

    if ($ShowIdleOnly) {
        $lifecycleData = $lifecycleData | Where-Object { $_.Status -in @("Idle", "Powered Off", "Low Usage") }
    }

    # Display
    Write-Host "`n── VM Lifecycle Status ──" -ForegroundColor Yellow
    $lifecycleData | Sort-Object Status, VMName |
        Format-Table VMName, Status, AgeDays, vCPU, MemoryGB, AvgCpuPct, AvgMemPct, Recommendation -AutoSize

    # Summary
    $statusCounts = $lifecycleData | Group-Object Status
    Write-Host "── Summary ──" -ForegroundColor Yellow
    foreach ($group in $statusCounts | Sort-Object Name) {
        $color = switch ($group.Name) {
            "Active" { "Green" }
            "Low Usage" { "Yellow" }
            "Idle" { "Red" }
            "Powered Off" { "DarkGray" }
            default { "White" }
        }
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor $color
    }
    Write-Host "  Total: $($lifecycleData.Count)" -ForegroundColor Cyan

    return $lifecycleData
}
