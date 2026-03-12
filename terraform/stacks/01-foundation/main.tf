# =============================================================================
# Foundation Stack — PowerStore Storage + vSphere Platform
# This stack provisions the base infrastructure:
#   1. PowerStore volumes for VMFS datastores
#   2. vSphere datacenter, cluster, resource pools, and folders
# =============================================================================

# --- Step 1: Provision PowerStore Volumes ---
module "powerstore" {
  source = "../../modules/powerstore-volumes"

  environment      = var.environment
  volume_group_name = "${var.environment}-vmfs-vg"
  cluster_name     = var.cluster_name

  volumes = {
    vmfs-01 = {
      name        = "${var.environment}-vmfs-ds01"
      size_gb     = var.datastore_size_gb
      description = "Primary VMFS datastore for VM workloads"
    }
    vmfs-02 = {
      name        = "${var.environment}-vmfs-ds02"
      size_gb     = var.datastore_size_gb
      description = "Secondary VMFS datastore for VM workloads"
    }
    vmfs-templates = {
      name        = "${var.environment}-vmfs-templates"
      size_gb     = 500
      description = "VMFS datastore for Packer templates"
    }
  }

  esxi_hosts = [
    for host in var.esxi_hosts : {
      name       = host
      iscsi_iqns = [var.esxi_iscsi_iqns[host]]
    }
  ]

  host_group_name        = "${var.cluster_name}-hg"
  create_snapshot_rule   = true
  snapshot_retention_days = 7
}

# --- Step 2: Configure vSphere Platform ---
module "vsphere_datacenter" {
  source = "../../modules/vsphere-datacenter"

  datacenter_name = var.datacenter_name
  cluster_name    = var.cluster_name
  ha_enabled      = true

  esxi_hosts       = var.esxi_hosts
  esxi_username    = var.esxi_username
  esxi_password    = var.esxi_password
  esxi_thumbprints = var.esxi_thumbprints

  # Map PowerStore volumes as VMFS datastores
  datastore_disks = {
    "PowerStore-DS01"       = "naa.${module.powerstore.volume_wwns["vmfs-01"]}"
    "PowerStore-DS02"       = "naa.${module.powerstore.volume_wwns["vmfs-02"]}"
    "PowerStore-Templates"  = "naa.${module.powerstore.volume_wwns["vmfs-templates"]}"
  }

  resource_pool_names = ["Development", "Staging", "Production", "Templates"]

  vm_folder_names = [
    "Reference-VMs",
    "Reference-VMs/Web",
    "Reference-VMs/App",
    "Reference-VMs/Database",
    "Reference-VMs/Docker",
  ]

  template_folder = "Templates"
}
