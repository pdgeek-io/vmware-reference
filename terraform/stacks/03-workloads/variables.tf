variable "vsphere_server" {
  type = string
}
variable "vsphere_user" {
  type = string
}
variable "vsphere_password" {
  type      = string
  sensitive = true
}

variable "datacenter_name" {
  type    = string
  default = "PDGeek-Lab-DC"
}
variable "cluster_name" {
  type    = string
  default = "PowerEdge-Cluster-01"
}
variable "datastore_name" {
  type    = string
  default = "PowerStore-DS01"
}
variable "network_name" {
  type    = string
  default = "DPG-Workload"
}
variable "gateway" {
  type = string
}
variable "dns_servers" {
  type = list(string)
}
variable "domain" {
  type    = string
  default = "lab.example.com"
}
variable "netmask" {
  type    = number
  default = 24
}

variable "vms" {
  description = "Map of VM definitions to deploy"
  type = map(object({
    template             = string
    resource_pool        = string
    folder               = string
    cpu                  = number
    num_cores_per_socket = optional(number, 1)
    cpu_hot_add          = optional(bool, false)
    memory_mb            = number
    memory_hot_add       = optional(bool, false)
    memory_reservation   = optional(number, 0)
    latency_sensitivity  = optional(string, "normal")
    os_disk_gb           = number
    ip_address           = string
    netmask              = optional(number)
    userdata             = optional(string, "")
    tags = optional(list(object({
      category = string
      name     = string
    })), [])
    chargeback = optional(object({
      department          = string
      cost_center         = string
      project             = string
      environment         = string
      billing_model       = optional(string, "shared_services")
      service_tier        = optional(string, "standard")
      backup_policy       = optional(string, "daily_30_day")
      application         = optional(string)
      app_owner           = optional(string)
      technical_owner     = optional(string)
      owner               = optional(string)
      monthly_budget_usd  = optional(number)
      grant_id            = optional(string)
      data_classification = optional(string, "internal")
      lifecycle           = optional(string, "annual_review")
    }))
    dns_ipam = optional(object({
      provider    = optional(string, "placeholder")
      record_type = optional(string, "A")
      fqdn        = string
      ttl         = optional(number, 3600)
      ptr         = optional(bool, true)
    }))
    app_hooks = optional(object({
      ansible_playbooks = optional(list(string), [])
      webhook_url_var   = optional(string)
      post_provision    = optional(list(string), [])
    }), {})
    validation = optional(object({
      tcp_ports = optional(list(number), [22])
      http_urls = optional(list(string), [])
    }), {})
    data_disks = list(object({
      label      = string
      size_gb    = number
      controller = optional(number, 0)
    }))
  }))
}
