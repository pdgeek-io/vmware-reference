# VMware Baseline

Production-ready VMware automation baseline for a small higher-ed service VM.

This repository currently supports one validated workflow:

1. Build a hardened Ubuntu 24.04 vSphere template with Packer.
2. Create the vSphere tag categories and tag values used for ownership, showback, backup policy, data classification, lifecycle review, and service ownership.
3. Deploy a small Linux VM from that template with Terraform.
4. Generate an Ansible inventory from Terraform output.
5. Run the higher-ed Linux baseline playbook to finalize and validate the guest.

The supported path is intentionally narrow. Customer-facing code in this repository should represent workflows that are implemented, validated, and repeatable.

## Supported Scope

Included:

- Ubuntu 24.04 Packer template: `packer/builds/linux/ubuntu-2404`
- Linux template cleanup and CIS-oriented hardening hooks
- vSphere VM Terraform module: `terraform/modules/vsphere-vm`
- Workload deployment stack: `terraform/stacks/03-workloads`
- Higher-ed Linux catalog contract: `self-service/catalog/higher-ed-small-linux.yml`
- Linux baseline Ansible playbook: `ansible/playbooks/higher-ed-linux-baseline.yml`
- Terraform-to-Ansible inventory renderer: `scripts/render-terraform-inventory.py`
- Baseline vSphere tag setup script: `scripts/setup-vsphere-tags.ps1`
- Validation suite: `tests/scripts`

Not included in the current supported release:

- Windows, RHEL, or Rocky template builds
- Self-service web portal or API gateway
- ITSM adapters, CMDB sync, approvals, or webhooks
- PowerStore or PowerScale provisioning
- Research storage automation
- Application deployment stacks
- Chargeback reporting
- Broad PowerCLI operations menu

Those areas should be added back only through dedicated feature work with build, deploy, validation, and documentation updates in the same change.

## Requirements

| Component | Minimum | Purpose |
|-----------|---------|---------|
| vCenter | 8.0 U2+ | Template build and VM deployment target |
| Terraform | 1.6+ | vSphere VM deployment |
| Packer | 1.10+ | Ubuntu template build |
| Ansible | 2.15+ | Guest finalization and validation |
| Python | 3.11+ | Inventory rendering |
| PowerShell + PowerCLI | 13.2+ | vSphere tag setup |

The vSphere environment must already exist. This repository does not deploy ESXi, vCenter, VCF, NSX, storage arrays, physical networking, or Dell hardware.

## Configure

Create local configuration from the examples:

```bash
cp terraform/stacks/03-workloads/terraform.tfvars.example terraform/stacks/03-workloads/terraform.tfvars
cp packer/config/vsphere.pkrvars.hcl.example packer/config/vsphere.pkrvars.hcl
cp packer/config/common.pkrvars.hcl.example packer/config/common.pkrvars.hcl
```

Optional lab readiness configuration:

```bash
cp config/vsphere-lab-readiness.env.example config/vsphere-lab-readiness.env
```

Local `*.tfvars`, `*.pkrvars.hcl`, environment files, generated inventories, Terraform cache, and Terraform state are ignored by git.

## Validate

Run the full validation suite:

```bash
make validate
```

Run targeted checks:

```bash
make validate-vsphere-lab
make validate-ubuntu-2404-cis-template
make validate-higher-ed-baseline
```

## Build

Initialize Terraform, Ansible collections, and Packer plugins:

```bash
make init
```

Build the Ubuntu 24.04 template:

```bash
make build-template-ubuntu
```

## Deploy

Create the required baseline vSphere tags:

```bash
export VSPHERE_SERVER="vcenter.example.edu"
export VSPHERE_USER="administrator@vsphere.local"
export VSPHERE_PASSWORD="..."
make setup-tags
```

Deploy the baseline VM and run the Ansible handoff:

```bash
make deploy-higher-ed-baseline
```

The Terraform handoff writes `config/generated/higher-ed-hosts.yml` and runs `ansible/playbooks/higher-ed-linux-baseline.yml`.

## Operating Contract

The supported workflow is defined by:

- `docs/higher-ed-baseline-mvp.md`
- `self-service/catalog/higher-ed-small-linux.yml`
- `tests/scripts/validate-higher-ed-baseline.sh`

Before adding a new customer-facing capability, include:

- runnable code
- local validation
- CI validation
- operator documentation
- a clean rollback or destroy path where applicable

## License And Contributions

This project is licensed under the Apache License 2.0. See `LICENSE` and `NOTICE`.

Contribution, documentation, and security expectations are defined in `CONTRIBUTING.md` and `SECURITY.md`. Planned work, defects, and future capabilities should be tracked in GitHub Issues before they become customer-facing code.
