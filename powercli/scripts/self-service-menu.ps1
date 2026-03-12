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
foreach ($env in @("powerstore.env", "powerscale.env")) {
    $envFile = Join-Path $PSScriptRoot "../../config/$env"
    if (Test-Path $envFile) {
        Get-Content $envFile | Where-Object { $_ -match '^export\s+(\w+)=(.*)' } | ForEach-Object {
            [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2].Trim('"'))
        }
    }
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                                  ║" -ForegroundColor Cyan
    Write-Host "  ║    pdgeek.io — Day 2 VMware Operations                           ║" -ForegroundColor Cyan
    Write-Host "  ║    PowerEdge  |  PowerStore  |  PowerScale  |  VMware VVF/VCF     ║" -ForegroundColor Cyan
    Write-Host "  ║                                                                  ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Write-Host "  ── Linux VMs ──────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host "    1) Small Linux       (2 vCPU, 4 GB, Ubuntu 24.04)"
    Write-Host "    2) Medium Linux      (4 vCPU, 8 GB, RHEL 9)"
    Write-Host "    3) Large Database    (8 vCPU, 32 GB, PostgreSQL + PowerStore)"
    Write-Host ""
    Write-Host "  ── Windows VMs ────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host "    4) Windows Standard  (4 vCPU, 8 GB, Server 2022)"
    Write-Host "    W) Windows IIS       (4 vCPU, 8 GB, IIS Web Server)"
    Write-Host "    S) Windows SQL       (8 vCPU, 32 GB, SQL Server + PowerStore)"
    Write-Host "    N) Windows .NET App  (4 vCPU, 16 GB, .NET 8 Runtime)"
    Write-Host "    D) Windows DC        (4 vCPU, 8 GB, Active Directory)"
    Write-Host ""
    Write-Host "  ── Compositions ───────────────────────────────────────" -ForegroundColor Yellow
    Write-Host "    5) Three-Tier Linux  (nginx + Flask + PostgreSQL)"
    Write-Host "    T) Three-Tier Windows (IIS + .NET + SQL Server)"
    Write-Host ""
    Write-Host "  ── Research Storage (PowerScale) ─────────────────────" -ForegroundColor Yellow
    Write-Host "    R) New researcher share  (NFS, Entra ID/AD, quota)"
    Write-Host "    G) Research share report  (grants, usage, expiration)"
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
        { $_ -in "1","2","3","4","W","w","S","s","N","n","D","d" } {
            $catalogMap = @{
                "1" = "small-linux"; "2" = "medium-linux"; "3" = "large-database"
                "4" = "windows-standard"
                "W" = "windows-web-server"; "w" = "windows-web-server"
                "S" = "windows-database"; "s" = "windows-database"
                "N" = "windows-app-server"; "n" = "windows-app-server"
                "D" = "windows-domain-controller"; "d" = "windows-domain-controller"
            }
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

            Write-Host "`n  Three-tier Linux app deployed and tagged!" -ForegroundColor Green
            Write-Host "  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        { $_ -in "T","t" } {
            Write-Host ""
            $prefix = Read-Host "  Enter name prefix for the Windows 3-tier app (e.g., campus)"
            $baseIP = Read-Host "  Enter base IP (last octet, e.g., 60 for .60/.61/.62)"
            $dept = Read-Host "  Department (e.g., IT, Registrar)"

            $base = [int]$baseIP
            New-RefVM -Name "${prefix}-iis" -CatalogItem "windows-web-server" -IPAddress "10.0.200.$base"
            New-RefVM -Name "${prefix}-dotnet" -CatalogItem "windows-app-server" -IPAddress "10.0.200.$($base+1)"
            New-RefVM -Name "${prefix}-sql" -CatalogItem "windows-database" -IPAddress "10.0.200.$($base+2)"

            if ($dept) {
                @("${prefix}-iis", "${prefix}-dotnet", "${prefix}-sql") | ForEach-Object {
                    Set-VMCostTags -VMName $_ -Department $dept -Project $prefix
                }
            }

            Write-Host "`n  Three-tier Windows app deployed and tagged!" -ForegroundColor Green
            Write-Host "  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        { $_ -in "R","r" } {
            Write-Host ""
            Write-Host "  ── New Researcher Share (PowerScale NFS) ──" -ForegroundColor Cyan
            Write-Host "  Grant & PI Information:" -ForegroundColor Yellow
            $shareName = Read-Host "  Share name (e.g., genomics-2025)"
            $dept = Read-Host "  Department (e.g., Biology, Computer Science, Kinesiology)"
            $piName = Read-Host "  PI name (e.g., Dr. Jane Smith)"
            $piUser = Read-Host "  PI username (Entra ID / AD)"
            $piEmail = Read-Host "  PI email"
            $grantID = Read-Host "  Grant ID (e.g., NIH-R01-GM123456)"
            $grantAgency = Read-Host "  Grant agency (NIH/NSF/DOE/DOD/USDA/state_of_texas/industry/internal)"
            if (-not $grantAgency) { $grantAgency = "NIH" }
            $grantExp = Read-Host "  Grant expiration (YYYY-MM-DD)"
            $quota = Read-Host "  Quota in GB (default: 1000)"
            if (-not $quota) { $quota = "1000" }

            Write-Host ""
            Write-Host "  Compliance & Classification:" -ForegroundColor Yellow
            Write-Host "    Data classification per TAC 202:"
            Write-Host "      public     — Open/published research data"
            Write-Host "      controlled — Unpublished results, proposals (default)"
            Write-Host "      confidential — FERPA, personnel, proprietary"
            Write-Host "      restricted — HIPAA PHI, export-controlled, CUI"
            $classification = Read-Host "  Classification [controlled]"
            if (-not $classification) { $classification = "controlled" }

            Write-Host "    Compliance flags (comma-separated, or Enter for none):"
            Write-Host "      ferpa, hipaa, export_control, cui, pii, proprietary"
            $flagsInput = Read-Host "  Flags"
            $flags = @()
            if ($flagsInput) {
                $flags = $flagsInput -split ',' | ForEach-Object { $_.Trim() }
            }

            $irb = Read-Host "  IRB number (required for human subjects, Enter to skip)"
            $iacuc = Read-Host "  IACUC number (required for animal research, Enter to skip)"
            $tcp = ""
            if ($flags -contains "export_control") {
                $tcp = Read-Host "  Technology Control Plan reference number"
            }
            $costCenter = Read-Host "  Dept cost center (fallback billing, Enter to skip)"

            $params = @{
                Name               = $shareName
                Department         = $dept
                PIName             = $piName
                PIUsername         = $piUser
                PIEmail            = $piEmail
                GrantID            = $grantID
                GrantAgency        = $grantAgency
                GrantExpiration    = $grantExp
                QuotaGB            = [int]$quota
                DataClassification = $classification
            }
            if ($flags.Count -gt 0) { $params.ComplianceFlags = $flags }
            if ($irb) { $params.IRBNumber = $irb }
            if ($iacuc) { $params.IACUCNumber = $iacuc }
            if ($tcp) { $params.TechnologyControlPlan = $tcp }
            if ($costCenter) { $params.CostCenter = $costCenter }

            New-ResearcherShare @params

            Write-Host "`n  Press Enter to continue..." -ForegroundColor Gray
            Read-Host
        }
        { $_ -in "G","g" } {
            Write-Host ""
            $dept = Read-Host "  Filter by department (or press Enter for all)"
            if ($dept) {
                Get-ResearchShareReport -Department $dept
            } else {
                Get-ResearchShareReport
            }
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
