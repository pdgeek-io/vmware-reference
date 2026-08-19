# =============================================================================
# Packer - Windows Server 2025 VM Template for vSphere
# In-progress feature branch scaffold; not part of the supported mainline path.
# =============================================================================

packer {
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.3.0"
    }
  }
}

source "vsphere-iso" "windows-server-2025" {
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
  vm_name       = var.vm_name
  guest_os_type = var.guest_os_type
  vm_version    = var.vm_hardware_version
  firmware      = "efi-secure"
  vTPM          = true

  CPUs                 = var.cpu_count
  RAM                  = var.memory_mb
  RAM_reserve_all      = false
  disk_controller_type = ["pvscsi"]
  notes                = "Windows Server 2025 template scaffold. Built by Packer on {{timestamp}}."
  tools_upgrade_policy = true
  remote_cache_cleanup = true

  storage {
    disk_size             = var.disk_size_mb
    disk_thin_provisioned = true
  }

  network_adapters {
    network      = var.network_name
    network_card = "vmxnet3"
  }

  # ISO: manual builds may use windows_iso_url. Pipeline builds should use
  # windows_iso_path with a datastore/content-library ISO path so the runner
  # does not depend on workstation-local media. VMware Tools is the only
  # optional second ISO.
  iso_url      = var.windows_iso_url
  iso_checksum = var.windows_iso_url != "" ? var.windows_iso_checksum : "none"
  iso_paths = var.windows_iso_path != "" && var.vmware_tools_iso_path != "" ? [
    var.windows_iso_path,
    var.vmware_tools_iso_path,
    ] : var.windows_iso_path != "" ? [
    var.windows_iso_path,
    ] : var.vmware_tools_iso_path != "" ? [
    var.vmware_tools_iso_path,
  ] : []

  floppy_label = "PACKERDATA"
  floppy_content = {
    "Autounattend.xml" = templatefile("${path.root}/answer/Autounattend.xml.pkrtpl", {
      windows_image_name             = var.windows_image_name
      winrm_username                 = var.winrm_username
      winrm_password                 = var.winrm_password
      winrm_allowed_remote_addresses = var.winrm_allowed_remote_addresses
    })
    "enable-winrm.ps1" = templatefile("${path.root}/scripts/enable-winrm.ps1", {
      winrm_allowed_remote_addresses = var.winrm_allowed_remote_addresses
    })
  }

  boot_wait = "5s"
  boot_command = [
    "<spacebar><wait>",
  ]

  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_use_ssl  = true
  winrm_use_ntlm = true
  winrm_insecure = true
  winrm_timeout  = "90m"

  shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer template shutdown\""
  shutdown_timeout = "30m"

  convert_to_template = true
  remove_cdrom        = true
}

build {
  sources = ["source.vsphere-iso.windows-server-2025"]

  provisioner "powershell" {
    environment_vars = [
      "VMWARE_TOOLS_INSTALLER_URL=${var.vmware_tools_installer_url}",
    ]
    scripts = [
      "${path.root}/scripts/install-vmware-tools.ps1",
    ]
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/cleanup-template.ps1",
    ]
  }

  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/sysprep-template.ps1",
    ]
  }
}
