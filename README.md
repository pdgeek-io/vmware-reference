# pdgeek.io — VMware Day 2 Operations

> **Open-source Day 2 IaC for VMware VVF/VCF on PowerEdge + PowerStore**
> Self-service VMs, automated templates, guest automation, and chargeback/showback.

[![pdgeek.io](https://img.shields.io/badge/pdgeek.io-Day%202%20Ops-blue)](https://pdgeek.io)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

Your VCF/VVF environment is deployed. Now what? This repo handles everything after — standing up new VMs that can't be migrated, automating inside the guest OS via VMware Tools, building golden templates, and tracking who's using what with chargeback/showback.

**Built by practitioners, for practitioners.**

## What This Covers (Day 2)

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Day 2 Operations (this repo)                   │
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────────┐   │
│  │ Self-Service │  │   Template  │  │   Chargeback / Showback  │   │
│  │ VM Catalog   │  │   Factory   │  │   Cost tags, rates,      │   │
│  │ PowerCLI /   │  │   Packer    │  │   per-dept reports,      │   │
│  │ FastAPI      │  │   builds    │  │   lifecycle tracking     │   │
│  └─────────────┘  └─────────────┘  └──────────────────────────┘   │
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────────┐   │
│  │   Guest     │  │  Reference  │  │   VM Lifecycle            │   │
│  │ Automation  │  │  Apps       │  │   Idle detection,         │   │
│  │ VMware Tools│  │  nginx,     │  │   rightsizing,            │   │
│  │ (no SSH)    │  │  PostgreSQL │  │   decommission            │   │
│  └─────────────┘  └─────────────┘  └──────────────────────────┘   │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│              Existing VCF / VVF Platform (already deployed)        │
│              PowerEdge (Compute)  +  PowerStore (Storage)          │
└─────────────────────────────────────────────────────────────────────┘
```

## What This Does NOT Cover (Day 0/1)

- VCF deployment, SDDC Manager bring-up, workload domain creation
- ESXi installation, vCenter deployment, cluster creation
- Those are automated by VCF itself — this repo picks up after that

## Quick Start

### Prerequisites

| Component | Minimum Version | Notes |
|-----------|----------------|-------|
| VMware vCenter | 8.0 U2+ | VVF or VCF — already deployed |
| PowerStore | PowerStoreOS 3.5+ | REST API enabled |
| Terraform | 1.6+ | With vsphere + powerstore providers |
| Packer | 1.10+ | With vsphere plugin |
| Ansible | 2.15+ | With vmware and dell collections |
| PowerCLI | 13.2+ | Core of the self-service layer |

### 1. Clone and Configure

```bash
git clone https://github.com/pdgeek-io/vmware-reference.git
cd vmware-reference
cp config/lab.auto.tfvars.example config/lab.auto.tfvars
cp config/powerstore.env.example config/powerstore.env
# Edit with your environment values
```

### 2. Initialize

```bash
make init
```

### 3. Build VM Templates

```bash
make build-templates
```

### 4. Launch the Operations Menu

```bash
make demo
```

## Operations Menu

The interactive PowerCLI menu covers all Day 2 tasks:

```
── Self-Service VMs ─────────────────────────────────
  1) Small Linux       (2 vCPU, 4 GB, Ubuntu 24.04)
  2) Medium Linux      (4 vCPU, 8 GB, RHEL 9)
  3) Large Database    (8 vCPU, 32 GB, PostgreSQL + PowerStore)
  4) Windows Standard  (4 vCPU, 8 GB, Server 2022)
  5) Three-Tier App    (Web + App + Database)

── Guest Automation (VMware Tools) ──────────────────
  6) Run command in guest VM
  7) Get guest system info
  8) Install package in guest
  9) Copy file to/from guest

── Chargeback / Showback ────────────────────────────
 10) Chargeback report (all VMs)
 11) Chargeback by department
 12) Tag a VM for cost tracking
 13) Export chargeback to CSV

── Lifecycle & Operations ───────────────────────────
 14) Lab status dashboard
 15) VM lifecycle report (idle/oversized detection)
 16) Remove a VM
```

## Repository Structure

```
powercli/           PowerCLI module — self-service, chargeback, guest automation
self-service/       VM catalog (YAML) + FastAPI portal + web UI
packer/             Automated VM template builds (Ubuntu, RHEL, Windows)
ansible/            Post-deploy configuration and app installation
terraform/          Terraform modules for VM deployment + storage provisioning
chargeback/         Rate cards, tag setup, report output
reference-vms/      Pre-built app compositions (3-tier app, DB cluster)
pipelines/          CI/CD workflows (GitHub Actions)
config/             Environment-specific configuration (not committed)
docs/               Architecture docs and quickstart guide
tests/              Validation and smoke tests
```

## Key Capabilities

### Self-Service VM Provisioning

Deploy VMs from a YAML catalog. Each catalog item defines CPU, memory, storage, template, and post-deploy automation. Works through PowerCLI, Terraform, or the FastAPI web portal.

```powershell
New-RefVM -Name "dev-web-01" -CatalogItem "small-linux" -IPAddress "10.0.200.50"
```

### VM Templates (Packer)

Automated golden image builds for Ubuntu 24.04, RHEL 9, and Windows Server 2022. Uses `vsphere-iso` builder with pvscsi, vmxnet3, and VMware Tools baked in.

```bash
make build-template-ubuntu
```

### Guest Automation via VMware Tools

Run commands, install packages, and transfer files inside guest VMs — no SSH keys or WinRM needed. Uses `Invoke-VMScript` and `Copy-VMGuestFile` through VMware Tools.

```powershell
# Run a command inside a guest
Invoke-GuestAutomation -VMName "web-01" -Script "nginx -v"

# Install a package without SSH
Invoke-GuestAutomation -VMName "web-01" -Action InstallPackage -PackageName "nginx"

# Copy a config file into the guest
Copy-GuestFile -VMName "web-01" -Source "./nginx.conf" -Destination "/etc/nginx/nginx.conf"
```

### Chargeback / Showback

Track resource consumption per VM and roll it up by department, project, or owner. Configurable rate cards, vSphere tag-based cost center assignment, CSV/JSON export.

```powershell
# Full chargeback report
Get-VMChargeback

# By department
Get-VMChargeback -Department "Engineering" -OutputFormat CSV

# Tag a VM for tracking
Set-VMCostTags -VMName "web-01" -Department "Engineering" -Project "RefApp" -Owner "jsmith"

# Find idle/oversized VMs
Get-VMLifecycle -ShowRightsizing
```

### Reference Applications

One-command deployment of a three-tier app (nginx + Flask + PostgreSQL) with PowerStore-backed database storage and Ansible post-deploy configuration.

```bash
make deploy-three-tier
```

## Contributing

Contributions welcome! This is a community project at [pdgeek.io](https://pdgeek.io). Open an issue or submit a PR.

## License

Apache License 2.0. See [LICENSE](LICENSE).

---

*An open-source project from [pdgeek.io](https://pdgeek.io) — practical Day 2 VMware operations for the community.*
