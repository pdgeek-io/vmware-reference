# Quick Start Guide

Get from zero to a running three-tier app in 15 minutes.

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

## Step 3: Deploy Foundation (3 min)

```bash
source config/powerstore.env
make deploy-foundation
```

This creates:
- PowerStore volumes for VMFS datastores
- vSphere datacenter, cluster, resource pools, and folders
- VMFS datastores mapped to PowerStore volumes

## Step 4: Build Templates (5 min)

```bash
make build-template-ubuntu
```

Packer builds an Ubuntu 24.04 template with VMware Tools, stores it in vCenter.

## Step 5: Deploy Three-Tier App (4 min)

```bash
make deploy-three-tier
```

This deploys:
- **Web VM**: nginx serving the reference landing page
- **App VM**: Flask API showing infrastructure details
- **DB VM**: PostgreSQL with sample data on PowerStore storage

## Step 6: Verify

Open a browser to the web VM IP — you'll see the pdgeek.io reference architecture landing page.

## What's Next?

- Run `make demo` for the interactive self-service menu
- Run `make portal` for the web-based self-service portal
- Explore `self-service/catalog/` to customize VM sizes
- Check `docs/architecture.md` for the full design document
