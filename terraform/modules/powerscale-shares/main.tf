# =============================================================================
# pdgeek.io — PowerScale NFS Research Shares
# Creates NFS exports on PowerScale for researcher self-service,
# bound to Entra ID/AD for authentication via RFC2307.
# =============================================================================

resource "powerscale_filesystem" "research_share" {
  for_each = var.shares

  directory_path       = "/ifs/research/${each.value.department}/${each.key}"
  owner                = { id = "user:${each.value.pi_username}", name = each.value.pi_username, type = "user" }
  group                = { id = "group:${each.value.department}", name = each.value.department, type = "group" }
  access_control       = "0770"
  recursive            = true
  overwrite            = false
}

resource "powerscale_nfs_export" "research_export" {
  for_each = var.shares

  paths       = ["/ifs/research/${each.value.department}/${each.key}"]
  description = "Research share: ${each.value.description} (Grant: ${each.value.grant_id}, PI: ${each.value.pi_name})"
  zone        = var.access_zone

  # Client access — restrict to lab subnet
  clients     = each.value.allowed_clients
  root_clients = each.value.root_clients

  # Security — require AUTH_SYS or krb5 depending on environment
  security_flavors = each.value.security_flavors

  # Map root to nobody for security
  map_root = {
    enabled = true
    user    = { id = "user:nobody" }
  }

  # Read-write access
  read_write_clients = each.value.allowed_clients

  depends_on = [powerscale_filesystem.research_share]
}

resource "powerscale_quota" "research_quota" {
  for_each = var.shares

  path              = "/ifs/research/${each.value.department}/${each.key}"
  type              = "directory"
  include_snapshots = false
  zone              = var.access_zone

  # Hard limit from catalog
  hard_limit    = each.value.quota_gb * 1073741824
  # Advisory at 80%
  advisory_limit = floor(each.value.quota_gb * 1073741824 * 0.80)
  # Soft limit at 90% with 7 day grace
  soft_limit       = floor(each.value.quota_gb * 1073741824 * 0.90)
  soft_grace_period = 604800

  depends_on = [powerscale_filesystem.research_share]
}

resource "powerscale_snapshot_schedule" "research_snapshots" {
  for_each = { for k, v in var.shares : k => v if v.enable_snapshots }

  name     = "snap-${each.key}"
  path     = "/ifs/research/${each.value.department}/${each.key}"
  pattern  = "ResearchSnap-%Y-%m-%d_%H:%M"
  schedule = "Every day at 2:00 AM"
  duration = var.snapshot_retention_days * 86400
  alias    = "research-${each.key}-latest"

  depends_on = [powerscale_filesystem.research_share]
}
