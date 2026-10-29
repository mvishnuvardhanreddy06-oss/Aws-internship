data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  az = coalesce(var.availability_zone, data.aws_availability_zones.available.names[0])

  # Address plan (workbook p.4)
  vpc_a_cidr     = "10.10.0.0/16"
  public_a_cidr  = "10.10.1.0/24"
  private_a_cidr = "10.10.2.0/24"
  vpc_b_cidr     = "10.20.0.0/16"
  private_b_cidr = "10.20.1.0/24"

  bastion_ip = "10.10.1.10"
  app_a_ip   = "10.10.2.10"
  app_b_ip   = "10.20.1.10"

  # Used for EBS volume tags (default_tags do not reach volumes created with an instance).
  common_tags = {
    Project = "EWB-VPC-Peering"
    Student = var.student_name
  }
}
