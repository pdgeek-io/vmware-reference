# VMware Day 2 Operations

> **Open-source Day 2 IaC for VMware VVF/VCF on PowerEdge + PowerStore + PowerScale**
> Self-service VMs, research storage, ITSM integration, and chargeback — built for higher ed.

[![pdgeek.io](https://img.shields.io/badge/pdgeek.io-Day%202%20Ops-blue)](https://pdgeek.io)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

Your VCF/VVF environment is deployed. Now what? This repo handles everything after — standing up Linux and Windows VMs, provisioning research NFS shares on PowerScale with grant tracking, integrating with your ITSM (ServiceNow, TeamDynamix), managing CMDB assets, and tracking chargeback by department, grant, or cost center.

**Built by practitioners, for practitioners. Designed for Texas higher ed, useful everywhere.**

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
- Those are automated by VCF itself — this repo picks up after that

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

### 4. Launch the Operations Menu or API Portal

```bash
make demo     # Interactive PowerCLI menu
make portal   # ITSM-ready REST API (http://localhost:8080/api/docs)
```

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
