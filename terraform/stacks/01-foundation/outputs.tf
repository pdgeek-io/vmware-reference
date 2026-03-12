output "datacenter_id" {
  value = module.vsphere_datacenter.datacenter_id
}

output "cluster_id" {
  value = module.vsphere_datacenter.cluster_id
}

output "resource_pool_ids" {
  value = module.vsphere_datacenter.resource_pool_ids
}

output "datastore_ids" {
  value = module.vsphere_datacenter.datastore_ids
}

output "powerstore_volume_ids" {
  value = module.powerstore.volume_ids
}

output "powerstore_host_group_id" {
  value = module.powerstore.host_group_id
}
