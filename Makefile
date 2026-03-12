.PHONY: init build-templates deploy-workloads deploy-three-tier deploy-research-storage demo portal chargeback setup-tags test validate destroy help

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
	packer init $(PACKER_DIR)/windows/windows-server-2025/
	@echo "==> Initializing PowerScale Terraform stack..."
	terraform -chdir=$(TERRAFORM_DIR)/04-research-storage init -upgrade
	@echo "==> Initialization complete."

# ─── VM Template Factory ─────────────────────────────────────────────

build-templates: build-template-ubuntu build-template-rhel build-template-windows build-template-windows-2025 ## Build all VM templates

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

build-template-windows-2025: ## Build Windows Server 2025 template
	@echo "==> Building Windows Server 2025 template..."
	packer build -force \
		-var-file="packer/config/vsphere.pkrvars.hcl" \
		-var-file="packer/config/common.pkrvars.hcl" \
		$(PACKER_DIR)/windows/windows-server-2025/

# ─── VM Deployments ──────────────────────────────────────────────────

deploy-workloads: ## Deploy VMs from templates via Terraform
	@echo "==> Deploying workload VMs..."
	terraform -chdir=$(TERRAFORM_DIR)/03-workloads apply -auto-approve

deploy-three-tier: ## Deploy three-tier web application (nginx + Flask + PostgreSQL)
	@echo "==> Deploying three-tier application..."
	terraform -chdir=reference-vms/three-tier-web-app apply -auto-approve
	ansible-playbook -i $(CONFIG_DIR)/inventory/hosts.yml \
		reference-vms/three-tier-web-app/ansible-playbook.yml

# ─── Research Storage (PowerScale) ────────────────────────────────────

deploy-research-storage: ## Provision research NFS shares on PowerScale
	@echo "==> Deploying research storage shares..."
	terraform -chdir=$(TERRAFORM_DIR)/04-research-storage apply -auto-approve

destroy-research-storage: ## Remove research shares from PowerScale
	@echo "==> WARNING: This will remove all research shares."
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	terraform -chdir=$(TERRAFORM_DIR)/04-research-storage destroy -auto-approve

# ─── Self-Service & Operations ───────────────────────────────────────

demo: ## Launch interactive Day 2 operations menu
	@echo "==> Launching Day 2 operations menu..."
	pwsh -File powercli/scripts/self-service-menu.ps1

portal: ## Start the self-service web portal
	@echo "==> Starting self-service API portal..."
	cd self-service/api && python -m uvicorn app:app --reload --port 8080

# ─── Chargeback / Showback ───────────────────────────────────────────

setup-tags: ## Initialize chargeback tag categories in vCenter
	@echo "==> Setting up chargeback tags..."
	pwsh -File chargeback/templates/tags-setup.ps1

chargeback: ## Generate chargeback report
	@echo "==> Generating chargeback report..."
	pwsh -Command "Import-Module ./powercli/modules/PDGeekRef; Get-VMChargeback -OutputFormat CSV"

# ─── Validation and Testing ──────────────────────────────────────────

validate: ## Validate all Terraform, Packer, and Ansible configs
	@bash tests/scripts/validate-all.sh

test: ## Run smoke tests against deployed infrastructure
	@bash tests/scripts/smoke-test.sh

# ─── Teardown ────────────────────────────────────────────────────────

destroy: ## Destroy all deployed VMs (in reverse order)
	@echo "==> WARNING: This will destroy all deployed VMs."
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	-terraform -chdir=reference-vms/three-tier-web-app destroy -auto-approve
	-terraform -chdir=$(TERRAFORM_DIR)/03-workloads destroy -auto-approve
	@echo "==> Teardown complete."
