# Networking layer (README sections 3, 5, 9):
# two non-overlapping VPCs, three subnets, one Internet Gateway on VPC A,
# three explicitly named route tables and three explicit subnet associations.
#
# Deliberately absent (README section 9):
#   * no NAT gateway,
#   * no default (0.0.0.0/0) routes on the private route tables,
#   * VPC B has no Internet Gateway at all.

resource "aws_vpc" "a" {
  cidr_block           = var.vpc_a_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "ewb-vpc-a" }
}

resource "aws_vpc" "b" {
  cidr_block           = var.vpc_b_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "ewb-vpc-b" }
}

# Availability zone choice is deterministic: the first AZ of the region.
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "a_public" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = var.subnet_a_public_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "ewb-a-public" }
}

resource "aws_subnet" "a_private" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = var.subnet_a_private_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = { Name = "ewb-a-private" }
}

resource "aws_subnet" "b_private" {
  vpc_id                  = aws_vpc.b.id
  cidr_block              = var.subnet_b_private_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = { Name = "ewb-b-private" }
}

# ------------------------------------------------------------------
# Internet Gateway - VPC A only (the bastion needs an entry point).
# ------------------------------------------------------------------

resource "aws_internet_gateway" "a" {
  vpc_id = aws_vpc.a.id

  tags = { Name = "ewb-igw-a" }
}

# ------------------------------------------------------------------
# Route tables. AWS injects the implicit local routes automatically; they
# are preserved and expanded here only for documentation clarity.
# ------------------------------------------------------------------

resource "aws_route_table" "a_public" {
  vpc_id = aws_vpc.a.id

  # NOTE: no inline `route` blocks are used on purpose. AWS injects the local
  # route automatically, and all other routes are managed as separate
  # aws_route resources. Mixing inline routes with aws_route resources would
  # let table updates delete the separate routes (observed live in this lab).

  tags = { Name = "ewb-rt-a-public" }
}

resource "aws_route_table" "a_private" {
  vpc_id = aws_vpc.a.id

  # Same rule as above: local route is implicit; peer route is an aws_route.

  tags = { Name = "ewb-rt-a-private" }
}

resource "aws_route_table" "b_private" {
  vpc_id = aws_vpc.b.id

  # Same rule as above: local route is implicit; peer route is an aws_route.

  tags = { Name = "ewb-rt-b-private" }
}

# ------------------------------------------------------------------
# Explicit subnet-to-route-table associations (README section 9).
# ------------------------------------------------------------------

resource "aws_route_table_association" "a_public" {
  subnet_id      = aws_subnet.a_public.id
  route_table_id = aws_route_table.a_public.id
}

resource "aws_route_table_association" "a_private" {
  subnet_id      = aws_subnet.a_private.id
  route_table_id = aws_route_table.a_private.id
}

resource "aws_route_table_association" "b_private" {
  subnet_id      = aws_subnet.b_private.id
  route_table_id = aws_route_table.b_private.id
}

# ------------------------------------------------------------------
# Routes.
# ------------------------------------------------------------------

# Always present: bastion internet connectivity.
resource "aws_route" "a_public_internet" {
  route_table_id         = aws_route_table.a_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.a.id
}

# Present only in "complete" mode - added AFTER the baseline failure test.
# Bastion subnet route to VPC B (README section 9, route table A).
resource "aws_route" "a_public_peer" {
  count                     = local.peering_enabled ? 1 : 0
  route_table_id            = aws_route_table.a_public.id
  destination_cidr_block    = var.vpc_b_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

# App-A forward route to VPC B (README section 9, route table B).
resource "aws_route" "a_private_peer" {
  count                     = local.peering_enabled ? 1 : 0
  route_table_id            = aws_route_table.a_private.id
  destination_cidr_block    = var.vpc_b_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

# App-B return route to VPC A (README section 9, route table C).
resource "aws_route" "b_private_peer" {
  count                     = local.peering_enabled ? 1 : 0
  route_table_id            = aws_route_table.b_private.id
  destination_cidr_block    = var.vpc_a_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}
