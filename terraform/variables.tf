variable "region" {
  description = "AWS Region for every resource (workbook example: Mumbai / ap-south-1)."
  type        = string
  default     = "ap-south-1"
}

variable "student_name" {
  description = "Your name. Applied as the Student tag on every resource."
  type        = string
}

variable "my_ip_cidr" {
  description = "Your current public IPv4 as a /32, for example 203.0.113.25/32. Only this address may SSH to the bastion."
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/32$", var.my_ip_cidr)) && !startswith(var.my_ip_cidr, "0.0.0.0")
    error_message = "my_ip_cidr must be one IPv4 address ending in /32 (never 0.0.0.0/0). Run scripts/get-my-ip.sh to find it."
  }
}

variable "key_name" {
  description = "Name of the EC2 key pair created by scripts/create-key-pair.sh (the .pem stays on your laptop)."
  type        = string
  default     = "ewb-lab"
}

variable "instance_type" {
  description = "Small x86 instance type approved by your instructor."
  type        = string
  default     = "t3.micro"
}

variable "availability_zone" {
  description = "Availability Zone for all subnets. Leave null to use the first available AZ in the Region."
  type        = string
  default     = null
}

variable "ami_id" {
  description = "Optional Amazon Linux 2023 x86_64 AMI ID. Leave null to look up the latest one automatically."
  type        = string
  default     = null
}

variable "enable_peering" {
  description = "Stage switch. false = build VPCs and instances only (baseline test). true = create the peering connection and the three peering routes."
  type        = bool
  default     = false
}

variable "app_b_icmp_enabled" {
  description = "Keep true. scripts/controlled-failure.sh sets it to false temporarily to remove the App-B ICMP Echo rule."
  type        = bool
  default     = true
}
