#!/bin/bash
# Validate the first higher-ed common infrastructure build slice.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CATALOG_ITEM="${ROOT_DIR}/self-service/catalog/higher-ed-small-linux.yml"
PLAYBOOK="${ROOT_DIR}/ansible/playbooks/higher-ed-linux-baseline.yml"
INVENTORY_RENDERER="${ROOT_DIR}/scripts/render-terraform-inventory.py"
PACKER_CIS_PLAYBOOK="${ROOT_DIR}/packer/builds/common/ansible-packer.yml"
PACKER_UBUNTU_TEMPLATE="${ROOT_DIR}/packer/builds/linux/ubuntu-2404/ubuntu-2404.pkr.hcl"
PACKER_UBUNTU_CIS_SCRIPT="${ROOT_DIR}/packer/builds/linux/ubuntu-2404/scripts/cis-baseline.sh"
PACKER_WINDOWS_2022_TEMPLATE="${ROOT_DIR}/packer/builds/windows/windows-server-2022/windows-server-2022.pkr.hcl"
PACKER_WINDOWS_2022_UNATTEND="${ROOT_DIR}/packer/builds/windows/windows-server-2022/scripts/Autounattend.xml"
PACKER_WINDOWS_2025_TEMPLATE="${ROOT_DIR}/packer/builds/windows/windows-server-2025/windows-server-2025.pkr.hcl"
PACKER_WINDOWS_2025_UNATTEND="${ROOT_DIR}/packer/builds/windows/windows-server-2025/scripts/Autounattend.xml"
PACKER_WINDOWS_CLEANUP="${ROOT_DIR}/packer/builds/windows/common/scripts/cleanup-windows-template.ps1"
STACK_DIR="${ROOT_DIR}/terraform/stacks/03-workloads"

echo "==> Validating higher-ed baseline catalog item"
ruby - <<'RUBY' "${CATALOG_ITEM}"
require "yaml"

item = YAML.load_file(ARGV.fetch(0))

required_top_level = %w[
  name
  template
  compute
  storage
  network
  resource_pool
  folder
  tags
  chargeback
  app_hooks
  validation
]
missing = required_top_level - item.keys
abort("missing required keys: #{missing.join(', ')}") unless missing.empty?

tag_keys = item["tags"].map { |tag| [tag["category"], tag["name"]] }
expected_tags = [
  ["Department", "Research"],
  ["CostCenter", "RC-1000"],
  ["Project", "Shared-Research-Compute"],
  ["Environment", "Development"],
  ["Owner", "Research-IT"],
  ["Application", "Shared-Linux-Service"],
  ["AppOwner", "Research-IT"],
  ["TechnicalOwner", "Platform-Engineering"],
  ["ServiceTier", "Standard"],
  ["BackupPolicy", "Daily-30-Day"],
  ["DataClassification", "Internal"],
  ["BillingModel", "Shared-Services"],
  ["Lifecycle", "Annual-Review"],
  ["ManagedBy", "VMware-Automation"],
]
missing_tags = expected_tags - tag_keys
abort("missing expected tags: #{missing_tags.inspect}") unless missing_tags.empty?

required_chargeback = %w[
  department
  cost_center
  project
  environment
  billing_model
  service_tier
  backup_policy
  application
  app_owner
  technical_owner
  monthly_budget_usd
  data_classification
  lifecycle
  managed_by
]
missing_chargeback = required_chargeback - item["chargeback"].keys
abort("missing chargeback keys: #{missing_chargeback.join(', ')}") unless missing_chargeback.empty?

unless item["managed_by"] == "VMware Automation"
  abort("catalog item must declare VMware Automation as the service control plane")
end

unless item.dig("network", "dns_ipam", "provider") == "placeholder"
  abort("DNS/IPAM provider must remain placeholder in the MVP")
end

unless item.dig("app_hooks", "ansible_playbooks").include?("ansible/playbooks/higher-ed-linux-baseline.yml")
  abort("baseline Ansible playbook is not exposed as an app hook")
end

