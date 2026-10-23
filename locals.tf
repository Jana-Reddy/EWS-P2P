# Local values shared across the lab configuration.

locals {
  # The peering connection and peering routes exist only in "complete" mode.
  peering_enabled = var.deployment_mode == "complete"

  # Host-specific /32 sources used by the private security groups.
  bastion_ip_cidr = "${var.bastion_private_ip}/32"
  app_a_ip_cidr   = "${var.app_a_private_ip}/32"
  app_b_ip_cidr   = "${var.app_b_private_ip}/32"

  # Explicit AMI ID wins; otherwise the latest Amazon Linux 2023 x86_64 AMI
  # of the selected region is used (region-aware, no hardcoded AMI).
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023.id

  key_name = var.key_pair_name
}
