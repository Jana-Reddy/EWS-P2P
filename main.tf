# Core resources that do not belong to the other layer files:
# AMI lookup, key pair handling, and the VPC peering connection.
# Routes targeting the peering connection live in networking.tf.

# ------------------------------------------------------------------
# Region-aware Amazon Linux 2023 AMI lookup (README section 15).
# A hardcoded AMI ID would become invalid when the region changes, so it
# is looked up per region unless var.ami_id explicitly overrides it.
# ------------------------------------------------------------------

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ------------------------------------------------------------------
# Key pair (README section 11).
# Default: reference an existing key pair (created once, e.g. from the
# console): the local private key must already exist at ~/.ssh/<name>.pem
# Optional: create the pair from user-supplied PUBLIC key material.
# The private key itself is never uploaded, copied or referenced here.
# ------------------------------------------------------------------

data "aws_key_pair" "lab" {
  count         = var.create_key_pair ? 0 : 1
  key_pair_name = var.key_pair_name
}

resource "aws_key_pair" "lab" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.key_pair_name
  public_key = var.public_key

  tags = { Name = var.key_pair_name }
}

# Plan-time sanity checks (README sections 11 and 15).

check "key_pair_setup" {
  assert(
    var.create_key_pair ? var.public_key != "" : true,
    "public_key is required when create_key_pair = true. Generate a local key pair first (ssh-keygen -f ~/.ssh/${var.key_pair_name}.pem) and pass its public material only."
  )
}

# ------------------------------------------------------------------
# VPC peering connection (README sections 3, 8, 9).
# Created and auto-accepted only in "complete" mode. auto_accept is valid
# here because both VPCs belong to the same AWS account in one region.
# VPC peering is non-transitive: routes must be added on BOTH sides
# (see aws_route resources in networking.tf). No Internet access is
# implied by the peering connection.
# ------------------------------------------------------------------

resource "aws_vpc_peering_connection" "a_b" {
  count       = local.peering_enabled ? 1 : 0
  vpc_id      = aws_vpc.a.id
  peer_vpc_id = aws_vpc.b.id
  auto_accept = true

  tags = { Name = "ewb-a-b-peer" }
}
