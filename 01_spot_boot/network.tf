# --------------------------------
# VPC
# --------------------------------
resource "aws_vpc" "vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "${var.project}-${var.env}-vpc"
    Project     = var.project
    Environment = var.env
  }
}

# --------------------------------
# Subnets
# --------------------------------
resource "aws_subnet" "public_subnet_1c" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.1.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.project}-${var.env}-public-subnet-1c"
    Project     = var.project
    Environment = var.env
    Type        = "public"
  }
}
resource "aws_subnet" "public_subnet_1d" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.2.0/24"
  availability_zone       = "ap-northeast-1d"
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.project}-${var.env}-public-subnet-1d"
    Project     = var.project
    Environment = var.env
    Type        = "public"
  }
}

resource "aws_subnet" "private_subnet_1c" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.3.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false
  tags = {
    Name        = "${var.project}-${var.env}-private-subnet-1c"
    Project     = var.project
    Environment = var.env
    Type        = "private"
  }
}

resource "aws_subnet" "private_subnet_1d" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.4.0/24"
  availability_zone       = "ap-northeast-1d"
  map_public_ip_on_launch = false
  tags = {
    Name        = "${var.project}-${var.env}-private-subnet-1d"
    Project     = var.project
    Environment = var.env
    Type        = "private"
  }
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

resource "aws_route_table_association" "public_rt_1c" {
  subnet_id      = aws_subnet.public_subnet_1c.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_1d" {
  subnet_id      = aws_subnet.public_subnet_1d.id
  route_table_id = aws_route_table.public_rt.id
}



resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${var.project}-${var.env}-private-route-table"
    Project     = var.project
    Environment = var.env
  }
}

resource "aws_route_table_association" "private_rt_1c" {
  subnet_id      = aws_subnet.private_subnet_1c.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_rt_1d" {
  subnet_id      = aws_subnet.private_subnet_1d.id
  route_table_id = aws_route_table.private_rt.id
}

# --------------------------------
# Internet Gateway
# --------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${var.project}-${var.env}-igw"
    Project     = var.project
    Environment = var.env
  }
}

resource "aws_route" "public_rt_igw" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}





