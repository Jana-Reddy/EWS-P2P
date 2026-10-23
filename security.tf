# Security layer (README sections 10 and 18).
#
# Least-privilege inbound rules only; the default outbound allow-all is kept
# explicitly for this educational lab. Security groups are stateful, so no
# return-traffic rules are needed.
#
# Naming requirements:
#   * bastion SSH source = the administrator's public /32 (var.admin_cidr) -
#     never 0.0.0.0/0.
#   * private-instance SSH source = the bastion's PRIVATE /32.
#   * ICMP Echo source = the PINGED peer's private /32.
#   * no broader VPC CIDR sources for these rules.

resource "aws_security_group" "bastion" {
  name        = "ewb-sg-bastion"
  description = "EWB lab bastion: SSH only from the administrator's public /32."
  vpc_id      = aws_vpc.a.id

  ingress {
    description = "SSH from administrator's current public IPv4 (update var.admin_cidr if it changes)"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    description = "Default outbound allow-all (educational lab)"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ewb-sg-bastion" }
}

resource "aws_security_group" "app_a" {
  name        = "ewb-sg-app-a"
  description = "EWB lab App-A: SSH from the bastion and ICMP echo from App-B only."
  vpc_id      = aws_vpc.a.id

  ingress {
    description = "SSH from the bastion's private IP (ProxyJump source)"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [local.bastion_ip_cidr]
  }

  ingress {
    description = "ICMP Echo request from App-B (ping test on App-B)"
    protocol    = "icmp"
    from_port   = 8 # ICMP type 8
    to_port     = 0 # ICMP code 0 (echo request)
    cidr_blocks = [local.app_b_ip_cidr]
  }

  egress {
    description = "Default outbound allow-all (educational lab)"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ewb-sg-app-a" }
}

resource "aws_security_group" "app_b" {
  name        = "ewb-sg-app-b"
  description = "EWB lab App-B: SSH from the bastion and ICMP echo from App-A only."
  vpc_id      = aws_vpc.b.id

  ingress {
    description = "SSH from the bastion's private IP (ProxyJump source)"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [local.bastion_ip_cidr]
  }

  ingress {
    description = "ICMP Echo request from App-A (ping test on App-B; remove/re-add for the controlled failure test)"
    protocol    = "icmp"
    from_port   = 8 # ICMP type 8
    to_port     = 0 # ICMP code 0 (echo request)
    cidr_blocks = [local.app_a_ip_cidr]
  }

  egress {
    description = "Default outbound allow-all (educational lab)"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ewb-sg-app-b" }
}
