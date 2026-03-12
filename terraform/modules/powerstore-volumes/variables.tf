variable "environment" {
  description = "Environment name (e.g., lab, dev, prod)"
  type        = string
  default     = "lab"
}

variable "volume_group_name" {
  description = "Name for the PowerStore volume group"
  type        = string
  default     = "ref-arch-vg"
}

variable "volumes" {
  description = "Map of volumes to create"
  type = map(object({
    name                  = string
    size_gb               = number
    description           = string
    performance_policy_id = optional(string, null)
  }))
}

variable "appliance_id" {
  description = "PowerStore appliance ID (A1 for single appliance)"
  type        = string
  default     = "A1"
}

variable "esxi_hosts" {
  description = "List of ESXi hosts to register"
  type = list(object({
    name       = string
    iscsi_iqns = list(string)
  }))
}

variable "host_group_name" {
  description = "Name for the host group"
  type        = string
  default     = "esxi-cluster-hg"
}

variable "cluster_name" {
  description = "vSphere cluster name (for description)"
  type        = string
}

variable "protection_policy_id" {
  description = "Protection policy ID to assign to the volume group"
  type        = string
  default     = null
}

variable "create_snapshot_rule" {
  description = "Whether to create a daily snapshot rule"
  type        = bool
  default     = true
}

variable "snapshot_retention_days" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 7
}
