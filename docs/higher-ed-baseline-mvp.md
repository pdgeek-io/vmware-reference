# Higher-Ed Baseline MVP

This is the first common infrastructure build slice for a live vSphere lab. It keeps the workflow narrow:

1. Packer builds `tpl-ubuntu-2404` and runs the Ubuntu CIS-oriented hardening hook.
2. Terraform clones a small Ubuntu VM from that template and applies standard vSphere tags.
3. Terraform emits VM inventory, DNS/IPAM placeholder records, showback metadata, and Ansible handoff hooks as outputs.
4. When `run_ansible_after_apply=true`, Terraform calls `scripts/render-terraform-inventory.py` during apply to create an Ansible inventory group.
5. The same Terraform apply calls `ansible-playbook` to apply common Linux services, validate VMware Tools and DNS, write platform metadata, and stage optional local hook scripts.
6. The catalog contract exposes a single item: `higher-ed-small-linux`.

## Catalog Item

`self-service/catalog/higher-ed-small-linux.yml`

- 2 vCPU, 4 GB RAM, 40 GB OS disk
- Showback and operations tags for department, cost center, project, environment, owner, application, app owner, technical owner, service tier, backup policy, data classification, billing model, lifecycle review, and `ManagedBy/VMware-Automation`
- DNS/IPAM integration is deliberately a placeholder with no provider credentials
- The only validated Ansible hook is `ansible/playbooks/higher-ed-linux-baseline.yml`

## Terraform

Use the workload stack:

```bash
terraform -chdir=terraform/stacks/03-workloads plan
```

The stack accepts these baseline VM metadata fields:

- `tags`
- `chargeback` metadata for showback fields
- `dns_ipam`
- `app_hooks`
- `validation`
- `userdata`
- `netmask`

Run `make setup-tags` before applying if the lab does not already have the standard tag categories and baseline tags.

## Packer CIS Baseline

VM builds should start from a hardened template. The Ubuntu 24.04 build runs `packer/builds/linux/ubuntu-2404/scripts/cis-baseline.sh` as the final guest-side Packer step and writes `/etc/pdgeek/template-hardening/ubuntu-2404-cis.yml` as evidence.

To run Terraform and immediately hand off to Ansible during the same `terraform apply`:

```bash
make deploy-higher-ed-baseline
```

## Ansible

The deploy target sets `run_ansible_after_apply=true`, so Terraform creates the VM and then runs the local Ansible handoff before the apply finishes. To run only the Ansible side after the VM is reachable:

```bash
ansible-playbook -i config/generated/higher-ed-hosts.yml ansible/playbooks/higher-ed-linux-baseline.yml
```

The playbook writes `/etc/pdgeek/higher-ed-baseline.yml`, stages hook scripts under `/opt/pdgeek/hooks.d`, and validates DNS plus TCP port 22 by default.

To force the Terraform-driven Ansible handoff to rerun without changing VM metadata, increment `ansible_handoff_version`.

## VMware Automation Boundary

The catalog item declares `managed_by: VMware Automation`, but this repository does not yet contain VMware Automation service definitions, ITSM adapters, approvals, or portal code. For the lab, `make deploy-higher-ed-baseline` drives Terraform directly so the implementation can be tested before adding a service control plane.

## Validation

```bash
make validate-higher-ed-baseline
```
