# =============================================================================
# Three-Tier Web Application — Reference Deployment
# Nginx (Web) + Flask (App) + PostgreSQL (DB) on PowerEdge + PowerStore
# =============================================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = ">= 2.9.0"
    }
  }
}

provider "vsphere" {
  vsphere_server       = var.vsphere_server
  user                 = var.vsphere_user
  password             = var.vsphere_password
  allow_unverified_ssl = true
}

# --- Web Tier (Nginx) ---
module "web" {
  source = "../../terraform/modules/vsphere-vm"

  datacenter_name    = var.datacenter_name
  cluster_name       = var.cluster_name
  datastore_name     = var.datastore_name
  network_name       = var.network_name
  resource_pool_name = "Production"

  template_name   = "tpl-ubuntu-2404"
  vm_name         = "${var.app_prefix}-web"
  vm_folder       = "Reference-VMs/Web"
  cpu_count       = 2
  memory_mb       = 4096
  os_disk_size_gb = 40
  ip_address      = var.web_ip
  gateway         = var.gateway
  dns_servers     = var.dns_servers
}

# --- App Tier (Flask) ---
module "app" {
  source = "../../terraform/modules/vsphere-vm"

  datacenter_name    = var.datacenter_name
  cluster_name       = var.cluster_name
  datastore_name     = var.datastore_name
  network_name       = var.network_name
  resource_pool_name = "Production"

  template_name   = "tpl-ubuntu-2404"
  vm_name         = "${var.app_prefix}-app"
  vm_folder       = "Reference-VMs/App"
  cpu_count       = 4
  memory_mb       = 8192
  os_disk_size_gb = 60
  ip_address      = var.app_ip
  gateway         = var.gateway
  dns_servers     = var.dns_servers
}

# --- Database Tier (PostgreSQL on PowerStore) ---
module "db" {
  source = "../../terraform/modules/vsphere-vm"

  datacenter_name    = var.datacenter_name
  cluster_name       = var.cluster_name
  datastore_name     = var.datastore_name
  network_name       = var.network_name
  resource_pool_name = "Production"

  template_name   = "tpl-ubuntu-2404"
  vm_name         = "${var.app_prefix}-db"
  vm_folder       = "Reference-VMs/Database"
  cpu_count       = 8
  memory_mb       = 32768
  os_disk_size_gb = 60
  ip_address      = var.db_ip
  gateway         = var.gateway
  dns_servers     = var.dns_servers

  disks = [
    { label = "pgdata", size_gb = 200 }
  ]
}
