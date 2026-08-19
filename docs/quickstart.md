# Quick Start Guide

Get from a validated vSphere lab to the first higher-ed Linux baseline build.

## Prerequisites Checklist

- [ ] vCenter 8.0 U2+ deployed and accessible
- [ ] Target cluster, datastore, port group, resource pool, and VM folder exist
- [ ] Terraform 1.6+, Packer 1.10+, and Ansible 2.15+ installed
- [ ] PowerShell and PowerCLI 13.2+ installed if running `make setup-tags`
- [ ] Ubuntu 24.04 ISO uploaded to a datastore

## Step 1: Configure Environment

```bash
cd vmware-reference

cp terraform/stacks/03-workloads/terraform.tfvars.example terraform/stacks/03-workloads/terraform.tfvars
cp packer/config/vsphere.pkrvars.hcl.example packer/config/vsphere.pkrvars.hcl
cp packer/config/common.pkrvars.hcl.example packer/config/common.pkrvars.hcl
```

Edit each file with the local vCenter, placement, network, template, and VM address values.

## Step 2: Initialize

```bash
make init
```

## Step 3: Validate the Lab Surface

```bash
make validate-vsphere-lab
```

This checks DNS, NTP reachability where available, and the vCenter HTTPS endpoint for the minimal lab surface.

## Step 4: Build or Select the Ubuntu Template

```bash
make validate-ubuntu-2404-cis-template
make build-template-ubuntu
```

If the lab already has a known-good Ubuntu 24.04 template, update `terraform/stacks/03-workloads/terraform.tfvars` to reference that template instead.

See [Ubuntu 24.04 CIS Template Hook](ubuntu-2404-cis-template.md) for the controls, operator variables, and Terraform/Ansible handoff.

## Step 5: Validate the First Build Contract

```bash
make validate-higher-ed-baseline
```

This validates the catalog contract, Terraform workload stack, Ansible playbook syntax, Ubuntu Packer hook, and Terraform-to-Ansible inventory handoff.

## Step 6: Deploy Higher-Ed Small Linux

```bash
export VSPHERE_SERVER="vcenter.lab.example.com"
export VSPHERE_USER="administrator@vsphere.local"
export VSPHERE_PASSWORD="..."
make setup-tags
make deploy-higher-ed-baseline
```

Terraform creates the VM and applies vSphere tags. During the same `terraform apply`, Terraform renders `config/generated/higher-ed-hosts.yml` and runs `ansible/playbooks/higher-ed-linux-baseline.yml`.

## Step 7: Verify

```bash
terraform -chdir=terraform/stacks/03-workloads output vm_inventory
cat config/generated/higher-ed-hosts.yml
```

On the guest, the baseline writes `/etc/pdgeek/higher-ed-baseline.yml`.

## Deferred

The broader service portal, ITSM adapters, storage automation, additional OS templates, and app deployment playbooks are not part of this validated baseline.
