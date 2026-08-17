# =============================================================================
# pdgeek.io — PowerStore Volume Provisioning & Host Mapping
# Creates storage volumes and maps them to ESXi hosts for VMFS datastores
# =============================================================================

# --- Volume Group (logical grouping for the reference lab) ---
resource "powerstore_volumegroup" "lab" {
  name        = var.volume_group_name
  description = "Reference architecture volume group for ${var.environment}"

  protection_policy_id = var.protection_policy_id
}

# --- Storage Volumes ---
resource "powerstore_volume" "datastore" {
  for_each = var.volumes

  name                  = each.value.name
  size                  = each.value.size_gb * 1073741824 # Convert GB to bytes
  description           = each.value.description
  volume_group_id       = powerstore_volumegroup.lab.id
  host_group_id         = powerstore_hostgroup.cluster.id
  appliance_id          = var.appliance_id
  performance_policy_id = each.value.performance_policy_id
}

# --- Host Registration (ESXi hosts) ---
resource "powerstore_host" "esxi" {
  for_each = { for idx, host in var.esxi_hosts : host.name => host }

  name        = each.value.name
  description = "ESXi host - ${each.value.name}"
  os_type     = "ESXi"

  initiators = [
    for iqn in each.value.iscsi_iqns : {
      port_name = iqn
      port_type = "iSCSI"
    }
  ]
}

# --- Host Group (cluster-level mapping) ---
resource "powerstore_hostgroup" "cluster" {
  name        = var.host_group_name
  description = "ESXi cluster host group for ${var.cluster_name}"

  host_ids = [for h in powerstore_host.esxi : h.id]
}

# --- Snapshot Rules (automated protection) ---
resource "powerstore_snapshotrule" "daily" {
  count = var.create_snapshot_rule ? 1 : 0

  name     = "${var.environment}-daily-snap"
  interval = "One_Day"

  desired_retention = var.snapshot_retention_days * 86400 # Convert days to seconds
}
