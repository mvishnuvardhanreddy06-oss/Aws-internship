output "region" {
  value = var.region
}

output "key_name" {
  value = var.key_name
}

output "vpc_a_id" {
  value = aws_vpc.a.id
}

output "vpc_b_id" {
  value = aws_vpc.b.id
}

output "subnet_a_public_id" {
  value = aws_subnet.a_public.id
}

output "subnet_a_private_id" {
  value = aws_subnet.a_private.id
}

output "subnet_b_private_id" {
  value = aws_subnet.b_private.id
}

output "igw_id" {
  value = aws_internet_gateway.a.id
}

output "rt_a_public_id" {
  value = aws_route_table.a_public.id
}

output "rt_a_private_id" {
  value = aws_route_table.a_private.id
}

output "rt_b_private_id" {
  value = aws_route_table.b_private.id
}

output "sg_bastion_id" {
  value = aws_security_group.bastion.id
}

output "sg_app_a_id" {
  value = aws_security_group.app_a.id
}

output "sg_app_b_id" {
  value = aws_security_group.app_b.id
}

output "instance_bastion_id" {
  value = aws_instance.bastion.id
}

output "instance_app_a_id" {
  value = aws_instance.app_a.id
}

output "instance_app_b_id" {
  value = aws_instance.app_b.id
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  value = aws_instance.bastion.private_ip
}

output "app_a_private_ip" {
  value = aws_instance.app_a.private_ip
}

output "app_b_private_ip" {
  value = aws_instance.app_b.private_ip
}

# Empty string until stage 2 (enable_peering = true)
output "peering_id" {
  value = var.enable_peering ? aws_vpc_peering_connection.a_b[0].id : ""
}
