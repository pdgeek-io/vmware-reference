#!/bin/bash
# Validate all Terraform, Packer, and Ansible configurations
set -euo pipefail

PASS=0
FAIL=0

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        pdgeek.io — VMware Reference Architecture             ║"
echo "║                 Validation Suite                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# --- Terraform ---
echo ""
echo "── Terraform ──"
for dir in terraform/modules/*/; do
    name=$(basename "$dir")
    if terraform -chdir="$dir" init -backend=false -input=false -no-color >/dev/null 2>&1 \
        && terraform -chdir="$dir" validate -no-color >/dev/null 2>&1; then
        echo "  [PASS] $name"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $name"
        FAIL=$((FAIL + 1))
    fi
done

# --- Terraform Format ---
echo ""
echo "── Terraform Format ──"
if terraform fmt -check -recursive terraform/ >/dev/null 2>&1; then
    echo "  [PASS] All files formatted correctly"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] Some files need formatting (run: terraform fmt -recursive terraform/)"
    FAIL=$((FAIL + 1))
fi

# --- Packer ---
echo ""
echo "── Packer ──"
for dir in packer/builds/*/*/; do
    name=$(basename "$dir")
    if ! compgen -G "${dir}"'*.pkr.hcl' >/dev/null; then
        continue
    fi

    if packer validate -syntax-only "$dir" 2>/dev/null; then
        echo "  [PASS] $name"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $name"
        FAIL=$((FAIL + 1))
    fi
done

# --- Ansible ---
echo ""
echo "── Ansible ──"
echo "  [INFO] Installing Ansible Galaxy collections from ansible/requirements.yml"
ansible-galaxy collection install -r ansible/requirements.yml >/dev/null
for playbook in ansible/playbooks/*.yml; do
    name=$(basename "$playbook")
    if ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook --syntax-check "$playbook" >/dev/null 2>&1; then
        echo "  [PASS] $name"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $name"
        FAIL=$((FAIL + 1))
    fi
done

# --- Summary ---
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "══════════════════════════════════════════════════════════════"

exit $FAIL
