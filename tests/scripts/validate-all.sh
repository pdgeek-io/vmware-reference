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
    if terraform -chdir="$dir" validate -no-color 2>/dev/null; then
        echo "  [PASS] $name"
        ((PASS++))
    else
        echo "  [FAIL] $name"
        ((FAIL++))
    fi
done

# --- Terraform Format ---
echo ""
echo "── Terraform Format ──"
if terraform fmt -check -recursive terraform/ >/dev/null 2>&1; then
    echo "  [PASS] All files formatted correctly"
    ((PASS++))
else
    echo "  [FAIL] Some files need formatting (run: terraform fmt -recursive terraform/)"
    ((FAIL++))
fi

# --- Packer ---
echo ""
echo "── Packer ──"
for dir in packer/builds/*/*/; do
    name=$(basename "$dir")
    if packer validate -syntax-only "$dir" 2>/dev/null; then
        echo "  [PASS] $name"
        ((PASS++))
    else
        echo "  [FAIL] $name"
        ((FAIL++))
    fi
done

# --- Ansible ---
echo ""
echo "── Ansible ──"
for playbook in ansible/playbooks/*.yml; do
    name=$(basename "$playbook")
    if ansible-playbook --syntax-check "$playbook" >/dev/null 2>&1; then
        echo "  [PASS] $name"
        ((PASS++))
    else
        echo "  [FAIL] $name"
        ((FAIL++))
    fi
done

# --- Summary ---
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "══════════════════════════════════════════════════════════════"

exit $FAIL
