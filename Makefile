.PHONY: init build-templates deploy-foundation deploy-networking deploy-workloads deploy-vcf-domain deploy-three-tier demo test validate destroy help

SHELL := /bin/bash
CONFIG_DIR := config
TERRAFORM_DIR := terraform/stacks
PACKER_DIR := packer/builds
ANSIBLE_DIR := ansible

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

# ─── Initialization ──────────────────────────────────────────────────

init: ## Initialize all tools (Terraform, Ansible Galaxy, Packer plugins)
	@echo "==> Initializing Terraform stacks..."
	@for stack in $(TERRAFORM_DIR)/*/; do \
		echo "  -> $${stack}"; \
		terraform -chdir=$${stack} init -upgrade; \
	done
	@echo "==> Installing Ansible Galaxy collections..."
	ansible-galaxy collection install -r $(ANSIBLE_DIR)/requirements.yml --force
	@echo "==> Installing Packer plugins..."
	packer init $(PACKER_DIR)/linux/ubuntu-2404/
	packer init $(PACKER_DIR)/linux/rhel-9/
	packer init $(PACKER_DIR)/windows/windows-server-2022/
	@echo "==> Initialization complete."

# ─── Packer Template Builds ─────────────────────────────────────────

build-templates: build-template-ubuntu build-template-rhel build-template-windows ## Build all VM templates

build-template-ubuntu: ## Build Ubuntu 24.04 template
	@echo "==> Building Ubuntu 24.04 template..."
	packer build -force \
		-var-file="packer/config/vsphere.pkrvars.hcl" \
		-var-file="packer/config/common.pkrvars.hcl" \
		$(PACKER_DIR)/linux/ubuntu-2404/

build-template-rhel: ## Build RHEL 9 template
	@echo "==> Building RHEL 9 template..."
	packer build -force \
		-var-file="packer/config/vsphere.pkrvars.hcl" \
		-var-file="packer/config/common.pkrvars.hcl" \
		$(PACKER_DIR)/linux/rhel-9/

build-template-windows: ## Build Windows Server 2022 template
	@echo "==> Building Windows Server 2022 template..."
	packer build -force \
		-var-file="packer/config/vsphere.pkrvars.hcl" \
		-var-file="packer/config/common.pkrvars.hcl" \
		$(PACKER_DIR)/windows/windows-server-2022/

# ─── Terraform Deployments ──────────────────────────────────────────

deploy-foundation: ## Deploy PowerStore volumes + vSphere foundation
	@echo "==> Deploying foundation infrastructure..."
	@source $(CONFIG_DIR)/powerstore.env && \
	terraform -chdir=$(TERRAFORM_DIR)/01-foundation apply -auto-approve

deploy-networking: ## Deploy distributed switches and port groups
	@echo "==> Deploying networking..."
	terraform -chdir=$(TERRAFORM_DIR)/02-networking apply -auto-approve

deploy-workloads: ## Deploy VMs from templates
	@echo "==> Deploying workload VMs..."
	terraform -chdir=$(TERRAFORM_DIR)/03-workloads apply -auto-approve

deploy-vcf-domain: ## Deploy VCF workload domain (requires VCF)
	@echo "==> Deploying VCF workload domain..."
	terraform -chdir=$(TERRAFORM_DIR)/04-vcf-domain apply -auto-approve

# ─── Reference Applications ─────────────────────────────────────────

deploy-three-tier: ## Deploy three-tier web application (nginx + Flask + PostgreSQL)
	@echo "==> Deploying three-tier application..."
	terraform -chdir=reference-vms/three-tier-web-app apply -auto-approve
	ansible-playbook -i $(CONFIG_DIR)/inventory/hosts.yml \
		reference-vms/three-tier-web-app/ansible-playbook.yml

deploy-db-cluster: ## Deploy PostgreSQL primary + replica cluster
	@echo "==> Deploying database cluster..."
	terraform -chdir=reference-vms/database-cluster apply -auto-approve
	ansible-playbook -i $(CONFIG_DIR)/inventory/hosts.yml \
		reference-vms/database-cluster/ansible-playbook.yml

deploy-docker-lab: ## Deploy Docker lab with Portainer
	@echo "==> Deploying Docker lab..."
	terraform -chdir=reference-vms/docker-lab apply -auto-approve
	ansible-playbook -i $(CONFIG_DIR)/inventory/hosts.yml \
		reference-vms/docker-lab/ansible-playbook.yml

# ─── Self-Service ────────────────────────────────────────────────────

demo: ## Launch interactive PowerCLI self-service menu
	@echo "==> Launching self-service demo menu..."
	pwsh -File powercli/scripts/self-service-menu.ps1

portal: ## Start the self-service web portal
	@echo "==> Starting self-service API portal..."
	cd self-service/api && python -m uvicorn app:app --reload --port 8080

# ─── Validation and Testing ─────────────────────────────────────────

validate: ## Validate all Terraform, Packer, and Ansible configs
	@bash tests/scripts/validate-all.sh

test: ## Run smoke tests against deployed infrastructure
	@bash tests/scripts/smoke-test.sh

# ─── Teardown ────────────────────────────────────────────────────────

destroy: ## Destroy all deployed infrastructure (in reverse order)
	@echo "==> WARNING: This will destroy all deployed resources."
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	-terraform -chdir=reference-vms/three-tier-web-app destroy -auto-approve
	-terraform -chdir=reference-vms/database-cluster destroy -auto-approve
	-terraform -chdir=reference-vms/docker-lab destroy -auto-approve
	-terraform -chdir=$(TERRAFORM_DIR)/03-workloads destroy -auto-approve
	-terraform -chdir=$(TERRAFORM_DIR)/02-networking destroy -auto-approve
	-terraform -chdir=$(TERRAFORM_DIR)/01-foundation destroy -auto-approve
	@echo "==> Teardown complete."
