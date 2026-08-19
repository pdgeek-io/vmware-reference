output "vm_inventory" {
  description = "VM placement, address, and metadata for the Terraform-to-Ansible handoff."
  value       = local.vm_inventory
}

output "dns_ipam_placeholders" {
  description = "DNS/IPAM work items for external handling. The baseline keeps provider integration as a placeholder."
  value = {
    for name, vm in var.vms : name => merge(
      {
        provider    = "placeholder"
        record_type = "A"
        fqdn        = "${name}.${var.domain}"
        ip_address  = vm.ip_address
        ttl         = 3600
        ptr         = true
      },
      try(vm.dns_ipam, {})
    )
  }
}

output "app_deployment_hooks" {
  description = "Post-provision hooks for orchestration layers to run after Terraform creates VM shells."
  value = {
    for name, vm in var.vms : name => {
      ansible_playbooks = try(vm.app_hooks.ansible_playbooks, [])
      webhook_url_var   = try(vm.app_hooks.webhook_url_var, null)
      post_provision    = try(vm.app_hooks.post_provision, [])
      validation        = try(vm.validation, {})
    }
  }
}
