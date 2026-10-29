# Stage 2: peering connection + the three routes (workbook pp.9-10).
# Same account and Region, so auto_accept performs the "Accept request" step.
resource "aws_vpc_peering_connection" "a_b" {
  count = var.enable_peering ? 1 : 0

  vpc_id      = aws_vpc.a.id # requester
  peer_vpc_id = aws_vpc.b.id # accepter
  auto_accept = true

  tags = { Name = "ewb-a-b-peer" }
}

# ewb-rt-a-private: 10.20.0.0/16 -> pcx (App-A to VPC B)
resource "aws_route" "a_private_to_b" {
  count = var.enable_peering ? 1 : 0

  route_table_id            = aws_route_table.a_private.id
  destination_cidr_block    = local.vpc_b_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

# ewb-rt-b-private: 10.10.0.0/16 -> pcx (return path to VPC A)
resource "aws_route" "b_private_to_a" {
  count = var.enable_peering ? 1 : 0

  route_table_id            = aws_route_table.b_private.id
  destination_cidr_block    = local.vpc_a_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

# ewb-rt-a-public: 10.20.0.0/16 -> pcx (bastion SSH to App-B through ProxyJump)
resource "aws_route" "a_public_to_b" {
  count = var.enable_peering ? 1 : 0

  route_table_id            = aws_route_table.a_public.id
  destination_cidr_block    = local.vpc_b_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}
