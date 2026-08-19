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
    @{ Name = "Department";         Description = "Customer department or college consuming the service" }
    @{ Name = "CostCenter";         Description = "Billing or showback cost center" }
    @{ Name = "Project";            Description = "Project, grant, or shared service name for cost allocation" }
    @{ Name = "Owner";              Description = "Primary VM owner or requestor group" }
    @{ Name = "Application";        Description = "Application or platform service supported by the VM" }
    @{ Name = "AppOwner";           Description = "Business or functional application owner" }
    @{ Name = "TechnicalOwner";     Description = "Technical team accountable for operations" }
    @{ Name = "Environment";        Description = "Environment tier such as Development, Test, or Production" }
    @{ Name = "ServiceTier";        Description = "Support and availability tier for shared services" }
    @{ Name = "BackupPolicy";       Description = "Backup policy or retention intent" }
    @{ Name = "DataClassification"; Description = "Data sensitivity classification" }
    @{ Name = "BillingModel";       Description = "Consumption model for billing and showback" }
    @{ Name = "Lifecycle";          Description = "Lifecycle review or retirement policy" }
    @{ Name = "ManagedBy";          Description = "Automation control plane or operational owner managing VM lifecycle" }
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
$departments = @("Engineering", "Sales", "Marketing", "IT", "Finance", "Operations", "Lab", "Research")
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

# Create first higher-ed baseline tags used by the MVP catalog item.
$baselineTags = @(
    @{ Category = "CostCenter";         Name = "RC-1000" }
    @{ Category = "Project";            Name = "Shared-Research-Compute" }
    @{ Category = "Owner";              Name = "Research-IT" }
    @{ Category = "Application";        Name = "Shared-Linux-Service" }
    @{ Category = "AppOwner";           Name = "Research-IT" }
    @{ Category = "TechnicalOwner";     Name = "Platform-Engineering" }
    @{ Category = "ServiceTier";        Name = "Standard" }
    @{ Category = "BackupPolicy";       Name = "Daily-30-Day" }
    @{ Category = "DataClassification"; Name = "Internal" }
    @{ Category = "BillingModel";       Name = "Shared-Services" }
    @{ Category = "Lifecycle";          Name = "Annual-Review" }
    @{ Category = "ManagedBy";          Name = "VMware-Automation" }
)

foreach ($tag in $baselineTags) {
    $category = Get-TagCategory -Name $tag.Category
    $existing = Get-Tag -Category $category -Name $tag.Name -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-Tag -Name $tag.Name -Category $category | Out-Null
        Write-Host "  [CREATED] $($tag.Category)/$($tag.Name)" -ForegroundColor Green
    }
}

Write-Host "`nTag setup complete. Use Set-VMCostTags to assign tags to VMs." -ForegroundColor Cyan
