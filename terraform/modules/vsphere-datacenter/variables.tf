variable "datacenter_name" {
  description = "Name of the vSphere datacenter"
  type        = string
}

variable "cluster_name" {
  description = "Name of the vSphere compute cluster"
  type        = string
}

variable "ha_enabled" {
  description = "Enable vSphere HA on the cluster"
  type        = bool
  default     = true
}

variable "esxi_hosts" {
  description = "List of ESXi host FQDNs to add to the cluster"
  type        = list(string)
}

variable "esxi_username" {
  description = "ESXi host username"
  type        = string
  default     = "root"
}

variable "esxi_password" {
  description = "ESXi host password"
  type        = string
  sensitive   = true
}

variable "esxi_thumbprints" {
  description = "Map of ESXi hostname to SSL thumbprint"
  type        = map(string)
}

variable "datastore_disks" {
  description = "Map of datastore name to PowerStore disk identifier (NAA ID)"
  type        = map(string)
  default     = {}
}

variable "resource_pool_names" {
  description = "List of resource pool names to create"
  type        = list(string)
  default     = ["Development", "Staging", "Production", "Templates"]
}

variable "vm_folder_names" {
  description = "List of VM folder paths to create"
  type        = list(string)
  default     = ["Reference-VMs/Web", "Reference-VMs/App", "Reference-VMs/Database", "Reference-VMs/Docker"]
}

variable "template_folder" {
  description = "Folder path for VM templates"
  type        = string
  default     = "Templates"
}
