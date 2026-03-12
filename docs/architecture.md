# Architecture Overview

## pdgeek.io — VMware VVF/VCF Reference Architecture

This document describes the full-stack reference architecture for VMware VVF/VCF on PowerEdge compute and PowerStore storage.

## Hardware Bill of Materials

| Component | Model | Qty | Role |
|-----------|-------|-----|------|
| Compute | PowerEdge R760 | 3 | ESXi hosts (vSphere cluster) |
| Storage | PowerStore 3200T | 1 | Block storage (iSCSI/FC) |
| Network | PowerSwitch S5248F-ON | 2 | 25GbE ToR switches |
| Management | iDRAC9 Enterprise | 3 | Out-of-band management |

## Network Design

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
1. Terraform (01-foundation)
   └── Creates PowerStore volumes
   └── Configures vSphere datacenter, cluster, datastores

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
- Use the `terraform/stacks/04-vcf-domain/` stack for workload domain provisioning
- NSX is mandatory — networking uses NSX segments instead of DVS port groups
- SDDC Manager handles lifecycle management
- vSAN may be used instead of/alongside PowerStore for HCI storage
