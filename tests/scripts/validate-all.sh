#!/bin/bash
# Validate the production MVP surface only.
set -euo pipefail

PASS=0
FAIL=0

run_check() {
    local name="$1"
    shift

    if "$@"; then
        echo "  [PASS] ${name}"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] ${name}"
        FAIL=$((FAIL + 1))
    fi
}

echo "==> Validating VMware higher-ed baseline MVP"

echo "==> Installing Ansible collections"
ansible-galaxy collection install -r ansible/requirements.yml >/dev/null

run_check "vSphere VM Terraform module" \
    bash -c 'terraform -chdir=terraform/modules/vsphere-vm init -backend=false -input=false -no-color >/dev/null && terraform -chdir=terraform/modules/vsphere-vm validate -no-color'

run_check "Terraform formatting" \
    terraform fmt -check -recursive terraform/

run_check "Ubuntu 24.04 CIS template hook" \
    bash tests/scripts/validate-ubuntu-2404-cis-template.sh

run_check "Higher-ed Linux baseline contract" \
    bash tests/scripts/validate-higher-ed-baseline.sh

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
exit "${FAIL}"
