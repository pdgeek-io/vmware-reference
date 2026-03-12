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
  default = "[PowerStore-Templates] ISO/SERVER_EVAL_x64FRE_en-us.iso"
}

variable "vmtools_iso_path" {
  type    = string
  default = "[] /vmimages/tools-isoimages/windows.iso"
}

variable "build_password" {
  type      = string
  sensitive = true
  default   = "packer"
}
