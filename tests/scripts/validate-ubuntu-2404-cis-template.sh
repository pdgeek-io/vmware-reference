#!/bin/bash
# Validate that the Ubuntu 24.04 Packer template has the expected CIS hook.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKER_DIR="${ROOT_DIR}/packer/builds/linux/ubuntu-2404"
PACKER_FILE="${PACKER_DIR}/ubuntu-2404.pkr.hcl"
VARIABLES_FILE="${PACKER_DIR}/variables.pkr.hcl"
CIS_SCRIPT="${PACKER_DIR}/scripts/cis-baseline.sh"

echo "==> Validating Ubuntu 24.04 CIS Packer hook"

test -f "${CIS_SCRIPT}"
test -x "${CIS_SCRIPT}"
grep -q 'scripts/cis-baseline.sh' "${PACKER_FILE}"
grep -q 'ENABLE_CIS_BASELINE' "${PACKER_FILE}"
grep -q 'variable "enable_cis_baseline"' "${VARIABLES_FILE}"
grep -q 'variable "cis_disable_password_ssh"' "${VARIABLES_FILE}"
grep -q 'EVIDENCE_DIR="/etc/pdgeek/template-hardening"' "${CIS_SCRIPT}"
grep -q 'EVIDENCE_FILE="${EVIDENCE_DIR}/ubuntu-2404-cis.yml"' "${CIS_SCRIPT}"
grep -q 'PasswordAuthentication' "${CIS_SCRIPT}"
grep -q 'pdgeek_cis_sshd_test_key' "${CIS_SCRIPT}"
grep -q 'auditd' "${CIS_SCRIPT}"
grep -q 'apparmor' "${CIS_SCRIPT}"
grep -q 'terraform: deploys VMs from this hardened template' "${CIS_SCRIPT}"
grep -q 'ansible: validates and finalizes guest/application state after clone' "${CIS_SCRIPT}"

packer fmt -check "${PACKER_DIR}" >/dev/null
packer validate -syntax-only "${PACKER_DIR}" >/dev/null

echo "  [PASS] ubuntu-2404 CIS template hook"
