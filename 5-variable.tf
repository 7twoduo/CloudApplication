variable "aws_region" {
  description = "AWS region for the VPC"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for resources"
  type        = string
  default     = "legend-vpc"
}

# Get available Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = slice(
    data.aws_availability_zones.available.names,
    0,
    2
  )

  public_subnet_cidrs = [
    "10.200.1.0/24",
    "10.200.2.0/24"
  ]

  private_subnet_cidrs = [
    "10.200.11.0/24",
    "10.200.12.0/24"
  ]

  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}
