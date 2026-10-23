# Compute layer (README sections 5, 11).
#
# All three instances use the same key pair, the same small x86 instance
# type and the region-aware Amazon Linux 2023 AMI. Only the bastion gets a
# public IPv4 address. Private addresses are pinned to the documented plan
# so that routes, security-group rules and SSH config can rely on them.
#
# No user_data is used: the private instances have no internet egress by
# design, and this lab deliberately avoids installing extra packages.

resource "aws_instance" "bastion" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.a_public.id
  private_ip                  = var.bastion_private_ip
  key_name                    = local.key_name
  associate_public_ip_address = true
  monitoring                  = false

  vpc_security_group_ids = [aws_security_group.bastion.id]

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = "ewb-bastion" }
}

resource "aws_instance" "app_a" {
  ami           = local.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.a_private.id
  private_ip    = var.app_a_private_ip
  key_name      = local.key_name
  monitoring    = false

  # Note: associate_public_ip_address is NOT set - App-A must stay private.
  vpc_security_group_ids = [aws_security_group.app_a.id]

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = "ewb-app-a" }
}

resource "aws_instance" "app_b" {
  ami           = local.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.b_private.id
  private_ip    = var.app_b_private_ip
  key_name      = local.key_name
  monitoring    = false

  # Note: associate_public_ip_address is NOT set - App-B must stay private.
  vpc_security_group_ids = [aws_security_group.app_b.id]

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = "ewb-app-b" }
}
