# Quick Start Guide

Get from a validated vSphere lab to the first higher-ed common infrastructure build.

## Prerequisites Checklist

- [ ] vCenter 8.0 U2+ deployed and accessible
- [ ] 3x PowerEdge hosts added to vCenter
- [ ] PowerStore management IP reachable, REST API enabled
- [ ] Terraform 1.6+, Packer 1.10+, Ansible 2.15+, PowerCLI 13.2+ installed
- [ ] ISO images uploaded to a datastore (Ubuntu 24.04, RHEL 9, Windows 2022)

## Step 1: Configure Environment (2 min)

```bash
cd vmware-reference

# Copy and edit config files
cp config/lab.auto.tfvars.example config/lab.auto.tfvars
cp config/powerstore.env.example config/powerstore.env
cp packer/config/vsphere.pkrvars.hcl.example packer/config/vsphere.pkrvars.hcl
cp packer/config/common.pkrvars.hcl.example packer/config/common.pkrvars.hcl
cp config/inventory/hosts.yml.example config/inventory/hosts.yml

# Edit each file with your lab values
# At minimum: vCenter IP/creds, PowerStore IP/creds, ESXi host FQDNs
```

## Step 2: Initialize (1 min)

```bash
make init
```

## Step 3: Validate the Lab Surface

```bash
make validate-vsphere-lab
```

This checks DNS, NTP reachability where available, and the vCenter HTTPS endpoint for the minimal lab surface.

## Step 4: Build or Select a Linux Template

```bash
make build-template-ubuntu
```

Packer builds an Ubuntu 24.04 template with VMware Tools and stores it in vCenter. If the lab already has a known-good template, update `terraform/stacks/03-workloads/terraform.tfvars` to reference that template instead.

## Step 5: Validate the First Build Contract

```bash
make validate-higher-ed-baseline
```

This validates the higher-ed catalog item, Terraform workload stack, Ansible playbook syntax, and Terraform-to-Ansible inventory handoff.

## Step 6: Deploy Higher-Ed Small Linux

```bash
make setup-tags
make deploy-higher-ed-baseline
```

Terraform creates the VM and applies vSphere tags. The deploy target then renders `config/generated/higher-ed-hosts.yml` from Terraform output and runs `ansible/playbooks/higher-ed-linux-baseline.yml`.

## Step 7: Verify

Check the generated inventory and the VM metadata evidence:

```bash
terraform -chdir=terraform/stacks/03-workloads output vm_inventory
cat config/generated/higher-ed-hosts.yml
```

On the guest, the baseline writes `/etc/pdgeek/higher-ed-baseline.yml`.

## What's Next?

- Run `make demo` for the interactive self-service menu
- Run `make portal` for the web-based self-service portal
- Explore `self-service/catalog/` to customize VM sizes
- Extend `self-service/catalog/higher-ed-small-linux.yml` before adding broader customer-facing builds
- Check `docs/architecture.md` for the full design document
