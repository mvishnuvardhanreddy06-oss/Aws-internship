terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.31.0, < 7.0.0"
    }
  }
}

provider "aws" {
  region = var.region

  # Workbook p.4: tag every resource with Project and Student.
  default_tags {
    tags = {
      Project = "EWB-VPC-Peering"
      Student = var.student_name
    }
  }
}
