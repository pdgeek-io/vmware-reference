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

variable "run_ansible_after_apply" {
  description = "Run the local Ansible post-provision handoff from inside terraform apply."
  type        = bool
  default     = false
}

variable "manage_vsphere_tags" {
  description = "Create missing workload tag categories/tags. Disable when a site has pre-created governed tags."
  type        = bool
  default     = true
}

variable "ansible_handoff_version" {
  description = "Increment to force the Terraform-driven Ansible handoff to rerun without changing VM metadata."
  type        = string
  default     = "1"
}

variable "ansible_inventory_renderer" {
  description = "Path to the Terraform-output-to-Ansible-inventory renderer, relative to this Terraform stack."
  type        = string
  default     = "../../../scripts/render-terraform-inventory.py"
}

variable "ansible_inventory_path" {
  description = "Generated Ansible inventory path, relative to this Terraform stack."
  type        = string
  default     = "../../../config/generated/higher-ed-hosts.yml"
}

variable "ansible_inventory_group" {
  description = "Generated Ansible inventory group used by the higher-ed baseline playbook."
  type        = string
  default     = "higher_ed_linux"
}

variable "ansible_config_path" {
  description = "Ansible config path, relative to this Terraform stack."
  type        = string
  default     = "../../../ansible/ansible.cfg"
}

variable "ansible_playbook_path" {
  description = "Post-provision Ansible playbook path, relative to this Terraform stack."
  type        = string
  default     = "../../../ansible/playbooks/higher-ed-linux-baseline.yml"
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
      managed_by          = optional(string, "VMware Automation")
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
