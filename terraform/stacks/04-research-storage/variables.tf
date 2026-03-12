# =============================================================================
# pdgeek.io — Research Storage Stack — Variables
# =============================================================================

variable "powerscale_endpoint" {
  description = "PowerScale cluster management IP or FQDN"
  type        = string
}

variable "powerscale_user" {
  description = "PowerScale admin username"
  type        = string
}

variable "powerscale_password" {
  description = "PowerScale admin password"
  type        = string
  sensitive   = true
}

variable "allow_unverified_ssl" {
  description = "Allow self-signed certificates"
  type        = bool
  default     = true
}

variable "access_zone" {
  description = "PowerScale access zone for research shares"
  type        = string
  default     = "research"
}

variable "research_shares" {
  description = "Map of research shares to provision"
  type = map(object({
    description      = string
    department       = string
    pi_name          = string
    pi_username      = string
    pi_email         = string
    grant_id         = string
    grant_expiration = string
    quota_gb         = number
    allowed_clients  = list(string)
    root_clients     = optional(list(string), [])
    security_flavors = optional(list(string), ["unix"])
    enable_snapshots = optional(bool, true)
  }))
  default = {}
}
