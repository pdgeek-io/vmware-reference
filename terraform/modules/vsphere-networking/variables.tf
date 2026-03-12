variable "datacenter_name" {
  type = string
}

variable "esxi_hosts" {
  type = list(string)
}

variable "dvs_name" {
  type    = string
  default = "DSwitch-PowerEdge"
}

variable "host_nic_devices" {
  description = "Physical NICs to attach to the DVS on each host"
  type        = list(string)
  default     = ["vmnic2", "vmnic3"]
}

variable "management_pg_name" {
  type    = string
  default = "DPG-Management"
}

variable "workload_pg_name" {
  type    = string
  default = "DPG-Workload"
}

variable "storage_pg_name" {
  type    = string
  default = "DPG-Storage"
}

variable "vmotion_pg_name" {
  type    = string
  default = "DPG-vMotion"
}

variable "management_vlan_id" {
  type    = number
  default = 100
}

variable "workload_vlan_id" {
  type    = number
  default = 200
}

variable "storage_vlan_id" {
  type    = number
  default = 300
}

variable "vmotion_vlan_id" {
  type    = number
  default = 400
}
