variable "datacenter_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "datastore_name" {
  type = string
}

variable "network_name" {
  type = string
}

variable "template_name" {
  description = "Name of the Packer-built VM template"
  type        = string
}

variable "resource_pool_name" {
  type = string
}

variable "vm_name" {
  type = string
}

variable "vm_folder" {
  description = "VM folder path"
  type        = string
  default     = ""
}

variable "cpu_count" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 4096
}

variable "os_disk_size_gb" {
  type    = number
  default = 40
}

variable "thin_provisioned" {
  type    = bool
  default = true
}

variable "disks" {
  description = "Additional data disks"
  type = list(object({
    label   = string
    size_gb = number
  }))
  default = []
}

variable "domain" {
  type    = string
  default = "lab.example.com"
}

variable "ip_address" {
  type = string
}

variable "netmask" {
  type    = number
  default = 24
}

variable "gateway" {
  type = string
}

variable "dns_servers" {
  type    = list(string)
  default = ["10.0.0.10"]
}

variable "userdata" {
  description = "Cloud-init userdata (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "vSphere tag IDs to apply"
  type        = list(string)
  default     = []
}
