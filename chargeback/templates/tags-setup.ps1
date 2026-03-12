#!/usr/bin/env pwsh
# pdgeek.io — Initialize chargeback tag categories in vCenter
# Run once to set up the tag structure for cost tracking.

$ErrorActionPreference = "Stop"

$modulePath = Join-Path $PSScriptRoot "../../powercli/modules/PDGeekRef"
Import-Module $modulePath -Force

# Source environment
$envFile = Join-Path $PSScriptRoot "../../config/powerstore.env"
if (Test-Path $envFile) {
    Get-Content $envFile | Where-Object { $_ -match '^export\s+(\w+)=(.*)' } | ForEach-Object {
        [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2].Trim('"'))
    }
}

Connect-VIServer -Server $env:VSPHERE_SERVER -User $env:VSPHERE_USER -Password $env:VSPHERE_PASSWORD

# Create tag categories
$categories = @(
    @{ Name = "Department"; Description = "Cost center department (e.g., Engineering, Sales, IT)" }
    @{ Name = "Project";    Description = "Project or application name for cost allocation" }
    @{ Name = "Owner";      Description = "VM owner or requestor" }
    @{ Name = "Environment"; Description = "Environment tier (Development, Staging, Production)" }
)

foreach ($cat in $categories) {
    $existing = Get-TagCategory -Name $cat.Name -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "  [EXISTS] $($cat.Name)" -ForegroundColor Gray
    } else {
        New-TagCategory -Name $cat.Name -Cardinality Single -EntityType VirtualMachine -Description $cat.Description
        Write-Host "  [CREATED] $($cat.Name)" -ForegroundColor Green
    }
}

# Create common department tags
$departments = @("Engineering", "Sales", "Marketing", "IT", "Finance", "Operations", "Lab")
$deptCategory = Get-TagCategory -Name "Department"
foreach ($dept in $departments) {
    $existing = Get-Tag -Category $deptCategory -Name $dept -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-Tag -Name $dept -Category $deptCategory | Out-Null
        Write-Host "  [CREATED] Department/$dept" -ForegroundColor Green
    }
}

# Create environment tags
$environments = @("Development", "Staging", "Production", "Lab")
$envCategory = Get-TagCategory -Name "Environment"
foreach ($env in $environments) {
    $existing = Get-Tag -Category $envCategory -Name $env -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-Tag -Name $env -Category $envCategory | Out-Null
        Write-Host "  [CREATED] Environment/$env" -ForegroundColor Green
    }
}

Write-Host "`nTag setup complete. Use Set-VMCostTags to assign tags to VMs." -ForegroundColor Cyan
