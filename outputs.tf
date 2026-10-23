# Outputs (README section 15). No credentials or private-key material is
# ever exposed. Peering-related outputs are null while the deployment is
# in "staged" mode (intentional pre-peering state).

output "vpc_a_id" {
  description = "VPC A (ewb-vpc-a) ID."
  value       = aws_vpc.a.id
}

output "vpc_b_id" {
  description = "VPC B (ewb-vpc-b) ID."
  value       = aws_vpc.b.id
}

output "public_subnet_id" {
  description = "Public subnet ID in VPC A (ewb-a-public)."
  value       = aws_subnet.a_public.id
}

output "private_subnet_a_id" {
  description = "Private subnet ID in VPC A (ewb-a-private)."
  value       = aws_subnet.a_private.id
}

output "private_subnet_b_id" {
  description = "Private subnet ID in VPC B (ewb-b-private)."
  value       = aws_subnet.b_private.id
}

output "internet_gateway_id" {
  description = "Internet Gateway attached to VPC A."
  value       = aws_internet_gateway.a.id
}

output "public_route_table_id" {
  description = "Route table of the bastion subnet (ewb-rt-a-public)."
  value       = aws_route_table.a_public.id
}

output "private_route_table_a_id" {
  description = "Route table of App-A's subnet (ewb-rt-a-private)."
  value       = aws_route_table.a_private.id
}

output "private_route_table_b_id" {
  description = "Route table of App-B's subnet (ewb-rt-b-private)."
  value       = aws_route_table.b_private.id
}

output "peering_connection_id" {
  description = <<-DESC
    VPC peering connection ID (ewb-a-b-peer). Null in staged mode; populated
    once deployment_mode is switched to "complete".
  DESC
  value       = try(aws_vpc_peering_connection.a_b[0].id, null)
}

output "bastion_instance_id" {
  description = "EC2 instance ID of the bastion host."
  value       = aws_instance.bastion.id
}

output "app_a_instance_id" {
  description = "EC2 instance ID of App-A."
  value       = aws_instance.app_a.id
}

output "app_b_instance_id" {
  description = "EC2 instance ID of App-B."
  value       = aws_instance.app_b.id
}

output "bastion_public_ip" {
  description = "Public IPv4 of the bastion. Pass it to scripts/configure-ssh.sh --bastion-ip."
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Private IPv4 of the bastion (source of SSH to the app servers)."
  value       = aws_instance.bastion.private_ip
}

output "app_a_private_ip" {
  description = "Private IPv4 of App-A (must equal the documented 10.10.2.10)."
  value       = aws_instance.app_a.private_ip
}

output "app_b_private_ip" {
  description = "Private IPv4 of App-B (must equal the documented 10.20.1.10)."
  value       = aws_instance.app_b.private_ip
}
