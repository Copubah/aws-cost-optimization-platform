.PHONY: help init plan apply destroy validate format clean test

# Variables
TERRAFORM_DIR := terraform
ENVIRONMENT ?= dev

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	cd $(TERRAFORM_DIR) && terraform init

validate: ## Validate Terraform configuration
	cd $(TERRAFORM_DIR) && terraform validate

format: ## Format Terraform files
	cd $(TERRAFORM_DIR) && terraform fmt -recursive

plan: ## Generate Terraform plan
	cd $(TERRAFORM_DIR) && terraform plan -out=tfplan

apply: ## Apply Terraform changes
	cd $(TERRAFORM_DIR) && terraform apply tfplan

apply-auto: ## Apply Terraform changes without confirmation
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve

destroy: ## Destroy all resources
	cd $(TERRAFORM_DIR) && terraform destroy

output: ## Show Terraform outputs
	cd $(TERRAFORM_DIR) && terraform output

clean: ## Clean up temporary files
	find . -type f -name "*.zip" -delete
	find . -type f -name "tfplan" -delete
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".pytest_cache" -exec rm -rf {} +

test-lambda: ## Test Lambda functions locally
	@echo "Testing cost optimizer..."
	cd lambda/cost_optimizer && python -m pytest tests/ || echo "No tests found"
	@echo "Testing budget handler..."
	cd lambda/notifications && python -m pytest tests/ || echo "No tests found"

package-lambda: ## Package Lambda functions
	@echo "Packaging Lambda functions..."
	cd lambda/cost_optimizer && zip -r ../../terraform/modules/lambda/cost_optimizer.zip . -x "*.pyc" -x "__pycache__/*" -x "tests/*"
	cd lambda/notifications && zip -r ../../terraform/modules/lambda/budget_handler.zip . -x "*.pyc" -x "__pycache__/*" -x "tests/*"

lint: ## Lint Python code
	@echo "Linting Python code..."
	find lambda -name "*.py" -exec pylint {} + || true

security-scan: ## Run security scan
	@echo "Running security scan..."
	cd $(TERRAFORM_DIR) && terraform init -backend=false
	cd $(TERRAFORM_DIR) && tfsec . || echo "tfsec not installed"

docs: ## Generate documentation
	@echo "Documentation available in docs/ directory"
	@ls -la docs/

check-aws: ## Check AWS credentials
	@aws sts get-caller-identity

setup-dev: init validate format ## Setup development environment
	@echo "Development environment ready"

deploy-dev: ## Deploy to development environment
	$(MAKE) ENVIRONMENT=dev plan
	$(MAKE) ENVIRONMENT=dev apply

deploy-staging: ## Deploy to staging environment
	$(MAKE) ENVIRONMENT=staging plan
	$(MAKE) ENVIRONMENT=staging apply

deploy-prod: ## Deploy to production environment
	$(MAKE) ENVIRONMENT=prod plan
	@echo "⚠️  WARNING: Deploying to PRODUCTION"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) ENVIRONMENT=prod apply; \
	fi

cost-estimate: ## Estimate infrastructure costs
	@echo "Generating cost estimate..."
	cd $(TERRAFORM_DIR) && terraform plan -out=tfplan > /dev/null
	@echo "Use Infracost or AWS Pricing Calculator for detailed estimates"

graph: ## Generate Terraform dependency graph
	cd $(TERRAFORM_DIR) && terraform graph | dot -Tpng > ../docs/terraform-graph.png
	@echo "Graph saved to docs/terraform-graph.png"
