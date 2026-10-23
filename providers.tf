# AWS provider configuration (README sections 8 and 15).
#
# Credentials are resolved through the standard AWS credential chain
# (shared config/credentials files, environment variables, SSO or an
# assumed role). No credentials are embedded anywhere in this repository.

provider "aws" {
  region = var.aws_region

  # Standard tags from README section 6 are applied automatically to every
  # resource this configuration creates. Per-resource Name tags are set on
  # each resource individually. Resources created manually in the console
  # do not inherit these tags: omit ManagedBy = Terraform for them.
  default_tags {
    tags = {
      Project     = var.project_name
      Student     = var.student_name
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
