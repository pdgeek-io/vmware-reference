# pdgeek.io — VMware VVF/VCF Reference Architecture

> **Open-source IaC for VMware on PowerEdge + PowerStore**
> Self-service VM provisioning, automated template builds, and reference application deployments.

[![pdgeek.io](https://img.shields.io/badge/pdgeek.io-reference--architecture-blue)](https://pdgeek.io)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

An open-source, community-driven reference architecture for running VMware VVF/VCF on PowerEdge servers with PowerStore storage. Everything is Infrastructure as Code — Terraform, Packer, Ansible, and PowerCLI — ready to clone and run in your lab.

**Built by practitioners, for practitioners.**

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Self-Service Portal                         │
│              (PowerCLI Menu / FastAPI / Catalog YAML)               │
├─────────────────────────────────────────────────────────────────────┤
│                     Reference Applications                         │
│         ┌──────────┐  ┌──────────┐  ┌──────────────┐              │
│         │  Nginx   │  │  Flask   │  │  PostgreSQL  │              │
│         │  Web Tier│  │  App Tier│  │  DB Tier     │              │
│         └──────────┘  └──────────┘  └──────────────┘              │
├─────────────────────────────────────────────────────────────────────┤
│                     VM Templates (Packer)                           │
│      Ubuntu 24.04 │ RHEL 9 │ Windows Server 2022/2025              │
├─────────────────────────────────────────────────────────────────────┤
│                  VMware vSphere / VCF Platform                      │
│   ┌────────────┐  ┌────────────┐  ┌────────────────────┐          │
│   │ vCenter    │  │ Clusters   │  │ Distributed Switch │          │
│   │ Datacenter │  │ Resource   │  │ Port Groups        │          │
│   │ Folders    │  │ Pools      │  │ NSX (VCF)          │          │
│   └────────────┘  └────────────┘  └────────────────────┘          │
├─────────────────────────────────────────────────────────────────────┤
│                     Physical Infrastructure                        │
│   ┌──────────────────────┐    ┌────────────────────────┐          │
│   │   PowerEdge          │    │   PowerStore            │          │
│   │   R760 / R660        │    │   1200T / 3200T        │          │
│   │   (Compute)          │    │   (Block Storage)      │          │
│   └──────────────────────┘    └────────────────────────┘          │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

| Component | Minimum Version | Notes |
|-----------|----------------|-------|
| VMware vCenter | 8.0 U2+ | VVF or VCF licensed |
| PowerStore | PowerStoreOS 3.5+ | REST API enabled |
| PowerEdge | 16th Gen (R760/R660) | iDRAC9 configured |
| Terraform | 1.6+ | With vsphere + powerstore providers |
| Packer | 1.10+ | With vsphere plugin |
| Ansible | 2.15+ | With vmware and dell collections |
| PowerCLI | 13.2+ | For self-service scripts |

### 1. Clone and Configure

```bash
git clone https://github.com/pdgeek-io/vmware-reference.git
cd vmware-reference

# Copy example configs and fill in your lab values
cp config/lab.auto.tfvars.example config/lab.auto.tfvars
cp config/powerstore.env.example config/powerstore.env
cp config/inventory/hosts.yml.example config/inventory/hosts.yml

# Edit with your lab-specific values
vim config/lab.auto.tfvars
```

### 2. Initialize

```bash
make init
```

### 3. Build VM Templates

```bash
make build-templates
```

### 4. Deploy Foundation Infrastructure

```bash
make deploy-foundation
```

### 5. Launch Self-Service Demo

```bash
# PowerCLI interactive menu
make demo

# OR deploy a three-tier app in one command
make deploy-three-tier
```

## Repository Structure

```
terraform/          Terraform modules and stacks (PowerStore + vSphere + VCF)
packer/             Automated VM template builds (Ubuntu, RHEL, Windows)
ansible/            Configuration management and app deployment
powercli/           PowerCLI self-service module and scripts
self-service/       VM catalog definitions and optional web portal
reference-vms/      Pre-built application compositions (3-tier app, DB cluster)
pipelines/          CI/CD workflows (GitHub Actions, GitLab CI)
config/             Environment-specific configuration (not committed)
docs/               Architecture documentation and runbooks
tests/              Validation and smoke tests
```

## Automation Layers

| Layer | Tool | What It Does |
|-------|------|-------------|
| Storage | Terraform (dell/powerstore) | Provisions volumes, host mappings, snapshot policies |
| Platform | Terraform (hashicorp/vsphere) | Configures datacenter, clusters, networking, datastores |
| Templates | Packer (vsphere-iso) | Builds hardened OS templates with VMware Tools |
| Configuration | Ansible | Post-deploy OS config, app installation, DB setup |
| Self-Service | PowerCLI / FastAPI | Catalog-driven VM provisioning |
| Validation | InSpec / Shell | Verifies deployments match desired state |

## Use Cases

1. **"Storage to VM in 5 Minutes"** — `make deploy-foundation` provisions PowerStore volumes, creates VMFS datastores, and stands up the vSphere foundation.

2. **"Self-Service VM Catalog"** — `make demo` walks through the interactive PowerCLI menu for catalog-driven VM deployment.

3. **"One-Click Three-Tier App"** — `make deploy-three-tier` deploys nginx + Flask + PostgreSQL on three VMs with PowerStore-backed storage.

4. **"Template Factory"** — `make build-templates` shows automated, repeatable OS image creation with Packer.

5. **"VCF Workload Domain"** — `make deploy-vcf-domain` (requires VCF) automates workload domain provisioning via SDDC Manager.

## Contributing

Contributions welcome! This is a community project at [pdgeek.io](https://pdgeek.io). Open an issue or submit a PR.

## License

Apache License 2.0. See [LICENSE](LICENSE).

---

*An open-source project from [pdgeek.io](https://pdgeek.io) — practical infrastructure code for the community.*
