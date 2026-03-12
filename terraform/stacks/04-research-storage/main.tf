# =============================================================================
# pdgeek.io — Research Storage Stack
# Self-service NFS shares on PowerScale for research grants
# Authenticated via Entra ID/AD with RFC2307 UID mapping
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    powerscale = {
      source  = "dell/powerscale"
      version = ">= 1.4.0"
    }
  }
}

provider "powerscale" {
  endpoint = var.powerscale_endpoint
  username = var.powerscale_user
  password = var.powerscale_password
  insecure = var.allow_unverified_ssl
}

module "research_shares" {
  source = "../../modules/powerscale-shares"

  shares              = var.research_shares
  access_zone         = var.access_zone
  powerscale_endpoint = var.powerscale_endpoint
}

output "share_paths" {
  value = module.research_shares.share_paths
}

output "mount_commands" {
  value = module.research_shares.mount_commands
}

output "share_metadata" {
  value = module.research_shares.share_metadata
}
