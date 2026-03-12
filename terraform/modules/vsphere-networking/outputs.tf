output "dvs_id" {
  value = vsphere_distributed_virtual_switch.dvs.id
}

output "management_pg_id" {
  value = vsphere_distributed_port_group.management.id
}

output "workload_pg_id" {
  value = vsphere_distributed_port_group.workload.id
}

output "storage_pg_id" {
  value = vsphere_distributed_port_group.storage.id
}

output "workload_network_name" {
  value = vsphere_distributed_port_group.workload.name
}
