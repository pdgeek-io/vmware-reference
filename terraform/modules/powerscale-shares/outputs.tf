# =============================================================================
# pdgeek.io — PowerScale Research Shares — Outputs
# =============================================================================

output "share_paths" {
  description = "Map of share names to their NFS export paths"
  value       = { for k, v in var.shares : k => "/ifs/research/${v.department}/${k}" }
}

output "mount_commands" {
  description = "NFS mount commands for each share"
  value = { for k, v in var.shares : k =>
    "mount -t nfs ${var.powerscale_endpoint}:/ifs/research/${v.department}/${k} /mnt/research/${k}"
  }
}

output "share_metadata" {
  description = "Metadata for each research share (for chargeback/compliance)"
  value = { for k, v in var.shares : k => {
    grant_id         = v.grant_id
    department       = v.department
    pi_name          = v.pi_name
    pi_email         = v.pi_email
    grant_expiration = v.grant_expiration
    quota_gb         = v.quota_gb
  }}
}
