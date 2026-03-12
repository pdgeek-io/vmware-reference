variable "vsphere_server" { type = string }
variable "vsphere_user" { type = string }
variable "vsphere_password" { type = string; sensitive = true }

variable "datacenter_name" { type = string; default = "PDGeek-Lab-DC" }
variable "cluster_name" { type = string; default = "PowerEdge-Cluster-01" }
variable "datastore_name" { type = string; default = "PowerStore-DS01" }
variable "network_name" { type = string; default = "DPG-Workload" }

variable "app_prefix" {
  description = "Naming prefix for the three-tier app VMs"
  type        = string
  default     = "refapp"
}

variable "web_ip" { type = string; default = "10.0.200.20" }
variable "app_ip" { type = string; default = "10.0.200.21" }
variable "db_ip" { type = string; default = "10.0.200.22" }
variable "gateway" { type = string; default = "10.0.200.1" }
variable "dns_servers" { type = list(string); default = ["10.0.0.10"] }
