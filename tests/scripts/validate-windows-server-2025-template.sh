#!/bin/bash
# Validate the Windows Server 2025 Packer scaffold without requiring the ISO.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKER_DIR="${ROOT_DIR}/packer/builds/windows/windows-server-2025"
PACKER_FILE="${PACKER_DIR}/windows-server-2025.pkr.hcl"
VARIABLES_FILE="${PACKER_DIR}/variables.pkr.hcl"
ANSWER_FILE="${PACKER_DIR}/answer/Autounattend.xml.pkrtpl"
TOOLS_SCRIPT="${PACKER_DIR}/scripts/install-vmware-tools.ps1"
WINRM_SCRIPT="${PACKER_DIR}/scripts/enable-winrm.ps1"
CLEANUP_SCRIPT="${PACKER_DIR}/scripts/cleanup-template.ps1"
SYSPREP_SCRIPT="${PACKER_DIR}/scripts/sysprep-template.ps1"
PREFLIGHT_SCRIPT="${ROOT_DIR}/scripts/preflight-windows-server-2025-template.ps1"

echo "==> Validating Windows Server 2025 Packer scaffold"

test -f "${ANSWER_FILE}"
test -f "${TOOLS_SCRIPT}"
test -f "${WINRM_SCRIPT}"
test -f "${CLEANUP_SCRIPT}"
test -f "${SYSPREP_SCRIPT}"
test -f "${PREFLIGHT_SCRIPT}"

grep -q 'source "vsphere-iso" "windows-server-2025"' "${PACKER_FILE}"
grep -q 'iso_url      = var.windows_iso_url' "${PACKER_FILE}"
grep -q 'iso_checksum = var.windows_iso_url != "" ? var.windows_iso_checksum : "none"' "${PACKER_FILE}"
grep -q 'var.windows_iso_path' "${PACKER_FILE}"
grep -q 'floppy_content = {' "${PACKER_FILE}"
grep -q 'remote_cache_cleanup = true' "${PACKER_FILE}"
grep -q 'remove_cdrom        = true' "${PACKER_FILE}"
grep -q 'VMWARE_TOOLS_INSTALLER_URL' "${PACKER_FILE}"
grep -q 'winrm_use_ssl  = true' "${PACKER_FILE}"
grep -q 'winrm_use_ntlm = true' "${PACKER_FILE}"
grep -q 'scripts/install-vmware-tools.ps1' "${PACKER_FILE}"
grep -q 'scripts/cleanup-template.ps1' "${PACKER_FILE}"
grep -q 'scripts/sysprep-template.ps1' "${PACKER_FILE}"

grep -q 'variable "windows_iso_url"' "${VARIABLES_FILE}"
grep -q 'variable "windows_iso_path"' "${VARIABLES_FILE}"
grep -q 'variable "windows_iso_checksum"' "${VARIABLES_FILE}"
grep -q 'variable "vmware_tools_iso_path"' "${VARIABLES_FILE}"
grep -q 'variable "vmware_tools_installer_url"' "${VARIABLES_FILE}"
grep -q 'variable "winrm_allowed_remote_addresses"' "${VARIABLES_FILE}"

grep -q 'Windows Server 2025 SERVERSTANDARDCORE' "${VARIABLES_FILE}"
grep -q 'cf96e924b4e7551169e09ef2a42d81340cdef11eaadf4bd4ac7bf1cdad5178a4' "${VARIABLES_FILE}"
grep -q 'AllowUnencrypted="false"' "${WINRM_SCRIPT}"
grep -q 'Basic="false"' "${WINRM_SCRIPT}"
grep -q 'New-SelfSignedCertificate' "${WINRM_SCRIPT}"
grep -q 'setup64.exe' "${TOOLS_SCRIPT}"
grep -q 'VMWARE_TOOLS_INSTALLER_URL' "${TOOLS_SCRIPT}"
grep -q 'Sysprep.exe' "${SYSPREP_SCRIPT}"
grep -q 'windows2022srvNext_64Guest' "${PREFLIGHT_SCRIPT}"
grep -q 'WINDOWS_SERVER_2025_ISO_VSPHERE_PATH' "${PREFLIGHT_SCRIPT}"
grep -q 'WINDOWS_SERVER_2025_LOCAL_ISO_PATH' "${PREFLIGHT_SCRIPT}"
grep -q '/usr/lib/vmware/isoimages/windows.iso' "${PREFLIGHT_SCRIPT}"

if command -v pwsh >/dev/null 2>&1; then
    for script in "${TOOLS_SCRIPT}" "${WINRM_SCRIPT}" "${CLEANUP_SCRIPT}" "${SYSPREP_SCRIPT}" "${PREFLIGHT_SCRIPT}"; do
        SCRIPT_TO_PARSE="${script}" pwsh -NoProfile -Command '
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($env:SCRIPT_TO_PARSE, [ref]$null, [ref]$errors) | Out-Null
            if ($errors.Count -gt 0) {
                $errors | ForEach-Object { Write-Error $_.Message }
                exit 1
            }
        ' >/dev/null
    done
fi

packer fmt -check "${PACKER_DIR}" >/dev/null
packer init "${PACKER_DIR}" >/dev/null
packer validate -syntax-only "${PACKER_DIR}" >/dev/null

echo "  [PASS] windows-server-2025 Packer scaffold"
