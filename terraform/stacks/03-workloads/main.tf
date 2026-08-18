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

locals {
  vm_tag_specs = flatten([
    for vm_name, vm in var.vms : [
      for tag in vm.tags : {
        key      = "${tag.category}/${tag.name}"
        category = tag.category
        name     = tag.name
      }
    ]
  ])

  vm_tag_specs_by_key = {
    for tag in local.vm_tag_specs : tag.key => tag...
  }

  vm_tags_by_key = {
    for key, tags in local.vm_tag_specs_by_key : key => tags[0]
  }
}

data "vsphere_tag_category" "workload" {
  for_each = toset([for tag in local.vm_tags_by_key : tag.category])

  name = each.key
}

data "vsphere_tag" "workload" {
  for_each = local.vm_tags_by_key

  name        = each.value.name
  category_id = data.vsphere_tag_category.workload[each.value.category].id
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

  cpu_count              = each.value.cpu
  num_cores_per_socket   = each.value.num_cores_per_socket
  cpu_hot_add_enabled    = each.value.cpu_hot_add
  memory_mb              = each.value.memory_mb
  memory_hot_add_enabled = each.value.memory_hot_add
  memory_reservation     = each.value.memory_reservation
  latency_sensitivity    = each.value.latency_sensitivity
  os_disk_size_gb        = each.value.os_disk_gb
  disks                  = each.value.data_disks

  ip_address  = each.value.ip_address
  netmask     = coalesce(each.value.netmask, var.netmask)
  gateway     = var.gateway
  dns_servers = var.dns_servers
  domain      = var.domain
  userdata    = each.value.userdata
  tags = [
    for tag in each.value.tags : data.vsphere_tag.workload["${tag.category}/${tag.name}"].id
  ]
}
