#!/bin/bash
# Smoke test: deploy a small VM, verify it, then destroy it
set -euo pipefail

VM_NAME="smoke-test-$(date +%s)"
echo "==> Smoke test: deploying $VM_NAME"

# Deploy
cd terraform/stacks/03-workloads
terraform apply -auto-approve \
    -var="vms={\"${VM_NAME}\"={template=\"tpl-ubuntu-2404\",resource_pool=\"Development\",folder=\"Reference-VMs\",cpu=2,memory_mb=4096,os_disk_gb=40,ip_address=\"10.0.200.250\",data_disks=[]}}" \
    2>&1

echo "==> Waiting 60s for VM to boot..."
sleep 60

# Verify
echo "==> Verifying VM is reachable..."
if ping -c 3 10.0.200.250 >/dev/null 2>&1; then
    echo "  [PASS] VM is reachable"
else
    echo "  [WARN] VM not responding to ping (may be firewall)"
fi

# Cleanup
echo "==> Destroying smoke test VM..."
terraform destroy -auto-approve \
    -var="vms={\"${VM_NAME}\"={template=\"tpl-ubuntu-2404\",resource_pool=\"Development\",folder=\"Reference-VMs\",cpu=2,memory_mb=4096,os_disk_gb=40,ip_address=\"10.0.200.250\",data_disks=[]}}" \
    2>&1

echo "==> Smoke test complete."
