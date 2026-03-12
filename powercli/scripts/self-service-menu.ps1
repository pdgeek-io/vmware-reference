#!/usr/bin/env pwsh
# =============================================================================
# pdgeek.io — VMware Reference Architecture — Self-Service Demo Menu
# Interactive TUI for lab demos and customer walkthroughs
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
    Write-Host "  ║    pdgeek.io — VMware Reference Architecture                      ║" -ForegroundColor Cyan
    Write-Host "  ║    Self-Service VM Provisioning Portal                           ║" -ForegroundColor Cyan
    Write-Host "  ║                                                                  ║" -ForegroundColor Cyan
    Write-Host "  ║    PowerEdge  |  PowerStore  |  VMware VVF/VCF                   ║" -ForegroundColor Cyan
    Write-Host "  ║                                                                  ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Write-Host "  ── VM Catalog ─────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host "    1) Small Linux       (2 vCPU, 4 GB, Ubuntu 24.04)"
    Write-Host "    2) Medium Linux      (4 vCPU, 8 GB, RHEL 9)"
    Write-Host "    3) Large Database    (8 vCPU, 32 GB, PostgreSQL + PowerStore)"
    Write-Host "    4) Windows Standard  (4 vCPU, 8 GB, Server 2022)"
    Write-Host ""
    Write-Host "  ── Compositions ───────────────────────────────────────" -ForegroundColor Yellow
    Write-Host "    5) Three-Tier App    (Web + App + Database)"
    Write-Host ""
    Write-Host "  ── Operations ─────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host "    6) Lab Status Dashboard"
    Write-Host "    7) Remove a VM"
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

            Write-Host ""
            New-RefVM -Name $vmName -CatalogItem $catalog -IPAddress $vmIP
            Write-Host "`n  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "5" {
            Write-Host ""
            $prefix = Read-Host "  Enter name prefix for the 3-tier app (e.g., demo)"
            $baseIP = Read-Host "  Enter base IP (last octet, e.g., 50 for .50/.51/.52)"

            $base = [int]$baseIP
            New-RefVM -Name "${prefix}-web" -CatalogItem "small-linux" -IPAddress "10.0.200.$base"
            New-RefVM -Name "${prefix}-app" -CatalogItem "medium-linux" -IPAddress "10.0.200.$($base+1)"
            New-RefVM -Name "${prefix}-db" -CatalogItem "large-database" -IPAddress "10.0.200.$($base+2)"

            Write-Host "`n  Three-tier app deployed!" -ForegroundColor Green
            Write-Host "  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "6" {
            Get-RefLabStatus
            Write-Host "  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        "7" {
            Write-Host ""
            $vmName = Read-Host "  Enter VM name to remove"
            Remove-RefVM -Name $vmName
            Write-Host "`n  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
    }
} while ($choice -ne "Q" -and $choice -ne "q")

Write-Host "`n  Goodbye!`n" -ForegroundColor Cyan
