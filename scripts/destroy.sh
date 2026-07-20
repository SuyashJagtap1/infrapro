#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

echo "Destroying InfraPro AWS resources..."

terraform -chdir="${TERRAFORM_DIR}" destroy \
  -input=false \
  -auto-approve

echo "InfraPro resources destroyed successfully."