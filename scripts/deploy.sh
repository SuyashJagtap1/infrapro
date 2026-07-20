#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

echo "Formatting Terraform configuration..."
terraform -chdir="${TERRAFORM_DIR}" fmt -recursive

echo "Initializing Terraform..."
terraform -chdir="${TERRAFORM_DIR}" init -input=false

echo "Validating Terraform configuration..."
terraform -chdir="${TERRAFORM_DIR}" validate

echo "Creating Terraform plan..."
terraform -chdir="${TERRAFORM_DIR}" plan \
  -input=false \
  -out=tfplan

echo "Applying Terraform plan..."
terraform -chdir="${TERRAFORM_DIR}" apply \
  -input=false \
  -auto-approve \
  tfplan

echo "InfraPro deployment completed successfully."
terraform -chdir="${TERRAFORM_DIR}" output