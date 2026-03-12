# =============================================================================
# VMware vSphere — VM Deployment from Template
# Clones a Packer-built template and customizes with cloud-init or sysprep
# =============================================================================

data "vsphere_datacenter" "dc" {
  name = var.datacenter_name
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "ds" {
  name          = var.datastore_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = var.resource_pool_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# --- Virtual Machine ---
resource "vsphere_virtual_machine" "vm" {
  name             = var.vm_name
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.ds.id
  folder           = var.vm_folder

  num_cpus = var.cpu_count
  memory   = var.memory_mb
  guest_id = data.vsphere_virtual_machine.template.guest_id

  firmware                = data.vsphere_virtual_machine.template.firmware
  scsi_type               = data.vsphere_virtual_machine.template.scsi_type
  scsi_controller_count   = max(1, length(var.disks))

  # Network
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = "vmxnet3"
  }

  # OS Disk (cloned from template)
  disk {
    label            = "disk0"
    size             = var.os_disk_size_gb
    thin_provisioned = var.thin_provisioned
  }

  # Additional Data Disks
  dynamic "disk" {
    for_each = var.disks
    content {
      label            = disk.value.label
      size             = disk.value.size_gb
      thin_provisioned = var.thin_provisioned
      unit_number      = disk.key + 1
    }
  }

  # Clone from template
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = var.vm_name
        domain    = var.domain
      }

      network_interface {
        ipv4_address = var.ip_address
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
    }
  }

  # Cloud-init via extra_config (if userdata provided)
  dynamic "extra_config" {
    for_each = var.userdata != "" ? { "guestinfo.userdata" = base64encode(var.userdata), "guestinfo.userdata.encoding" = "base64" } : {}
    content {
      key   = extra_config.key
      value = extra_config.value
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      annotation,
      clone[0].template_uuid,
    ]
  }
}
