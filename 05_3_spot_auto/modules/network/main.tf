# --------------------------------
# VPC
# --------------------------------
resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name        = "${var.project}-${var.env}-vpc"
    Project     = var.project
    Environment = var.env
  }
}

# --------------------------------
# Subnets
# --------------------------------
resource "aws_subnet" "public_subnet_1" {
  availability_zone       = var.az_public1
  cidr_block              = var.cidr_public1
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.project}-${var.env}-public-subnet-1"
    Project     = var.project
    Environment = var.env
    Type        = "public"
  }
}

resource "aws_subnet" "public_subnet_2" {
  availability_zone       = var.az_public2
  cidr_block              = var.cidr_public2
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.project}-${var.env}-public-subnet-2"
    Project     = var.project
    Environment = var.env
    Type        = "public"
  }
}

# --------------------------------
# Internet Gateway
# --------------------------------
resource "aws_internet_gateway" "igw" {
  tags = {
    Name        = "${var.project}-${var.env}-igw"
    Project     = var.project
    Environment = var.env
  }
  vpc_id = aws_vpc.vpc.id
}

# --------------------------------
# Route Tables
# --------------------------------

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${var.project}-${var.env}-public-route-table"
    Project     = var.project
    Environment = var.env
  }
}

resource "aws_route" "public-route" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  route_table_id         = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}



