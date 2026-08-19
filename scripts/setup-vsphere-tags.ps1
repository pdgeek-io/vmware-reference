#!/usr/bin/env pwsh
# pdgeek.io - initialize vSphere tag categories for the higher-ed baseline.
# Requires VSPHERE_SERVER, VSPHERE_USER, and VSPHERE_PASSWORD in the environment.

$ErrorActionPreference = "Stop"

$requiredEnv = @("VSPHERE_SERVER", "VSPHERE_USER", "VSPHERE_PASSWORD")
$missingEnv = $requiredEnv | Where-Object { -not [System.Environment]::GetEnvironmentVariable($_) }
if ($missingEnv.Count -gt 0) {
    throw "Missing required environment variables: $($missingEnv -join ', ')"
}

Import-Module VMware.VimAutomation.Core -ErrorAction Stop
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

# Create only the baseline values currently consumed by the validated catalog item.
$departments = @("Research")
$deptCategory = Get-TagCategory -Name "Department"
foreach ($dept in $departments) {
    $existing = Get-Tag -Category $deptCategory -Name $dept -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-Tag -Name $dept -Category $deptCategory | Out-Null
        Write-Host "  [CREATED] Department/$dept" -ForegroundColor Green
    }
}

$environments = @("Development")
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

Write-Host "`nBaseline tag setup complete. Terraform applies these tags during deployment." -ForegroundColor Cyan
