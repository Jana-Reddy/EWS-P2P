# Input variables (README sections 5, 6, 10, 11, 15).
#
# Values documented in the IP addressing plan are provided as defaults and
# may be changed only with a documented reason. Every IP/CIDR input is
# validated; the administrator SSH source must stay a host-specific /32.

# ------------------------------------------------------------------
# General
# ------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region into which every lab resource is deployed."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region code, e.g. ap-south-1."
  }
}

variable "student_name" {
  description = "Student name used in resource tags and in the report."
  type        = string
  default     = "YOUR_NAME"

  validation {
    condition     = length(trimspace(var.student_name)) > 0 && var.student_name != "YOUR_NAME"
    error_message = "student_name must not be empty. Replace YOUR_NAME with your own name."
  }
}

variable "project_name" {
  description = "Project tag applied to every lab resource."
  type        = string
  default     = "EWB-VPC-Peering"
}

variable "environment" {
  description = "Environment tag applied to every lab resource."
  type        = string
  default     = "Lab"
}

variable "deployment_mode" {
  description = <<-EOT
    Deployment mode (README section 8):

      staged   - creates VPCs, subnets, the Internet Gateway, route tables,
                 security groups and EC2 instances, but NO peering connection
                 and NO peering routes. Use this mode to capture the required
                 baseline ping failure before peering exists.

      complete - additionally creates the peering connection and all three
                 peering routes (public subnet, private subnet A, private
                 subnet B) for the positive tests.

    Switching modes is an explicit action: review terraform plan first, then
    apply with -var='deployment_mode=complete'. Never switch before the
    baseline failure evidence has been captured.
  EOT
  type        = string
  default     = "staged"

  validation {
    condition     = contains(["staged", "complete"], var.deployment_mode)
    error_message = "deployment_mode must be 'staged' or 'complete'."
  }
}

# ------------------------------------------------------------------
# Identity and key material
# ------------------------------------------------------------------

variable "admin_cidr" {
  description = <<-EOT
    Administrator public IPv4 CIDR, used as the ONLY source allowed to SSH
    to the bastion. Must be a host-specific /32 and must not be 0.0.0.0/0.
    Find your current IP with: curl -s https://checkip.amazonaws.com
  EOT
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/32$", var.admin_cidr)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr must be a host-specific IPv4 /32 (e.g. 203.0.113.10/32) and must not be 0.0.0.0/0."
  }
}

variable "key_pair_name" {
  description = "EC2 key pair used by all three instances (README section 11)."
  type        = string
  default     = "ewb-lab"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{3,64}$", var.key_pair_name))
    error_message = "key_pair_name must be 3-64 characters of letters, digits, '.', '_' or '-'."
  }
}

variable "create_key_pair" {
  description = <<-EOT
    When false (default), Terraform looks up an EXISTING key pair by
    key_pair_name; create it once in the AWS console first (or import the
    public key of your local private key).

    When true, Terraform creates the key pair from var.public_key. Terraform
    never touches the private key: keep it local, chmod 400, never commit it.
  EOT
  type        = bool
  default     = false
}

variable "public_key" {
  description = "Public key material for aws_key_pair. Required only when create_key_pair = true."
  type        = string
  default     = ""

  validation {
    condition     = var.public_key == "" || can(startswith(var.public_key, "ssh-"))
    error_message = "public_key must be OpenSSH public key material starting with 'ssh-'."
  }
}

# ------------------------------------------------------------------
# Compute
# ------------------------------------------------------------------

variable "instance_type" {
  description = "Small x86 instance type for all three instances (README section 11)."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro", "t4.micro", "t3.nano", "t3.small"], var.instance_type)
    error_message = "instance_type must be one of: t2.micro, t3.micro, t4.micro, t3.nano, t3.small."
  }
}

variable "ami_id" {
  description = <<-EOT
    Optional explicit AMI ID for the region you deploy to. Leave empty to
    look up the latest Amazon Linux 2023 x86_64 AMI owned by AWS in the
    selected region (region-aware default, no hardcoded AMI).
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.ami_id == "" || can(regex("^ami-[0-9a-f]{8,}$", var.ami_id))
    error_message = "ami_id must be empty or look like an AMI ID (ami-...)."
  }
}

# ------------------------------------------------------------------
# Network addressing (README section 5 - do not change without a
# documented reason; the two VPC CIDRs must never overlap)
# ------------------------------------------------------------------

variable "vpc_a_cidr" {
  description = "IPv4 CIDR for VPC A (ewb-vpc-a). Must not overlap VPC B."
  type        = string
  default     = "10.10.0.0/16"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(1[6-9]|2[0-8])$", var.vpc_a_cidr))
    error_message = "vpc_a_cidr must be an IPv4 CIDR with a mask between /16 and /28."
  }
}

variable "vpc_b_cidr" {
  description = "IPv4 CIDR for VPC B (ewb-vpc-b). Must not overlap VPC A."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(1[6-9]|2[0-8])$", var.vpc_b_cidr))
    error_message = "vpc_b_cidr must be an IPv4 CIDR with a mask between /16 and /28."
  }
}

variable "subnet_a_public_cidr" {
  description = "CIDR of the public subnet in VPC A (bastion)."
  type        = string
  default     = "10.10.1.0/24"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(1[6-9]|2[0-8])$", var.subnet_a_public_cidr))
    error_message = "subnet_a_public_cidr must be an IPv4 CIDR with a mask between /16 and /28."
  }
}

variable "subnet_a_private_cidr" {
  description = "CIDR of the private subnet in VPC A (App-A)."
  type        = string
  default     = "10.10.2.0/24"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(1[6-9]|2[0-8])$", var.subnet_a_private_cidr))
    error_message = "subnet_a_private_cidr must be an IPv4 CIDR with a mask between /16 and /28."
  }
}

variable "subnet_b_private_cidr" {
  description = "CIDR of the private subnet in VPC B (App-B)."
  type        = string
  default     = "10.20.1.0/24"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(1[6-9]|2[0-8])$", var.subnet_b_private_cidr))
    error_message = "subnet_b_private_cidr must be an IPv4 CIDR with a mask between /16 and /28."
  }
}

# ------------------------------------------------------------------
# Static private IPv4 addresses (README section 5)
# ------------------------------------------------------------------

variable "bastion_private_ip" {
  description = "Planned private IPv4 of the bastion inside subnet_a_public_cidr."
  type        = string
  default     = "10.10.1.10"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.bastion_private_ip))
    error_message = "bastion_private_ip must be a bare IPv4 address."
  }
}

variable "app_a_private_ip" {
  description = "Planned private IPv4 of App-A inside subnet_a_private_cidr."
  type        = string
  default     = "10.10.2.10"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.app_a_private_ip))
    error_message = "app_a_private_ip must be a bare IPv4 address."
  }
}

variable "app_b_private_ip" {
  description = "Planned private IPv4 of App-B inside subnet_b_private_cidr."
  type        = string
  default     = "10.20.1.10"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.app_b_private_ip))
    error_message = "app_b_private_ip must be a bare IPv4 address."
  }
}
