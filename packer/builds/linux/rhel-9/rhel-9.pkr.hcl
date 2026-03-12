# =============================================================================
# Packer — RHEL 9 / Rocky 9 VM Template for vSphere
# =============================================================================

packer {
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.3.0"
    }
  }
}

source "vsphere-iso" "rhel-9" {
  vcenter_server      = var.vsphere_server
  username            = var.vsphere_user
  password            = var.vsphere_password
  insecure_connection = true

  datacenter = var.datacenter_name
  cluster    = var.cluster_name
  datastore  = var.datastore_name
  folder     = var.template_folder

  vm_name              = "tpl-rhel-9"
  guest_os_type        = "rhel9_64Guest"
  firmware             = "efi"
  CPUs                 = 2
  RAM                  = 2048
  disk_controller_type = ["pvscsi"]
  notes                = "RHEL 9 template. Built by Packer on {{timestamp}}."

  storage {
    disk_size             = 40960
    disk_thin_provisioned = true
  }

  network_adapters {
    network      = var.network_name
    network_card = "vmxnet3"
  }

  iso_paths = [var.iso_path]

  http_content = {
    "/ks.cfg" = templatefile("${path.root}/http/ks.cfg", {
      username = var.build_username
      password = var.build_password_hash
      ssh_key  = var.ssh_public_key
    })
  }

  boot_wait = "5s"
  boot_command = [
    "<up><wait>",
    "e<wait>",
    "<down><down><end>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
    "<leftCtrlOn>x<leftCtrlOff>"
  ]

  ssh_username           = var.build_username
  ssh_password           = var.build_password
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 100

  convert_to_template = true
  remove_cdrom        = true
}

build {
  sources = ["source.vsphere-iso.rhel-9"]

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts         = ["${path.root}/scripts/cleanup.sh"]
  }
}
