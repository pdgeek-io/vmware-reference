# =============================================================================
# Packer — Windows Server 2025 VM Template for vSphere
# =============================================================================

packer {
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.3.0"
    }
  }
}

source "vsphere-iso" "windows-2025" {
  vcenter_server      = var.vsphere_server
  username            = var.vsphere_user
  password            = var.vsphere_password
  insecure_connection = true

  datacenter = var.datacenter_name
  cluster    = var.cluster_name
  datastore  = var.datastore_name
  folder     = var.template_folder

  vm_name              = "tpl-windows-2025"
  guest_os_type        = "windows2019srvNext_64Guest"
  firmware             = "efi"
  CPUs                 = 4
  RAM                  = 4096
  disk_controller_type = ["pvscsi"]
  notes                = "Windows Server 2025 template. Built by Packer on {{timestamp}}."

  storage {
    disk_size             = 102400
    disk_thin_provisioned = true
  }

  network_adapters {
    network      = var.network_name
    network_card = "vmxnet3"
  }

  iso_paths = [
    var.iso_path,
    var.vmtools_iso_path,
  ]

  floppy_files = [
    "${path.root}/scripts/Autounattend.xml",
    "${path.root}/../windows-server-2022/scripts/configure-winrm.ps1",
    "${path.root}/../windows-server-2022/scripts/install-vmtools.ps1",
  ]

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = var.build_password
  winrm_timeout  = "60m"

  convert_to_template = true
  remove_cdrom        = true
}

build {
  sources = ["source.vsphere-iso.windows-2025"]

  provisioner "powershell" {
    inline = [
      "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force",
      "Install-WindowsFeature -Name NET-Framework-45-Core",
    ]
  }

  provisioner "powershell" {
    inline = [
      "Remove-Item -Path $env:TEMP\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "Clear-EventLog -LogName Application, System, Security -ErrorAction SilentlyContinue",
      "Stop-Service -Name wuauserv -Force",
      "Remove-Item -Path C:\\Windows\\SoftwareDistribution\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "& C:\\Windows\\System32\\Sysprep\\sysprep.exe /generalize /oobe /shutdown /quiet",
    ]
  }
}
