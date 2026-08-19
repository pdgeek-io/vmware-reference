# PD Geek IO Validated Private Cloud

> **Your grant is approved. Your environment is ready.**
> Dell hardware. VMware private cloud. ITSM-driven self-service. Day 2 operations as code.

[![pdgeek.io](https://img.shields.io/badge/pdgeek.io-Day%202%20Ops-blue)](https://pdgeek.io)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

PD Geek IO is a validated private cloud automation framework for institutions that want governed self-service on Dell hardware and VMware VVF/VCF. It assumes the private cloud has already been brought up against the appropriate Dell, VMware, and network/storage reference architecture, then validates and operates that environment with repeatable automation and evidence.

The higher-ed research computing scenario is the first packaged use case. Researchers get same-day access to compute and storage. Grants fund the shared pool. Compliance is built in. IT gets visibility. Everyone wins.

No more 100+ unmanaged servers in closets. No more zombie hardware from grants that ended 7 years ago. No more grad students as sysadmins.

**Built by practitioners, for practitioners. Designed for Texas higher ed, useful everywhere.**

### What Researchers Get

- Compute and storage ready the day their grant starts — no PO, no hardware chase
- Self-service catalog — pick a size, get an environment
- Grant compliance met out of the box (NIST, FERPA, HIPAA, CUI, export control)
- Their data managed, backed up, and archived when the grant ends

### What the Institution Gets

- Shadow IT consolidated into a managed, compliant platform
- Every dollar tracked to a grant, audit-ready
- Self-funding model — grants pay for usage, the pool grows
- Reduced risk from unmanaged, unpatched, orphaned infrastructure

## Product Positioning

Open-source Day 2 IaC for a validated private cloud built around:

- Dell PowerEdge compute
- Dell PowerStore block storage
- Dell PowerScale file storage
- VMware VVF/VCF private cloud
- Infoblox or equivalent enterprise DNS/IPAM/DDI
- ITSM-driven service requests and approvals
- Git-based automation, validation, and evidence

Validation boundary: Dell, VMware, storage, and network bring-up is treated as a prerequisite. This repo does not replace vendor deployment guidance, VCF bring-up, or Dell validated designs. It validates that the resulting platform exposes the expected Day 2 control points and then drives customer-facing automation from those control points.

Terraform owns infrastructure state after the platform exists: vSphere objects, VM lifecycle, networks, DNS/IPAM records, storage objects, tags, and placement.

Packer owns hardened base images. Linux templates run a shared CIS-aligned baseline during image build before Terraform can deploy them as catalog VMs.

Ansible owns configuration and Day 2 operations: OS finalization, agents, patching, application deployment, service validation, backup checks, drift reports, remediation, and evidence.

VMware Automation is the expected service control plane for managed customer workflows. ITSM systems such as ServiceNow, TeamDynamix, or a generic webhook can still submit and approve requests, but VMware Automation owns the customer-facing service lifecycle while this repo provides the Terraform and Ansible implementation behind those services.

For lab and PoC validation, the [vSphere lab validation path](docs/vsphere-lab-validation.md) checks the minimal ESXi + vCenter readiness surface while the repo proves service-catalog workflows such as VM provisioning, database deployment, application deployment, evidence capture, and UX feedback.

The first materialized build is [Higher-Ed Small Linux](docs/higher-ed-baseline-mvp.md). It provisions a small Linux service VM, applies showback/ownership/backup/data-classification/managed-by tags, emits DNS/IPAM and app-hook handoff data, renders a Terraform-generated Ansible inventory, and runs the higher-ed Linux baseline playbook. The local Makefile path exists so the implementation can be validated directly while the repo grows toward VMware Automation-managed services.

## Under the Hood

Validated Day 2 private cloud automation for VMware VVF/VCF on an already-deployed PowerEdge + PowerStore + PowerScale architecture. Self-service VMs, research storage, ITSM integration, DNS/IPAM, multi-tenancy, CMDB, and chargeback.

## What This Covers (Day 2)

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Day 2 Operations (this repo)                     │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────────────┐ │
│  │ Self-Service │  │   Template  │  │  Research Storage             │ │
│  │ VM Catalog   │  │   Factory   │  │  PowerScale NFS              │ │
│  │ Linux +      │  │   Packer    │  │  Entra ID / AD (RFC2307)    │ │
│  │ Windows      │  │   builds    │  │  Grant tracking, quotas      │ │
│  └─────────────┘  └─────────────┘  └──────────────────────────────┘ │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────────────┐ │
│  │ ITSM / API  │  │ Chargeback  │  │   VM Lifecycle               │ │
│  │ Gateway     │  │ / Showback  │  │   Idle detection,            │ │
│  │ ServiceNow, │  │ Rate cards, │  │   rightsizing,               │ │
│  │ TeamDynamix,│  │ grant-based │  │   decommission               │ │
│  │ CMDB sync   │  │ billing     │  │                              │ │
│  └─────────────┘  └─────────────┘  └──────────────────────────────┘ │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────────────┐ │
│  │   Guest     │  │  Reference  │  │   Compliance                 │ │
│  │ Automation  │  │  Apps       │  │   TAC 202 classification,    │ │
│  │ VMware Tools│  │  IIS, SQL,  │  │   FERPA/HIPAA/export ctrl,   │ │
│  │ (no SSH)    │  │  AD, .NET,  │  │   federal grant retention,   │ │
│  │             │  │  nginx, PG  │  │   state fiscal year          │ │
│  └─────────────┘  └─────────────┘  └──────────────────────────────┘ │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│            Existing VCF / VVF Platform (already deployed)            │
│  PowerEdge (Compute)  +  PowerStore (Block)  +  PowerScale (File)   │
└──────────────────────────────────────────────────────────────────────┘
```

## What This Does NOT Cover (Day 0/1)

- VCF deployment, SDDC Manager bring-up, workload domain creation
- ESXi installation, vCenter deployment, cluster creation
- Hardware, storage, network, and platform design validation owned by Dell, VMware, and the customer's architecture process
- Those are automated by VCF itself or by vendor-aligned Day 0/1 processes. This repo picks up after that baseline exists.

## Quick Start

### Prerequisites

| Component | Minimum Version | Notes |
|-----------|----------------|-------|
| VMware vCenter | 8.0 U2+ | VVF or VCF — already deployed |
| PowerStore | PowerStoreOS 3.5+ | REST API enabled |
| PowerScale | OneFS 9.5+ | For research NFS shares (optional) |
| Terraform | 1.6+ | vsphere + powerstore + powerscale providers |
| Packer | 1.10+ | With vsphere plugin |
| Ansible | 2.15+ | With vmware, dell, and windows collections |
| PowerCLI | 13.2+ | Core of the self-service layer |
| Python | 3.11+ | For the ITSM API gateway (FastAPI) |

### 1. Clone and Configure

```bash
git clone https://github.com/pdgeek-io/vmware-reference.git
cd vmware-reference
cp config/lab.auto.tfvars.example config/lab.auto.tfvars
cp config/powerstore.env.example config/powerstore.env
cp config/powerscale.env.example config/powerscale.env   # If using research shares
cp config/itsm.env.example config/itsm.env               # If using ITSM integration
# Edit with your environment values
```

### 2. Initialize

```bash
make init
```

### 3. Build VM Templates

```bash
make build-templates   # Ubuntu 24.04, RHEL 9, Windows 2022, Windows 2025
```

Weekly template hygiene is handled by the GitLab scheduled Packer rebuild. See [docs/weekly-packer-rebuild.md](docs/weekly-packer-rebuild.md) for the Friday midnight schedule.

### 4. Launch the Operations Menu or API Portal

```bash
make demo     # Interactive PowerCLI menu
make portal   # ITSM-ready REST API (http://localhost:8080/api/docs)
```

### First Build: Higher-Ed Small Linux

This is the smallest end-to-end private-cloud automation slice:

1. Packer builds a CIS-aligned Linux template and writes template evidence.
2. `make setup-tags` creates the vSphere tag categories and baseline tag values used for showback, ownership, backup policy, data classification, lifecycle review, and VMware Automation management ownership.
3. `terraform/stacks/03-workloads` clones the VM from the hardened template and applies the vSphere tags.
4. Terraform outputs VM inventory, DNS/IPAM placeholder records, chargeback metadata, and app-deployment hooks.
5. With `run_ansible_after_apply=true`, Terraform turns its own output into `config/generated/higher-ed-hosts.yml`.
6. The same Terraform apply calls `ansible/playbooks/higher-ed-linux-baseline.yml`, which configures the guest, writes metadata evidence, and validates DNS plus TCP reachability.

Operate it with:

```bash
make validate-higher-ed-baseline
make setup-tags
make deploy-higher-ed-baseline
```

Read [docs/higher-ed-baseline-mvp.md](docs/higher-ed-baseline-mvp.md) before changing the first build contract.

## Operations Menu

The interactive PowerCLI menu covers all Day 2 tasks:

```
── Linux VMs ──────────────────────────────────────
  1) Small Linux       (2 vCPU, 4 GB, Ubuntu 24.04)
  2) Medium Linux      (4 vCPU, 8 GB, RHEL 9)
  3) Large Database    (8 vCPU, 32 GB, PostgreSQL + PowerStore)

