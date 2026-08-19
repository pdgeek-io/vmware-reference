variable "vsphere_server" {
  type = string
}

variable "vsphere_user" {
  type = string
}

variable "vsphere_password" {
  type      = string
  sensitive = true
}

variable "datacenter_name" {
  type    = string
  default = "PDGeek-Lab-DC"
}

variable "cluster_name" {
  type    = string
  default = "PowerEdge-Cluster-01"
}

variable "datastore_name" {
  type    = string
  default = "Template-Datastore-01"
}

variable "template_folder" {
  type    = string
  default = "Templates"
}

variable "network_name" {
  type    = string
  default = "DPG-Workload"
}

variable "windows_iso_url" {
  description = "Local file URL or remote URL for manual Windows Server 2025 builds. Prefer windows_iso_path for pipeline builds."
  type        = string
  default     = ""
}

variable "windows_iso_path" {
  description = "Pipeline-safe vSphere datastore or content library path for the Windows Server 2025 ISO. Example: \"[datastore1] iso/windows-server-2025.iso\"."
  type        = string
  default     = ""
}

variable "windows_iso_checksum" {
  description = "Checksum for windows_iso_url. Set to sha256:<digest> after validating local media."
  type        = string
  default     = "sha256:cf96e924b4e7551169e09ef2a42d81340cdef11eaadf4bd4ac7bf1cdad5178a4"
}

variable "windows_image_name" {
  description = "Windows image name from install.wim to install unattended."
  type        = string
  default     = "Windows Server 2025 SERVERSTANDARDCORE"
}

variable "vmware_tools_iso_path" {
  description = "Optional preflighted ESXi datastore path for the VMware Tools Windows ISO, for example [] /usr/lib/vmware/isoimages/windows.iso. Leave empty and use vmware_tools_installer_url when productLocker is not reliable."
  type        = string
  default     = ""
}

variable "vmware_tools_installer_url" {
  description = "Optional HTTPS URL to a VMware Tools Windows installer reachable from the guest when vmware_tools_iso_path is not used."
  type        = string
  default     = ""
}

variable "vm_name" {
  type    = string
  default = "tpl-windows-server-2025"
}

variable "guest_os_type" {
  description = "Windows Server 2025 guest OS identifier on ESXi 8.0 U3+; use windows2022srv_64Guest as a lab fallback if unavailable."
  type        = string
  default     = "windows2022srvNext_64Guest"
}

variable "vm_hardware_version" {
  description = "Windows Server 2025 guest OS selection requires virtual hardware 20+ on current vSphere releases."
  type        = number
  default     = 20
}

variable "cpu_count" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 4096
}

variable "disk_size_mb" {
  type    = number
  default = 81920
}

variable "winrm_username" {
  type    = string
  default = "Administrator"
}

variable "winrm_password" {
  type      = string
  sensitive = true

  validation {
    condition     = length(regexall("[<>&]", var.winrm_password)) == 0
    error_message = "Winrm_password is injected into Autounattend.xml and must not contain XML-reserved characters: <, >, or &."
  }
}

variable "winrm_allowed_remote_addresses" {
  description = "Windows Firewall RemoteAddress value for WinRM HTTPS. Use a build subnet or host CIDR for validation; Any is only for isolated labs."
  type        = string
  default     = "Any"
}
