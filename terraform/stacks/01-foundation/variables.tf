# ─── Provider Connection ─────────────────────────────────────────────
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

variable "powerstore_endpoint" {
  type = string
}

variable "powerstore_user" {
  type = string
}

variable "powerstore_password" {
  type      = string
  sensitive = true
}

variable "allow_unverified_ssl" {
  type    = bool
  default = true
}

# ─── Infrastructure ─────────────────────────────────────────────────
variable "environment" {
  type    = string
  default = "lab"
}

variable "datacenter_name" {
  type    = string
  default = "PDGeek-Lab-DC"
}

variable "cluster_name" {
  type    = string
  default = "PowerEdge-Cluster-01"
}

variable "esxi_hosts" {
  type = list(string)
}

variable "esxi_username" {
  type    = string
  default = "root"
}

variable "esxi_password" {
  type      = string
  sensitive = true
}

variable "esxi_thumbprints" {
  type = map(string)
}

variable "esxi_iscsi_iqns" {
  description = "Map of ESXi hostname to iSCSI IQN"
  type        = map(string)
}

variable "datastore_size_gb" {
  description = "Size of each VMFS datastore in GB"
  type        = number
  default     = 1000
}
