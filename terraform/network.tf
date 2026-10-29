# ---------------------------------------------------------------------------
# VPC A (10.10.0.0/16): public subnet for the bastion, private subnet for App-A
# ---------------------------------------------------------------------------
resource "aws_vpc" "a" {
  cidr_block           = local.vpc_a_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "ewb-vpc-a" }
}

resource "aws_subnet" "a_public" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = local.public_a_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false # public IPv4 is requested per instance (bastion only)

  tags = { Name = "ewb-a-public" }
}

resource "aws_subnet" "a_private" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = local.private_a_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false

  tags = { Name = "ewb-a-private" }
}

resource "aws_internet_gateway" "a" {
  vpc_id = aws_vpc.a.id

  tags = { Name = "ewb-igw-a" }
}

# Public route table: local route (automatic) + 0.0.0.0/0 -> IGW
resource "aws_route_table" "a_public" {
  vpc_id = aws_vpc.a.id

  tags = { Name = "ewb-rt-a-public" }
}

resource "aws_route" "a_public_internet" {
  route_table_id         = aws_route_table.a_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.a.id
}

resource "aws_route_table_association" "a_public" {
  subnet_id      = aws_subnet.a_public.id
  route_table_id = aws_route_table.a_public.id
}

# Private route table: local route only (peering route is added in peering.tf)
resource "aws_route_table" "a_private" {
  vpc_id = aws_vpc.a.id

  tags = { Name = "ewb-rt-a-private" }
}

resource "aws_route_table_association" "a_private" {
  subnet_id      = aws_subnet.a_private.id
  route_table_id = aws_route_table.a_private.id
}

# ---------------------------------------------------------------------------
# VPC B (10.20.0.0/16): one private subnet, no internet gateway
# ---------------------------------------------------------------------------
resource "aws_vpc" "b" {
  cidr_block           = local.vpc_b_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "ewb-vpc-b" }
}

resource "aws_subnet" "b_private" {
  vpc_id                  = aws_vpc.b.id
  cidr_block              = local.private_b_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false

  tags = { Name = "ewb-b-private" }
}

resource "aws_route_table" "b_private" {
  vpc_id = aws_vpc.b.id

  tags = { Name = "ewb-rt-b-private" }
}

resource "aws_route_table_association" "b_private" {
  subnet_id      = aws_subnet.b_private.id
  route_table_id = aws_route_table.b_private.id
}