abort("SSH validation port missing") unless item.dig("validation", "tcp_ports").include?(22)

puts "  [PASS] catalog metadata"
RUBY

echo "==> Validating Terraform stack"
terraform -chdir="${STACK_DIR}" init -backend=false -input=false -no-color >/dev/null
terraform -chdir="${STACK_DIR}" validate -no-color >/dev/null
echo "  [PASS] terraform/stacks/03-workloads"

echo "==> Validating Ansible playbook syntax"
ANSIBLE_CONFIG="${ROOT_DIR}/ansible/ansible.cfg" ansible-playbook -i localhost, --syntax-check "${PLAYBOOK}" >/dev/null
echo "  [PASS] higher-ed-linux-baseline.yml"

echo "==> Validating Packer CIS baseline hook"
ANSIBLE_CONFIG="${ROOT_DIR}/ansible/ansible.cfg" ansible-playbook -i localhost, --syntax-check "${PACKER_CIS_PLAYBOOK}" >/dev/null
grep -q "scripts/cis-baseline.sh" "${PACKER_UBUNTU_TEMPLATE}"
grep -q "CIS_PROFILE" "${PACKER_UBUNTU_CIS_SCRIPT}"
echo "  [PASS] Packer CIS baseline hook"

echo "==> Validating Windows Packer bootstrap"
grep -q "floppy_content" "${PACKER_WINDOWS_2022_TEMPLATE}"
grep -q "floppy_content" "${PACKER_WINDOWS_2025_TEMPLATE}"
grep -q 'build_password = var.build_password' "${PACKER_WINDOWS_2022_TEMPLATE}"
grep -q 'build_password = var.build_password' "${PACKER_WINDOWS_2025_TEMPLATE}"
grep -q '${build_password}' "${PACKER_WINDOWS_2022_UNATTEND}"
grep -q '${build_password}' "${PACKER_WINDOWS_2025_UNATTEND}"
grep -q 'install-vmtools.ps1' "${PACKER_WINDOWS_2022_UNATTEND}"
grep -q 'configure-winrm.ps1' "${PACKER_WINDOWS_2022_UNATTEND}"
grep -q 'install-vmtools.ps1' "${PACKER_WINDOWS_2025_UNATTEND}"
grep -q 'configure-winrm.ps1' "${PACKER_WINDOWS_2025_UNATTEND}"
grep -q 'cleanup-windows-template.ps1' "${PACKER_WINDOWS_2022_TEMPLATE}"
grep -q 'cleanup-windows-template.ps1' "${PACKER_WINDOWS_2025_TEMPLATE}"
grep -q 'Get-AppxProvisionedPackage' "${PACKER_WINDOWS_CLEANUP}"
grep -q 'Disable-WindowsOptionalFeature' "${PACKER_WINDOWS_CLEANUP}"
grep -q 'disabledServices' "${PACKER_WINDOWS_CLEANUP}"
grep -q 'Removing ghost network device' "${PACKER_WINDOWS_CLEANUP}"
grep -q 'NetworkList\\Profiles' "${PACKER_WINDOWS_CLEANUP}"
grep -q 'ghostNetworkDevices' "${PACKER_WINDOWS_CLEANUP}"
grep -q 'Windows template cleanup evidence' "${PACKER_WINDOWS_CLEANUP}"
echo "  [PASS] Windows VMTools and WinRM bootstrap"

echo "==> Validating Terraform-to-Ansible inventory handoff"
python3 "${INVENTORY_RENDERER}" --group higher_ed_linux <<'JSON' >/dev/null
{
  "hed-linux-01": {
    "ip_address": "10.0.200.20",
    "fqdn": "hed-linux-01.lab.example.edu",
    "folder": "Reference-VMs/App",
    "template": "tpl-ubuntu-2404",
    "tags": [{"category": "Department", "name": "Research"}],
    "chargeback": {"cost_center": "RC-1000"},
    "validation": {"tcp_ports": [22]}
  }
}
JSON
echo "  [PASS] Terraform output renders as Ansible inventory"
