.PHONY: init build-templates build-template-ubuntu deploy-workloads deploy-higher-ed-baseline setup-tags validate validate-vsphere-lab validate-higher-ed-baseline validate-ubuntu-2404-cis-template destroy help

SHELL := /bin/bash
CONFIG_DIR := config
TERRAFORM_DIR := terraform/stacks
PACKER_DIR := packer/builds
ANSIBLE_DIR := ansible

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform, Ansible Galaxy, and Packer for the baseline
	@echo "==> Initializing Terraform workload stack..."
	terraform -chdir=$(TERRAFORM_DIR)/03-workloads init -upgrade
	@echo "==> Installing Ansible Galaxy collections..."
	ansible-galaxy collection install -r $(ANSIBLE_DIR)/requirements.yml --force
	@echo "==> Installing Packer plugins..."
	packer init $(PACKER_DIR)/linux/ubuntu-2404/
	@echo "==> Initialization complete."

build-templates: build-template-ubuntu ## Build the validated Ubuntu 24.04 VM template

build-template-ubuntu: ## Build Ubuntu 24.04 template
	@echo "==> Building Ubuntu 24.04 template..."
	packer build -force \
		-var-file="packer/config/vsphere.pkrvars.hcl" \
		-var-file="packer/config/common.pkrvars.hcl" \
		$(PACKER_DIR)/linux/ubuntu-2404/

deploy-workloads: ## Deploy VMs from terraform/stacks/03-workloads
	@echo "==> Deploying workload VMs..."
	terraform -chdir=$(TERRAFORM_DIR)/03-workloads apply -auto-approve

deploy-higher-ed-baseline: ## Deploy first higher-ed VM with Terraform, then configure with Ansible
	@echo "==> Deploying higher-ed baseline workload..."
	terraform -chdir=$(TERRAFORM_DIR)/03-workloads apply -auto-approve \
		-var run_ansible_after_apply=true

setup-tags: ## Initialize baseline vSphere tag categories and values
	@echo "==> Setting up baseline vSphere tags..."
	pwsh -File scripts/setup-vsphere-tags.ps1

validate: ## Validate the supported baseline
	@bash tests/scripts/validate-all.sh

validate-vsphere-lab: ## Validate vSphere lab readiness for the smallest API lab
	@bash tests/scripts/validate-vsphere-lab-readiness.sh

validate-higher-ed-baseline: ## Validate first higher-ed common infrastructure slice
	@bash tests/scripts/validate-higher-ed-baseline.sh

validate-ubuntu-2404-cis-template: ## Validate Ubuntu 24.04 Packer CIS baseline hook
	@bash tests/scripts/validate-ubuntu-2404-cis-template.sh

destroy: ## Destroy the baseline workload stack
	@echo "==> WARNING: This will destroy all deployed VMs in terraform/stacks/03-workloads."
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	terraform -chdir=$(TERRAFORM_DIR)/03-workloads destroy -auto-approve
	@echo "==> Teardown complete."
