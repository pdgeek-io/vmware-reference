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
  default = "PowerStore-DS01"
}
variable "network_name" {
  type    = string
  default = "DPG-Workload"
}
variable "gateway" {
  type = string
}
variable "dns_servers" {
  type = list(string)
}
variable "domain" {
  type    = string
  default = "lab.example.com"
}

variable "vms" {
  description = "Map of VM definitions to deploy"
  type = map(object({
    template             = string
    resource_pool        = string
    folder               = string
    cpu                  = number
    num_cores_per_socket = optional(number, 1)
    cpu_hot_add          = optional(bool, false)
    memory_mb            = number
    memory_hot_add       = optional(bool, false)
    memory_reservation   = optional(number, 0)
    latency_sensitivity  = optional(string, "normal")
    os_disk_gb           = number
    ip_address           = string
    data_disks = list(object({
      label      = string
      size_gb    = number
      controller = optional(number, 0)
    }))
  }))
}
