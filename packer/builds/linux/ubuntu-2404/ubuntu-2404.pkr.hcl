# =============================================================================
# Packer — Ubuntu 24.04 LTS VM Template for vSphere
# Builds a hardened, VMware-Tools-enabled template on PowerEdge + PowerStore
# =============================================================================

packer {
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.3.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}

# --- vSphere Connection ---
source "vsphere-iso" "ubuntu-2404" {
  # vCenter connection
  vcenter_server      = var.vsphere_server
  username            = var.vsphere_user
  password            = var.vsphere_password
  insecure_connection = true

  # Target location
  datacenter = var.datacenter_name
  cluster    = var.cluster_name
  datastore  = var.datastore_name
  folder     = var.template_folder

  # VM settings
  vm_name              = "tpl-ubuntu-2404"
  guest_os_type        = "ubuntu64Guest"
  firmware             = "efi"
  CPUs                 = 2
  RAM                  = 2048
  RAM_reserve_all      = false
  disk_controller_type = ["pvscsi"]
  notes                = "Ubuntu 24.04 LTS template. Built by Packer on {{timestamp}}."

  storage {
    disk_size             = 40960
    disk_thin_provisioned = true
  }

  network_adapters {
    network      = var.network_name
    network_card = "vmxnet3"
  }

  # ISO
  iso_paths = [var.iso_path]

  # Cloud-init autoinstall via HTTP
  http_content = {
    "/user-data" = templatefile("${path.root}/http/user-data", {
      hostname = "tpl-ubuntu-2404"
      username = var.build_username
      password = var.build_password_hash
      ssh_key  = var.ssh_public_key
    })
    "/meta-data" = ""
  }

  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<f10>"
  ]

  # SSH communicator
  ssh_username         = var.build_username
  ssh_password         = var.build_password
  ssh_timeout          = "30m"
  ssh_handshake_attempts = 100

  # Convert to template
  convert_to_template = true

  # Remove CD-ROM after build
  remove_cdrom = true
}

build {
  sources = ["source.vsphere-iso.ubuntu-2404"]

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = ["cloud-init status --wait"]
  }

  # Base configuration via Ansible
  provisioner "ansible" {
    playbook_file = "${path.root}/../../common/ansible-packer.yml"
    user          = var.build_username
    extra_arguments = [
      "--extra-vars", "ansible_become=true"
    ]
  }

  # Cleanup
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts = [
      "${path.root}/scripts/cleanup.sh"
    ]
  }
}