── Windows VMs ────────────────────────────────────
  4) Windows Standard  (4 vCPU, 8 GB, Server 2022)
  W) Windows IIS       (4 vCPU, 8 GB, IIS Web Server)
  S) Windows SQL       (8 vCPU, 32 GB, SQL Server + PowerStore)
  N) Windows .NET App  (4 vCPU, 16 GB, .NET 8 Runtime)
  D) Windows DC        (4 vCPU, 8 GB, Active Directory)

── Compositions ───────────────────────────────────
  5) Three-Tier Linux  (nginx + Flask + PostgreSQL)
  T) Three-Tier Windows (IIS + .NET + SQL Server)

── Research Storage (PowerScale) ──────────────────
  R) New researcher share  (NFS, Entra ID/AD, quota)
  G) Research share report (grants, usage, expiration)

── Guest Automation (VMware Tools) ────────────────
  6-9) Run commands, get info, install packages, copy files

── Chargeback / Showback ──────────────────────────
 10-13) Reports, department filtering, tagging, CSV export

── Lifecycle & Operations ─────────────────────────
 14-16) Lab dashboard, idle detection, VM removal
```

## ITSM Integration

The API gateway (`make portal`) provides a REST interface for ITSM platforms to drive provisioning, track assets, and sync billing data.

### Supported ITSM Platforms

| Platform | Adapter | Auth | Notes |
|----------|---------|------|-------|
| **TeamDynamix** | `teamdynamix` | Bearer token (admin API) | Dominant in higher ed. Ticket + CMDB asset sync. |
| **ServiceNow** | `servicenow` | Basic auth (REST API) | RITM creation, CMDB CI sync (`cmdb_ci_vm_instance`). |
| **Generic** | `generic` | Bearer token / webhook | Works with Freshservice, Jira SM, Cherwell, etc. |

### API Endpoints

```
POST /api/v1/requests/vm              Submit VM provisioning request
POST /api/v1/requests/research-share  Submit research share request
GET  /api/v1/requests                 List/filter service requests
PATCH /api/v1/requests/{id}           Approve, cancel, update requests

