variable "vsphere_server" { type = string }
variable "vsphere_user" { type = string }
variable "vsphere_password" { type = string; sensitive = true }

variable "datacenter_name" { type = string; default = "PDGeek-Lab-DC" }
variable "cluster_name" { type = string; default = "PowerEdge-Cluster-01" }
variable "datastore_name" { type = string; default = "PowerStore-Templates" }
variable "template_folder" { type = string; default = "Templates" }
variable "network_name" { type = string; default = "DPG-Workload" }

variable "iso_path" {
  type    = string
  default = "[PowerStore-Templates] ISO/rhel-9.4-x86_64-dvd.iso"
}

variable "build_username" { type = string; default = "packer" }
variable "build_password" { type = string; sensitive = true; default = "packer" }
variable "build_password_hash" { type = string; sensitive = true }
variable "ssh_public_key" { type = string; default = "" }
