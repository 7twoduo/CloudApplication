terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket  = "deathless-godx"
    key     = "environments/production/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    #  use_lockfile = true # Enables native S3 state locking (removes DynamoDB dependency)
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.8"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
# --------------------------------------------------
# 1. VPC
# --------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.200.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# --------------------------------------------------
# 2. Public Subnets
# --------------------------------------------------

resource "aws_subnet" "public_1" {

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.200.1.0/24"
  availability_zone       = local.availability_zones[0]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-1"
    Tier = "Public"
  })
}
resource "aws_subnet" "public_2" {

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.200.2.0/24"
  availability_zone       = local.availability_zones[1]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-2"
    Tier = "Public"
  })
}
# --------------------------------------------------
# 3. Private Subnets
# --------------------------------------------------

resource "aws_subnet" "private_1" {

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.200.11.0/24"
  availability_zone       = local.availability_zones[0]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-1"
    Tier = "Private"
  })
}

resource "aws_subnet" "private_2" {

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.200.12.0/24"
  availability_zone       = local.availability_zones[1]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-2"
    Tier = "Private"
  })
}

# --------------------------------------------------
# 4. Internet Gateway
# --------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# --------------------------------------------------
# 5. Public Route Table
# --------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

# Send public subnet internet-bound traffic to the IGW
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Associate both public subnets with the public route table
resource "aws_route_table_association" "public" {

  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {

  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# --------------------------------------------------
# 6. Elastic IP for NAT Gateway
# --------------------------------------------------

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-eip"
  })
}

# --------------------------------------------------
# 7. NAT Gateway
# --------------------------------------------------

# NAT must be placed in a PUBLIC subnet.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  # Ensure the IGW and public route exist first.
  depends_on = [
    aws_internet_gateway.main,
    aws_route.public_internet
  ]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat"
  })
}

# --------------------------------------------------
# 8. Private Route Table
# --------------------------------------------------

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-rt"
  })
}

# Send private subnet internet-bound traffic to the NAT
resource "aws_route" "private_internet" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

# Associate both private subnets with the private route table
resource "aws_route_table_association" "private" {

  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}




###################################  DYNAMODB TABLES  ###################################



# Customer-managed KMS key for DynamoDB encryption.
resource "aws_kms_key" "tasks" {
  description             = "Encrypt CloudApplication DynamoDB tasks"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = {
    Name      = "cloudapplication-dynamodb-key"
    Project   = "CloudApplication"
    ManagedBy = "Terraform"
  }
}

# Readable alias for the KMS key.
resource "aws_kms_alias" "tasks" {
  name          = "alias/cloudapplication-dynamodb"
  target_key_id = aws_kms_key.tasks.key_id
}

# DynamoDB table for the Task API.
resource "aws_dynamodb_table" "tasks" {
  name         = "cloudapplication-tasks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  # Encrypt the table using our customer-managed KMS key.
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.tasks.arn
  }

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name      = "cloudapplication-tasks"
    Project   = "CloudApplication"
    ManagedBy = "Terraform"
  }
}






# AWS-managed IP prefix list for DynamoDB in this region.
data "aws_prefix_list" "dynamodb" {
  name = "com.amazonaws.${var.aws_region}.dynamodb"
}

# Routes private-subnet DynamoDB traffic through AWS's network,
# instead of sending it through the NAT Gateway.
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private.id
  ]

  tags = {
    Name      = "${var.project_name}-dynamodb-endpoint"
    Project   = "CloudApplication"
    ManagedBy = "Terraform"
  }
}