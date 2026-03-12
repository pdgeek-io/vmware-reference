output "datacenter_id" {
  description = "Datacenter managed object ID"
  value       = vsphere_datacenter.dc.moid
}

output "cluster_id" {
  description = "Compute cluster managed object ID"
  value       = vsphere_compute_cluster.cluster.id
}

output "resource_pool_ids" {
  description = "Map of resource pool name to ID"
  value       = { for k, v in vsphere_resource_pool.environments : k => v.id }
}

output "datastore_ids" {
  description = "Map of datastore name to ID"
  value       = { for k, v in vsphere_vmfs_datastore.powerstore : k => v.id }
}

output "folder_paths" {
  description = "Map of folder name to full path"
  value       = { for k, v in vsphere_folder.vm_folders : k => v.path }
}

output "template_folder_path" {
  description = "Template folder path"
  value       = vsphere_folder.templates.path
}
