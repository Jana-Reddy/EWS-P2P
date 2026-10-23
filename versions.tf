# Terraform and provider version constraints (README section 15).
# The `check` block used in main.tf requires Terraform 1.5 or newer.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0, < 6.0.0"
    }
  }
}
