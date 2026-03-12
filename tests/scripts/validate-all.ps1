#!/usr/bin/env pwsh
# pdgeek.io — Validate all Terraform, Packer, and Ansible configurations
# PowerShell equivalent of validate-all.sh

$ErrorActionPreference = "Continue"
$pass = 0
$fail = 0

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        pdgeek.io — VMware Reference Architecture             ║" -ForegroundColor Cyan
Write-Host "║                 Validation Suite                             ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# --- Terraform ---
Write-Host "`n── Terraform Modules ──" -ForegroundColor Yellow
Get-ChildItem -Path "terraform/modules" -Directory | ForEach-Object {
    $name = $_.Name
    Push-Location $_.FullName
    $result = terraform validate -no-color 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] $name" -ForegroundColor Green
        $script:pass++
    } else {
        Write-Host "  [FAIL] $name" -ForegroundColor Red
        $script:fail++
    }
    Pop-Location
}

# --- Terraform Format ---
Write-Host "`n── Terraform Format ──" -ForegroundColor Yellow
$fmtResult = terraform fmt -check -recursive terraform/ 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [PASS] All files formatted correctly" -ForegroundColor Green
    $pass++
} else {
    Write-Host "  [FAIL] Some files need formatting (run: terraform fmt -recursive terraform/)" -ForegroundColor Red
    $fail++
}

# --- Packer ---
Write-Host "`n── Packer Templates ──" -ForegroundColor Yellow
Get-ChildItem -Path "packer/builds" -Directory -Recurse -Depth 1 |
    Where-Object { Get-ChildItem $_.FullName -Filter "*.pkr.hcl" -ErrorAction SilentlyContinue } |
    ForEach-Object {
        $name = $_.Name
        $validateResult = packer validate -syntax-only $_.FullName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [PASS] $name" -ForegroundColor Green
            $script:pass++
        } else {
            Write-Host "  [FAIL] $name" -ForegroundColor Red
            $script:fail++
        }
    }

# --- Ansible ---
Write-Host "`n── Ansible Playbooks ──" -ForegroundColor Yellow
Get-ChildItem -Path "ansible/playbooks" -Filter "*.yml" | ForEach-Object {
    $name = $_.Name
    $checkResult = ansible-playbook --syntax-check $_.FullName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] $name" -ForegroundColor Green
        $script:pass++
    } else {
        Write-Host "  [FAIL] $name" -ForegroundColor Red
        $script:fail++
    }
}

# --- Summary ---
Write-Host "`n══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Results: $pass passed, $fail failed" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Green" })
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

exit $fail
