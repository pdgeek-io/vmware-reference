# Architecture Overview

## pdgeek.io — Validated Private Cloud Automation

This is a Day 2 automation framework for a private cloud that has already been deployed against the appropriate Dell, VMware, storage, and network reference architecture. The repo does not certify the physical build. It validates the operational surface after bring-up and turns that validated surface into customer-facing self-service.

The first packaged outcome is higher-ed research computing: same-day, grant-ready compute and storage for researchers. It runs on VMware VVF/VCF with PowerEdge and PowerStore, but to the researcher, it's just "my environment is ready."

### Platform Positioning

This platform delivers outcomes, not infrastructure:

- **"Your environment is ready"** — not "we provisioned a VM"
- **"Your grant requirements are met"** — not "we're NIST 800-171 compliant"
- **"Your spend is tracked"** — not "we run chargeback reports"

The underlying technology is an implementation detail. Researchers interact with a self-service catalog and get results. See the [Adoption Playbook](adoption-playbook.md) for how to position and sell this at your institution.

---

## Validation Boundary

The expected starting point is an environment already built from vendor-aligned architecture:

- Dell PowerEdge compute sized and cabled according to the approved design
- Dell PowerStore and optionally PowerScale deployed according to vendor guidance
- VMware vSphere Foundation or VMware Cloud Foundation brought up successfully
- Network, storage, management, and workload VLANs available and routed as designed
- DNS/IPAM/DDI available through Infoblox or an equivalent enterprise platform
- ITSM, identity, monitoring, and backup integrations identified

This repo validates and automates the Day 2 layer:

- vCenter inventory, clusters, datastores, folders, tags, and placement targets
- DNS/IPAM record lifecycle
- VM templates and guest customization
- Storage objects exposed to the virtualization layer
- ITSM request intake, approvals, CMDB updates, chargeback/showback, and evidence
- Ansible configuration, patching, compliance checks, and application deployment

## Technical Reference

The automation reference target for VMware VVF/VCF on PowerEdge compute and PowerStore storage.

## Example Hardware Bill of Materials

This is an example shape for local development and customer conversations, not the authoritative build standard. Final sizing and topology should come from the vendor/customer reference architecture.

| Component | Model | Qty | Role |
|-----------|-------|-----|------|
| Compute | PowerEdge R760 | 3 | ESXi hosts (vSphere cluster) |
| Storage | PowerStore 3200T | 1 | Block storage (iSCSI/FC) |
| Network | PowerSwitch S5248F-ON | 2 | 25GbE ToR switches |
| Management | iDRAC9 Enterprise | 3 | Out-of-band management |

## Example Network Design

These VLANs represent the automation contract the repo expects to find. The exact addressing and segmentation belong to the customer's validated architecture.

```
VLAN 100 — Management     (10.0.100.0/24)  vCenter, ESXi mgmt, iDRAC
VLAN 200 — VM Workload    (10.0.200.0/24)  VM traffic
VLAN 300 — Storage        (10.0.300.0/24)  iSCSI to PowerStore
VLAN 400 — vMotion        (10.0.400.0/24)  Live migration
```

## Storage Design

### Default: VMFS on PowerStore

PowerStore volumes are presented to ESXi hosts via iSCSI and formatted as VMFS 6 datastores. This is the simplest path and works with both VVF and VCF.

```
PowerStore Volume  →  iSCSI  →  ESXi Host  →  VMFS Datastore  →  VM Disks
```

### Advanced: vVols on PowerStore

For per-VM storage policies, PowerStore supports VMware vVols via its built-in VASA provider. This enables:
- Per-VM snapshot policies
- Storage-based replication at the VM level
- QoS policies per VM

## Automation Flow

```
0. Existing validated platform
   └── Dell/VMware/storage/network reference architecture already deployed
   └── vCenter or VCF operational, storage online, networks routable

1. Terraform (01-foundation)
   └── Validates and manages Day 2 platform objects
   └── Creates PowerStore volumes, vSphere folders, tags, and placement objects

2. Terraform (02-networking)
   └── Creates distributed switch and port groups

3. Packer
   └── Builds OS templates (Ubuntu, RHEL, Windows)
   └── Stores as vSphere templates

4. Terraform (03-workloads) or PowerCLI
   └── Deploys VMs from templates
   └── Applies cloud-init customization

5. Ansible
   └── Post-deploy configuration
   └── App installation (nginx, PostgreSQL, Docker)
```

## VCF-Specific Considerations

When running VMware Cloud Foundation instead of standalone vSphere:
- Treat SDDC Manager and workload domain bring-up as Day 0/1 prerequisites unless explicitly working in a lab branch
- Use the `terraform/stacks/04-vcf-domain/` stack only where the customer architecture allows automation at that layer
- NSX is expected for VCF designs, so networking may use NSX segments instead of DVS port groups
- SDDC Manager handles lifecycle management
- vSAN may be used instead of/alongside PowerStore for HCI storage
