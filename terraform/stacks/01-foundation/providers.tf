# =============================================================================
# pdgeek.io — Provider Configuration — PowerStore + VMware vSphere
# Both providers work together: PowerStore provisions storage,
# vSphere consumes it as VMFS datastores on PowerEdge hosts.
# =============================================================================

provider "vsphere" {
  vsphere_server       = var.vsphere_server
  user                 = var.vsphere_user
  password             = var.vsphere_password
  allow_unverified_ssl = var.allow_unverified_ssl
}

provider "powerstore" {
  endpoint = var.powerstore_endpoint
  username = var.powerstore_user
  password = var.powerstore_password
  insecure = var.allow_unverified_ssl
  timeout  = 120
}
