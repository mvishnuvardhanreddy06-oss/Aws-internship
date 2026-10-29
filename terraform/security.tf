# Security groups with explicit rule resources. Terraform removes the default
# allow-all egress rule from groups it manages, so egress is re-created below
# (workbook p.6: keep default outbound allow-all for this beginner lab).

resource "aws_security_group" "bastion" {
  name        = "ewb-sg-bastion"
  description = "EWB bastion: SSH from the student public IP only"
  vpc_id      = aws_vpc.a.id

  tags = { Name = "ewb-sg-bastion" }
}

resource "aws_security_group" "app_a" {
  name        = "ewb-sg-app-a"
  description = "EWB App-A: SSH from bastion and ICMP echo from App-B"
  vpc_id      = aws_vpc.a.id

  tags = { Name = "ewb-sg-app-a" }
}

resource "aws_security_group" "app_b" {
  name        = "ewb-sg-app-b"
  description = "EWB App-B: SSH from bastion and ICMP echo from App-A"
  vpc_id      = aws_vpc.b.id

  tags = { Name = "ewb-sg-app-b" }
}

# --- ewb-sg-bastion -------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH from student public IPv4"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.my_ip_cidr
}

# --- ewb-sg-app-a ---------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "app_a_ssh_from_bastion" {
  security_group_id = aws_security_group.app_a.id
  description       = "SSH from bastion private IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${local.bastion_ip}/32"
}

resource "aws_vpc_security_group_ingress_rule" "app_a_icmp_from_app_b" {
  security_group_id = aws_security_group.app_a.id
  description       = "ICMP echo request from App-B"
  ip_protocol       = "icmp"
  from_port         = 8 # ICMP type 8 = Echo request
  to_port           = 0 # ICMP code 0
  cidr_ipv4         = "${local.app_b_ip}/32"
}

# --- ewb-sg-app-b ---------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "app_b_ssh_from_bastion" {
  security_group_id = aws_security_group.app_b.id
  description       = "SSH from bastion private IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${local.bastion_ip}/32"
}

# This is the rule removed and restored by the controlled failure test.
resource "aws_vpc_security_group_ingress_rule" "app_b_icmp_from_app_a" {
  count = var.app_b_icmp_enabled ? 1 : 0

  security_group_id = aws_security_group.app_b.id
  description       = "ICMP echo request from App-A"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
  cidr_ipv4         = "${local.app_a_ip}/32"
}

# --- egress: allow all (default behaviour, made explicit) ------------------
resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_a_all" {
  security_group_id = aws_security_group.app_a.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_b_all" {
  security_group_id = aws_security_group.app_b.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
