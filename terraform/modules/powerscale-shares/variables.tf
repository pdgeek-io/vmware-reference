# =============================================================================
# pdgeek.io — PowerScale Research Shares — Variables
# =============================================================================

variable "shares" {
  description = "Map of research shares to create"
  type = map(object({
    description      = string
    department       = string
    pi_name          = string
    pi_username      = string
    pi_email         = string
    grant_id         = string
    grant_expiration = string  # ISO 8601 date (e.g., "2027-08-31")
    quota_gb         = number
    allowed_clients  = list(string)
    root_clients     = optional(list(string), [])
    security_flavors = optional(list(string), ["unix"])
    enable_snapshots = optional(bool, true)
  }))
}

variable "access_zone" {
  description = "PowerScale access zone for research shares"
  type        = string
  default     = "research"
}

variable "powerscale_endpoint" {
  description = "PowerScale cluster management endpoint"
  type        = string
}

variable "snapshot_retention_days" {
  description = "Number of days to retain daily snapshots"
  type        = number
  default     = 30
}
