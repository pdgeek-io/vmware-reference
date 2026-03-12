# =============================================================================
# Workload Stack — Deploy VMs from Packer Templates
# Uses the vsphere-vm module to deploy catalog-driven workloads
# =============================================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = ">= 2.9.0"
    }
  }
}

provider "vsphere" {
  vsphere_server       = var.vsphere_server
  user                 = var.vsphere_user
  password             = var.vsphere_password
  allow_unverified_ssl = true
}

# --- Deploy VMs from catalog definitions ---
module "workload_vms" {
  source   = "../../modules/vsphere-vm"
  for_each = var.vms

  datacenter_name    = var.datacenter_name
  cluster_name       = var.cluster_name
  datastore_name     = var.datastore_name
  network_name       = var.network_name
  resource_pool_name = each.value.resource_pool

  template_name = each.value.template
  vm_name       = each.key
  vm_folder     = each.value.folder

  cpu_count      = each.value.cpu
  memory_mb      = each.value.memory_mb
  os_disk_size_gb = each.value.os_disk_gb
  disks          = each.value.data_disks

  ip_address  = each.value.ip_address
  gateway     = var.gateway
  dns_servers = var.dns_servers
  domain      = var.domain
}