GET  /api/v1/cmdb/assets              List CMDB assets (VMs, shares)
POST /api/v1/cmdb/assets              Import existing assets
POST /api/v1/cmdb/sync                Full sync to external ITSM CMDB
GET  /api/v1/cmdb/summary             Dashboard: counts + costs

GET  /api/v1/chargeback/rates         Current rate card
GET  /api/v1/chargeback/research-shares  Per-share costs by grant/dept
GET  /api/v1/chargeback/summary       High-level cost summary

POST /api/v1/webhooks/servicenow      Inbound ServiceNow webhooks
POST /api/v1/webhooks/teamdynamix     Inbound TeamDynamix webhooks
POST /api/v1/webhooks/generic         Inbound generic ITSM webhooks

GET  /api/v1/catalog                  Browse service catalog
GET  /api/v1/health                   Health check
```

### Request Workflow

```
ITSM User → Submit Request → [Pending Approval] → Approved → Provisioning → Completed
                                    ↑                              ↓
                             ITSM Webhook              CMDB Asset Created
                           (approve/deny)            (synced to ITSM CMDB)
```

## Research Storage (PowerScale)

Self-service NFS shares for researchers, authenticated via Entra ID / Active Directory using RFC2307 UID mapping.

```powershell
New-ResearcherShare -Name "genomics-2025" -Department "Biology" `
    -PIName "Dr. Jane Smith" -PIUsername "jsmith" -PIEmail "jsmith@university.edu" `
    -GrantID "NIH-R01-GM123456" -GrantAgency "NIH" -GrantExpiration "2027-08-31" `
    -QuotaGB 5000 -DataClassification "controlled"
```

