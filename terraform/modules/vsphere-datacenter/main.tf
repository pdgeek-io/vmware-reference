# =============================================================================
# VMware vSphere — Datacenter, Cluster, Resource Pools, and Folders
# Sets up the vSphere platform layer on PowerEdge
# =============================================================================

# --- Datacenter ---
resource "vsphere_datacenter" "dc" {
  name = var.datacenter_name
}

# --- Compute Cluster ---
resource "vsphere_compute_cluster" "cluster" {
  name          = var.cluster_name
  datacenter_id = vsphere_datacenter.dc.moid

  # DRS configuration
  drs_enabled          = true
  drs_automation_level = "fullyAutomated"

  # HA configuration
  ha_enabled                                    = var.ha_enabled
  ha_admission_control_policy                   = "resourcePercentage"
  ha_admission_control_host_failure_tolerance   = 1
  ha_admission_control_resource_percentage_cpu  = 25
  ha_admission_control_resource_percentage_memory = 25

  # vSAN (if applicable)
  vsan_enabled = false
}

# --- Add ESXi Hosts to Cluster ---
resource "vsphere_host" "esxi" {
  for_each = toset(var.esxi_hosts)

  hostname   = each.value
  username   = var.esxi_username
  password   = var.esxi_password
  cluster    = vsphere_compute_cluster.cluster.id
  thumbprint = var.esxi_thumbprints[each.value]
}

# --- VMFS Datastores (backed by PowerStore volumes) ---
resource "vsphere_vmfs_datastore" "powerstore" {
  for_each = var.datastore_disks

  name           = each.key
  host_system_id = vsphere_host.esxi[var.esxi_hosts[0]].id

  disks = [each.value]
}

# --- Resource Pools ---
resource "vsphere_resource_pool" "environments" {
  for_each = toset(var.resource_pool_names)

  name                    = each.value
  parent_resource_pool_id = vsphere_compute_cluster.cluster.resource_pool_id
}

# --- VM Folders ---
resource "vsphere_folder" "vm_folders" {
  for_each = toset(var.vm_folder_names)

  path          = each.value
  type          = "vm"
  datacenter_id = vsphere_datacenter.dc.moid
}

# --- Template Folder ---
resource "vsphere_folder" "templates" {
  path          = var.template_folder
  type          = "vm"
  datacenter_id = vsphere_datacenter.dc.moid
}
