data "aws_ami" "al2023" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  ami_id = coalesce(var.ami_id, one(data.aws_ami.al2023[*].id))
}

# Public bastion in VPC A (the only host with a public IPv4 address)
resource "aws_instance" "bastion" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.a_public.id
  private_ip                  = local.bastion_ip
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  volume_tags = merge(local.common_tags, { Name = "ewb-bastion-root" })
  tags        = { Name = "ewb-bastion" }

  # Keep the same AMI between stage 1 and stage 2 even if a newer one is released.
  lifecycle {
    ignore_changes = [ami]
  }

  depends_on = [aws_route.a_public_internet]
}

# Private App-A in VPC A (no public IPv4)
resource "aws_instance" "app_a" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.a_private.id
  private_ip                  = local.app_a_ip
  vpc_security_group_ids      = [aws_security_group.app_a.id]
  associate_public_ip_address = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  volume_tags = merge(local.common_tags, { Name = "ewb-app-a-root" })
  tags        = { Name = "ewb-app-a" }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Private App-B in VPC B (no public IPv4)
resource "aws_instance" "app_b" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.b_private.id
  private_ip                  = local.app_b_ip
  vpc_security_group_ids      = [aws_security_group.app_b.id]
  associate_public_ip_address = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  volume_tags = merge(local.common_tags, { Name = "ewb-app-b-root" })
  tags        = { Name = "ewb-app-b" }

  lifecycle {
    ignore_changes = [ami]
  }
}