Each share tracks: grant ID, agency, PI, expiration, quota, data classification, compliance flags (FERPA/HIPAA/export control/CUI), IRB/IACUC numbers, and cost center.

### Compliance

- **Data classification** aligned with TAC 202 (public, controlled, confidential, restricted)
- **Auto-escalation**: HIPAA/CUI/export-controlled data automatically upgraded to `restricted`
- **NFS security**: `krb5p` for restricted, `krb5` for confidential, `AUTH_SYS` for standard
- **Retention**: Per-agency (NIH 7yr, NSF 5yr, DOE 7yr, state 5yr) — shares go read-only on expiry
- **Audit logging**: Enabled for confidential/restricted data, 7-year log retention
- **State fiscal year**: September 1 start, reflected in chargeback reports

## Repository Structure

```
self-service/
  api/                ITSM-ready REST API gateway (FastAPI)
    routers/          Catalog, requests, CMDB, chargeback, webhooks
    adapters/         ServiceNow, TeamDynamix, generic ITSM adapters
    models/           Pydantic models for requests, assets, CMDB
  catalog/            Service catalog items (YAML)
  ui/                 Web portal frontend

powercli/             PowerCLI module — self-service, chargeback, research shares
  modules/PDGeekRef/  Public functions: New-RefVM, New-ResearcherShare, etc.
  scripts/            Interactive operations menu

terraform/
  modules/            Reusable modules (vsphere-vm, powerstore, powerscale-shares)
  stacks/             Composable stacks (foundation, workloads, research-storage)

packer/               VM templates (Ubuntu 24.04, RHEL 9, Windows 2022/2025)
ansible/              Roles + playbooks (Linux, Windows, IIS, SQL, AD, PowerScale NFS)
chargeback/           Rate cards, tag setup
config/               Environment configs (not committed), compliance defaults
tests/                Validation and smoke tests (Bash + PowerShell)
```

## Key Capabilities

### Self-Service VM Provisioning

```powershell
New-RefVM -Name "dev-web-01" -CatalogItem "small-linux" -IPAddress "10.0.200.50"
New-RefVM -Name "campus-iis" -CatalogItem "windows-web-server" -IPAddress "10.0.200.60"
```

### Guest Automation via VMware Tools

```powershell
Invoke-GuestAutomation -VMName "web-01" -Action InstallPackage -PackageName "nginx"
Copy-GuestFile -VMName "web-01" -Source "./nginx.conf" -Destination "/etc/nginx/nginx.conf"
```

### Chargeback / Showback

```powershell
Get-VMChargeback -Department "Engineering" -OutputFormat CSV
Get-ResearchShareReport -GrantAgency "NIH"
```

### ITSM-Driven Provisioning

```bash
# Submit a VM request via API (triggers ITSM workflow)
curl -X POST http://localhost:8080/api/v1/requests/vm \
  -H "Content-Type: application/json" \
  -d '{"catalog_item":"small-linux","vm_name":"dev-01","ip_address":"10.0.200.50",
       "department":"Computer Science","requestor_email":"admin@university.edu",
       "requestor_name":"IT Admin","itsm_ticket_id":"RITM0012345"}'
```

## Contributing

Contributions welcome! This is a community project at [pdgeek.io](https://pdgeek.io). Open an issue or submit a PR.

## License

Apache License 2.0. See [LICENSE](LICENSE).

---

*An open-source project from [pdgeek.io](https://pdgeek.io) — practical Day 2 VMware operations for the community.*
