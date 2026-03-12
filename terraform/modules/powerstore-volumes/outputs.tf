output "volume_ids" {
  description = "Map of volume name to volume ID"
  value       = { for k, v in powerstore_volume.datastore : k => v.id }
}

output "volume_wwns" {
  description = "Map of volume name to WWN (for VMFS datastore creation)"
  value       = { for k, v in powerstore_volume.datastore : k => v.wwn }
}

output "host_group_id" {
  description = "Host group ID for cluster-level volume mapping"
  value       = powerstore_host_group.cluster.id
}

output "volume_group_id" {
  description = "Volume group ID"
  value       = powerstore_volume_group.lab.id
}
