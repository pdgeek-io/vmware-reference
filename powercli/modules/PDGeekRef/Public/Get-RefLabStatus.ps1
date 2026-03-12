function Get-RefLabStatus {
    <#
    .SYNOPSIS
        Display a dashboard of all Reference Lab VMs, storage, and health.
    .EXAMPLE
        Get-RefLabStatus
    #>
    [CmdletBinding()]
    param()

    Connect-RefEnvironment

    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       pdgeek.io — Reference Lab Status Dashboard            ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # --- Cluster Info ---
    Write-Host "`n── Compute (PowerEdge) ──" -ForegroundColor Yellow
    $cluster = Get-Cluster -Name "PowerEdge-Cluster-01" -ErrorAction SilentlyContinue
    if ($cluster) {
        $hosts = Get-VMHost -Location $cluster
        Write-Host "  Cluster:    $($cluster.Name)"
        Write-Host "  DRS:        $($cluster.DrsEnabled)"
        Write-Host "  HA:         $($cluster.HAEnabled)"
        Write-Host "  Hosts:      $($hosts.Count)"
        $hosts | ForEach-Object {
            $status = if ($_.ConnectionState -eq "Connected") { "OK" } else { $_.ConnectionState }
            Write-Host "    $($_.Name) — $status — $($_.NumCpu) CPU, $([math]::Round($_.MemoryTotalGB, 1)) GB RAM"
        }
    }

    # --- Storage Info ---
    Write-Host "`n── Storage (PowerStore) ──" -ForegroundColor Yellow
    $datastores = Get-Datastore -Name "PowerStore*" -ErrorAction SilentlyContinue
    $datastores | ForEach-Object {
        $usedPct = [math]::Round((($_.CapacityGB - $_.FreeSpaceGB) / $_.CapacityGB) * 100, 1)
        $color = if ($usedPct -gt 80) { "Red" } elseif ($usedPct -gt 60) { "Yellow" } else { "Green" }
        Write-Host "  $($_.Name): $([math]::Round($_.FreeSpaceGB, 1)) GB free of $([math]::Round($_.CapacityGB, 1)) GB ($usedPct% used)" -ForegroundColor $color
    }

    # --- VM Inventory ---
    Write-Host "`n── Reference VMs ──" -ForegroundColor Yellow
    $folder = Get-Folder -Name "Reference-VMs" -Type VM -ErrorAction SilentlyContinue
    if ($folder) {
        $vms = Get-VM -Location $folder
        if ($vms.Count -eq 0) {
            Write-Host "  No VMs deployed yet. Run 'New-RefVM' to get started."
        } else {
            $vms | Sort-Object Name | ForEach-Object {
                $ip = $_.Guest.IPAddress | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1
                $state = if ($_.PowerState -eq "PoweredOn") { "ON " } else { "OFF" }
                $stateColor = if ($_.PowerState -eq "PoweredOn") { "Green" } else { "Red" }
                Write-Host "  [$state] $($_.Name) — $($_.NumCpu) vCPU, $($_.MemoryGB) GB, IP: $($ip ?? 'N/A')" -ForegroundColor $stateColor
            }
        }
        Write-Host "`n  Total VMs: $($vms.Count)"
    }

    Write-Host ""
}
