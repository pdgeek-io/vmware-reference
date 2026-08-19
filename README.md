# VMware Reference Baseline

This repository currently contains one validated near-term automation slice for a higher-ed VMware lab:

1. Build an Ubuntu 24.04 vSphere template with Packer.
2. Apply a narrow CIS-oriented hardening hook during the template build.
3. Create the vSphere tag categories and tag values used by the baseline.
4. Clone one small Linux VM with `terraform/stacks/03-workloads`.
5. Emit Terraform VM metadata for DNS/IPAM placeholder work, showback metadata, and Ansible handoff.
6. Render a generated Ansible inventory.
7. Run `ansible/playbooks/higher-ed-linux-baseline.yml` to finalize and validate the guest.

Everything outside that path is intentionally deferred until it is implemented and validated.

## Scope

Included now:

- Ubuntu 24.04 Packer template under `packer/builds/linux/ubuntu-2404`
- Baseline Linux security-agent cleanup hook under `packer/builds/linux/common`
- vSphere VM Terraform module under `terraform/modules/vsphere-vm`
- Workload stack under `terraform/stacks/03-workloads`
- Higher-ed baseline catalog contract under `self-service/catalog/higher-ed-small-linux.yml`
- Linux baseline Ansible playbook and supporting roles under `ansible/playbooks` and `ansible/roles`
- Terraform-to-Ansible inventory renderer under `scripts/render-terraform-inventory.py`
- Baseline vSphere tag setup script under `scripts/setup-vsphere-tags.ps1`
- Validation scripts under `tests/scripts`

Deferred:

- Self-service API or web portal
- ITSM adapters, CMDB sync, approvals, and webhooks
- Research storage automation
- PowerStore and PowerScale provisioning modules
- Chargeback reporting
- Windows, RHEL, and Rocky template tracks
- Reference applications and app deployment playbooks
- Broad PowerCLI operations menu and day-2 lifecycle tooling

## Prerequisites

| Component | Minimum Version | Notes |
|-----------|-----------------|-------|
| vCenter | 8.0 U2+ | Already deployed and reachable |
| Terraform | 1.6+ | Uses the vSphere provider |
| Packer | 1.10+ | Uses the vSphere builder |
| Ansible | 2.15+ | Runs the Linux baseline handoff |
| PowerShell + PowerCLI | PowerCLI 13.2+ | Only needed for `make setup-tags` |
| Python | 3.11+ | Used by the inventory renderer |

## Configure

Copy the examples that match the task you are running:

```bash
cp terraform/stacks/03-workloads/terraform.tfvars.example terraform/stacks/03-workloads/terraform.tfvars
cp packer/config/vsphere.pkrvars.hcl.example packer/config/vsphere.pkrvars.hcl
cp packer/config/common.pkrvars.hcl.example packer/config/common.pkrvars.hcl
```

For lab readiness checks, optionally copy:

```bash
cp config/vsphere-lab-readiness.env.example config/vsphere-lab-readiness.env
```

Local `*.tfvars`, `*.pkrvars.hcl`, environment files, generated inventories, and Terraform state are ignored by git.

## Validate

Run the full near-term validation suite:

```bash
make validate
```

Targeted checks:

```bash
make validate-vsphere-lab
make validate-ubuntu-2404-cis-template
make validate-higher-ed-baseline
```

## Build And Deploy

Initialize the baseline toolchain:

```bash
make init
```

Build the Ubuntu 24.04 template:

```bash
make build-template-ubuntu
```

Create the baseline vSphere tag categories and values:

```bash
export VSPHERE_SERVER="vcenter.lab.example.com"
export VSPHERE_USER="administrator@vsphere.local"
export VSPHERE_PASSWORD="..."
make setup-tags
```

Deploy the higher-ed Linux baseline and run the Terraform-driven Ansible handoff:

```bash
make deploy-higher-ed-baseline
```

The handoff writes `config/generated/higher-ed-hosts.yml` and then runs `ansible/playbooks/higher-ed-linux-baseline.yml`.

## Contract

The first build contract is documented in [docs/higher-ed-baseline-mvp.md](docs/higher-ed-baseline-mvp.md). Treat that document, `self-service/catalog/higher-ed-small-linux.yml`, and `tests/scripts/validate-higher-ed-baseline.sh` as the source of truth for what is currently validated.
