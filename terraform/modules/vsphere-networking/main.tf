# =============================================================================
# VMware vSphere — Distributed Switch & Port Groups
# Network foundation for VM workloads
# =============================================================================

data "vsphere_datacenter" "dc" {
  name = var.datacenter_name
}

data "vsphere_host" "hosts" {
  for_each      = toset(var.esxi_hosts)
  name          = each.value
  datacenter_id = data.vsphere_datacenter.dc.id
}

# --- Distributed Virtual Switch ---
resource "vsphere_distributed_virtual_switch" "dvs" {
  name          = var.dvs_name
  datacenter_id = data.vsphere_datacenter.dc.id

  uplinks         = ["Uplink1", "Uplink2"]
  active_uplinks  = ["Uplink1"]
  standby_uplinks = ["Uplink2"]

  dynamic "host" {
    for_each = data.vsphere_host.hosts
    content {
      host_system_id = host.value.id
      devices        = var.host_nic_devices
    }
  }
}

# --- Port Groups ---
resource "vsphere_distributed_port_group" "management" {
  name                            = var.management_pg_name
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.dvs.id

  vlan_id = var.management_vlan_id

  allow_promiscuous      = false
  allow_forged_transmits = false
  allow_mac_changes      = false
}

resource "vsphere_distributed_port_group" "workload" {
  name                            = var.workload_pg_name
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.dvs.id

  vlan_id = var.workload_vlan_id

  allow_promiscuous      = false
  allow_forged_transmits = false
  allow_mac_changes      = false
}

resource "vsphere_distributed_port_group" "storage" {
  name                            = var.storage_pg_name
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.dvs.id

  vlan_id = var.storage_vlan_id

  allow_promiscuous      = false
  allow_forged_transmits = false
  allow_mac_changes      = false
}

resource "vsphere_distributed_port_group" "vmotion" {
  name                            = var.vmotion_pg_name
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.dvs.id

  vlan_id = var.vmotion_vlan_id

  allow_promiscuous      = false
  allow_forged_transmits = false
  allow_mac_changes      = false
}
