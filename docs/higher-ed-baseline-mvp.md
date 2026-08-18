# Higher-Ed Baseline MVP

This is the first common infrastructure build slice for a live vSphere lab. It keeps the workflow narrow:

1. Terraform clones a small Ubuntu VM from the existing template and applies standard vSphere tags.
2. Terraform emits VM inventory, DNS/IPAM placeholder records, chargeback metadata, and app deployment hooks as outputs.
3. When `run_ansible_after_apply=true`, Terraform calls `scripts/render-terraform-inventory.py` during apply to create an Ansible inventory group.
4. The same Terraform apply then calls `ansible-playbook` to apply common Linux services, validate VMware Tools and DNS, write platform metadata, and stage optional app hook scripts.
5. The self-service catalog exposes a single requestable item: `higher-ed-small-linux`.

## Catalog Item

`self-service/catalog/higher-ed-small-linux.yml`

- 2 vCPU, 4 GB RAM, 40 GB OS disk
- Showback and operations tags for department, cost center, project, environment, owner, application, app owner, technical owner, service tier, backup policy, data classification, billing model, and lifecycle review
- DNS/IPAM integration is deliberately a placeholder with no provider credentials
- App hooks point at `ansible/playbooks/higher-ed-linux-baseline.yml`

## Terraform

Use the existing workload stack:

```bash
terraform -chdir=terraform/stacks/03-workloads plan
```

The stack now accepts optional VM fields:

- `tags`
- `chargeback`
- `dns_ipam`
- `app_hooks`
- `validation`
- `userdata`
- `netmask`

Run `make setup-tags` before applying if the lab does not already have the standard tag categories and baseline tags.

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

## Validation

```bash
make validate-higher-ed-baseline
```
