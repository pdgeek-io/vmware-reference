#!/usr/bin/env pwsh
# =============================================================================
# pdgeek.io — Day 2 Operations Menu
# Self-service VMs, guest automation, chargeback/showback
# =============================================================================

$ErrorActionPreference = "Stop"

# Import module
$modulePath = Join-Path $PSScriptRoot "../modules/PDGeekRef"
Import-Module $modulePath -Force

# Source environment
$envFile = Join-Path $PSScriptRoot "../../config/powerstore.env"
if (Test-Path $envFile) {
    Get-Content $envFile | Where-Object { $_ -match '^export\s+(\w+)=(.*)' } | ForEach-Object {
        [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2].Trim('"'))
    }
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                                  ║" -ForegroundColor Cyan
    Write-Host "  ║    pdgeek.io — Day 2 VMware Operations                           ║" -ForegroundColor Cyan
    Write-Host "  ║    PowerEdge  |  PowerStore  |  VMware VVF/VCF                   ║" -ForegroundColor Cyan
    Write-Host "  ║                                                                  ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Write-Host "  ── Self-Service VMs ───────────────────────────────────" -ForegroundColor Yellow
    Write-Host "    1) Small Linux       (2 vCPU, 4 GB, Ubuntu 24.04)"
    Write-Host "    2) Medium Linux      (4 vCPU, 8 GB, RHEL 9)"
    Write-Host "    3) Large Database    (8 vCPU, 32 GB, PostgreSQL + PowerStore)"
    Write-Host "    4) Windows Standard  (4 vCPU, 8 GB, Server 2022)"
    Write-Host "    5) Three-Tier App    (Web + App + Database)"
    Write-Host ""
    Write-Host "  ── Guest Automation (VMware Tools) ────────────────────" -ForegroundColor Yellow
    Write-Host "    6) Run command in guest VM"
    Write-Host "    7) Get guest system info"
    Write-Host "    8) Install package in guest"
    Write-Host "    9) Copy file to/from guest"
    Write-Host ""
    Write-Host "  ── Chargeback / Showback ──────────────────────────────" -ForegroundColor Yellow
    Write-Host "   10) Chargeback report (all VMs)"
    Write-Host "   11) Chargeback by department"
    Write-Host "   12) Tag a VM for cost tracking"
    Write-Host "   13) Export chargeback to CSV"
    Write-Host ""
    Write-Host "  ── Lifecycle & Operations ─────────────────────────────" -ForegroundColor Yellow
    Write-Host "   14) Lab status dashboard"
    Write-Host "   15) VM lifecycle report (idle/oversized detection)"
    Write-Host "   16) Remove a VM"
    Write-Host "    Q) Quit"
    Write-Host ""
}

# Main loop
do {
    Show-Banner
    Show-Menu

    $choice = Read-Host "  Select an option"

    switch ($choice) {
        { $_ -in "1","2","3","4" } {
            $catalogMap = @{ "1" = "small-linux"; "2" = "medium-linux"; "3" = "large-database"; "4" = "windows-standard" }
            $catalog = $catalogMap[$choice]

            Write-Host ""
            $vmName = Read-Host "  Enter VM name"
            $vmIP = Read-Host "  Enter IP address (e.g., 10.0.200.50)"
            $dept = Read-Host "  Department (e.g., Engineering, IT, Lab)"

            Write-Host ""
            $vm = New-RefVM -Name $vmName -CatalogItem $catalog -IPAddress $vmIP
            if ($dept) {
                Set-VMCostTags -VMName $vmName -Department $dept
            }
            Write-Host "`n  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "5" {
            Write-Host ""
            $prefix = Read-Host "  Enter name prefix for the 3-tier app (e.g., demo)"
            $baseIP = Read-Host "  Enter base IP (last octet, e.g., 50 for .50/.51/.52)"
            $dept = Read-Host "  Department (e.g., Engineering)"

            $base = [int]$baseIP
            New-RefVM -Name "${prefix}-web" -CatalogItem "small-linux" -IPAddress "10.0.200.$base"
            New-RefVM -Name "${prefix}-app" -CatalogItem "medium-linux" -IPAddress "10.0.200.$($base+1)"
            New-RefVM -Name "${prefix}-db" -CatalogItem "large-database" -IPAddress "10.0.200.$($base+2)"

            if ($dept) {
                @("${prefix}-web", "${prefix}-app", "${prefix}-db") | ForEach-Object {
                    Set-VMCostTags -VMName $_ -Department $dept -Project $prefix
                }
            }

            Write-Host "`n  Three-tier app deployed and tagged!" -ForegroundColor Green
            Write-Host "  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "6" {
            Write-Host ""
            $vmName = Read-Host "  VM name"
            $cmd = Read-Host "  Command to run"
            Invoke-GuestAutomation -VMName $vmName -Script $cmd
            Write-Host "`n  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "7" {
            Write-Host ""
            $vmName = Read-Host "  VM name"
            Invoke-GuestAutomation -VMName $vmName -Action GetSystemInfo
            Write-Host "`n  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "8" {
            Write-Host ""
            $vmName = Read-Host "  VM name"
            $pkg = Read-Host "  Package name (e.g., nginx, docker-ce)"
            Invoke-GuestAutomation -VMName $vmName -Action InstallPackage -PackageName $pkg
            Write-Host "`n  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "9" {
            Write-Host ""
            $vmName = Read-Host "  VM name"
            $direction = Read-Host "  Direction (to/from)"
            $src = Read-Host "  Source path"
            $dst = Read-Host "  Destination path"
            if ($direction -eq "from") {
                Copy-GuestFile -VMName $vmName -Source $src -Destination $dst -FromGuest
            } else {
                Copy-GuestFile -VMName $vmName -Source $src -Destination $dst
            }
            Write-Host "`n  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "10" {
            Get-VMChargeback
            Write-Host "  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "11" {
            Write-Host ""
            $dept = Read-Host "  Department name"
            Get-VMChargeback -Department $dept
            Write-Host "  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "12" {
            Write-Host ""
            $vmName = Read-Host "  VM name"
            $dept = Read-Host "  Department"
            $proj = Read-Host "  Project (optional)"
            $owner = Read-Host "  Owner (optional)"
            Set-VMCostTags -VMName $vmName -Department $dept -Project $proj -Owner $owner
            Write-Host "`n  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "13" {
            Get-VMChargeback -OutputFormat CSV
            Write-Host "  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "14" {
            Get-RefLabStatus
            Write-Host "  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "15" {
            Get-VMLifecycle -ShowRightsizing
            Write-Host "  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "16" {
            Write-Host ""
            $vmName = Read-Host "  Enter VM name to remove"
            Remove-RefVM -Name $vmName
            Write-Host "`n  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
    }
} while ($choice -ne "Q" -and $choice -ne "q")

Write-Host "`n  Goodbye!`n" -ForegroundColor Cyan
