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

variable "num_cores_per_socket" {
  description = "Cores per socket. Set equal to cpu_count to keep all vCPUs in one NUMA node (recommended for DB)."
  type        = number
  default     = 1
}

variable "cpu_hot_add_enabled" {
  description = "Allow adding vCPUs without downtime"
  type        = bool
  default     = false
}

variable "memory_mb" {
  type    = number
  default = 4096
}

variable "memory_hot_add_enabled" {
  description = "Allow adding memory without downtime"
  type        = bool
  default     = false
}

variable "memory_reservation" {
  description = "Memory reservation in MB. Set equal to memory_mb for DB VMs to prevent balloon reclaim."
  type        = number
  default     = 0
}

variable "latency_sensitivity" {
  description = "Latency sensitivity: normal, low, medium, or high. Use high for latency-sensitive DB workloads."
  type        = string
  default     = "normal"
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
  description = "Additional data disks. Set controller (0-3) to spread disks across pvscsi controllers for max I/O."
  type = list(object({
    label      = string
    size_gb    = number
    controller = optional(number, 0)
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
