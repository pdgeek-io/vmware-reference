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
  vm_inventory = {
    for name, vm in var.vms : name => {
      ip_address = vm.ip_address
      fqdn       = try(vm.dns_ipam.fqdn, "${name}.${var.domain}")
      folder     = vm.folder
      template   = vm.template
      tags       = vm.tags
      chargeback = vm.chargeback
      validation = try(vm.validation, {})
    }
  }

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

resource "terraform_data" "ansible_after_apply" {
  count = var.run_ansible_after_apply ? 1 : 0

  input = local.vm_inventory
  triggers_replace = [
    sha256(jsonencode(local.vm_inventory)),
    var.ansible_handoff_version,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
set -euo pipefail
mkdir -p "$(dirname "${abspath("${path.root}/${var.ansible_inventory_path}")}")"
cat > "${path.root}/.terraform/higher-ed-vm-inventory.json" <<'JSON'
${jsonencode(local.vm_inventory)}
JSON
python3 "${abspath("${path.root}/${var.ansible_inventory_renderer}")}" \
  --group "${var.ansible_inventory_group}" \
  < "${path.root}/.terraform/higher-ed-vm-inventory.json" \
  > "${abspath("${path.root}/${var.ansible_inventory_path}")}"
ANSIBLE_CONFIG="${abspath("${path.root}/${var.ansible_config_path}")}" \
  ansible-playbook \
  -i "${abspath("${path.root}/${var.ansible_inventory_path}")}" \
  "${abspath("${path.root}/${var.ansible_playbook_path}")}"
EOT
  }

  depends_on = [module.workload_vms]
}
