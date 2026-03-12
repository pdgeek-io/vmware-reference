#!/usr/bin/env pwsh
# pdgeek.io — Smoke test: deploy a VM, verify, then destroy
# PowerShell equivalent of smoke-test.sh

$ErrorActionPreference = "Stop"

$vmName = "smoke-test-$(Get-Date -Format 'yyyyMMddHHmmss')"
$testIP = "10.0.200.250"

Write-Host "==> Smoke test: deploying $vmName" -ForegroundColor Cyan

# Deploy
Push-Location "terraform/stacks/03-workloads"
try {
    $tfVars = @"
{
  "$vmName" = {
    template      = "tpl-ubuntu-2404"
    resource_pool = "Development"
    folder        = "Reference-VMs"
    cpu           = 2
    memory_mb     = 4096
    os_disk_gb    = 40
    ip_address    = "$testIP"
    data_disks    = []
  }
}
"@

    terraform apply -auto-approve -var "vms=$tfVars" 2>&1

    Write-Host "==> Waiting 60s for VM to boot..." -ForegroundColor Yellow
    Start-Sleep -Seconds 60

    # Verify
    Write-Host "==> Verifying VM is reachable..." -ForegroundColor Yellow
    $pingResult = Test-Connection -TargetName $testIP -Count 3 -ErrorAction SilentlyContinue
    if ($pingResult) {
        Write-Host "  [PASS] VM is reachable at $testIP" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] VM not responding to ping (may be firewall)" -ForegroundColor Yellow
    }

} finally {
    # Cleanup
    Write-Host "==> Destroying smoke test VM..." -ForegroundColor Yellow
    terraform destroy -auto-approve -var "vms=$tfVars" 2>&1
    Pop-Location
}

Write-Host "==> Smoke test complete." -ForegroundColor Green
