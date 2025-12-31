# --------------------------------
# Terraform configuration
# --------------------------------

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
  }
}

# --------------------------------
# Provider
# --------------------------------
provider "aws" {
  profile = "default"
  region  = "ap-northeast-1"
}

provider "aws" {
  alias  = "apne2"
  region = "ap-northeast-2"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "usw2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "euc1"
  region = "eu-central-1"
}

# --------------------------------
# Variables
# --------------------------------
variable "project" {
  type = string
}

variable "env" {
  type = string
}

# --------------------------------
# Modules
# --------------------------------
# ----------------------------
# 東京 (ap-northeast-1)
# ----------------------------
module "network_tokyo" {
  source = "../../modules/network"
  providers = {
    aws = aws
  }
  cidr_vpc     = "10.1.0.0/16"
  cidr_public1 = "10.1.1.0/24"
  cidr_public2 = "10.1.2.0/24"
  az_public1   = "ap-northeast-1c"
  az_public2   = "ap-northeast-1d"
  env          = var.env
  project      = var.project
}

# ----------------------------
# 韓国 (ap-northeast-2)
# ----------------------------
module "network_korea" {
  source = "../../modules/network"
  providers = {
    aws = aws.apne2
  }
  cidr_vpc     = "10.2.0.0/16"
  cidr_public1 = "10.2.1.0/24"
  cidr_public2 = "10.2.2.0/24"
  az_public1   = "ap-northeast-2a"
  az_public2   = "ap-northeast-2b"
  env          = var.env
  project      = var.project
}

# ----------------------------
# バージニア北部 (us-east-1)
# ----------------------------
module "network_virginia" {
  source = "../../modules/network"
  providers = {
    aws = aws.use1
  }
  cidr_vpc     = "10.3.0.0/16"
  cidr_public1 = "10.3.1.0/24"
  cidr_public2 = "10.3.2.0/24"
  az_public1   = "us-east-1b"
  az_public2   = "us-east-1c"
  env          = var.env
  project      = var.project
}

# ----------------------------
# オレゴン (us-west-2)
# ----------------------------
module "network_oregon" {
  source = "../../modules/network"
  providers = {
    aws = aws.usw2
  }
  cidr_vpc     = "10.4.0.0/16"
  cidr_public1 = "10.4.1.0/24"
  cidr_public2 = "10.4.2.0/24"
  az_public1   = "us-west-2a"
  az_public2   = "us-west-2b"
  env          = var.env
  project      = var.project
}

# ----------------------------
# フランクフルト (eu-central-1)
# ----------------------------
module "network_frankfurt" {
  source = "../../modules/network"
  providers = {
    aws = aws.euc1
  }
  cidr_vpc     = "10.5.0.0/16"
  cidr_public1 = "10.5.1.0/24"
  cidr_public2 = "10.5.2.0/24"
  az_public1   = "eu-central-1a"
  az_public2   = "eu-central-1b"
  env          = var.env
  project      = var.project
}

# ----------------------------
# security_group
# ----------------------------
module "security_tokyo" {
  source = "../../modules/security"
  providers = {
    aws = aws
  }
  VPCID   = module.network_tokyo.VPCID
  env     = var.env
  project = var.project
}


module "security_korea" {
  source = "../../modules/security"
  providers = {
    aws = aws.apne2
  }
  VPCID   = module.network_korea.VPCID
  env     = var.env
  project = var.project
}

module "security_virginia" {
  source = "../../modules/security"
  providers = {
    aws = aws.use1
  }
  VPCID   = module.network_virginia.VPCID
  env     = var.env
  project = var.project
}

module "security_oregon" {
  source = "../../modules/security"
  providers = {
    aws = aws.usw2
  }
  VPCID   = module.network_oregon.VPCID
  env     = var.env
  project = var.project
}

module "security_frankfurt" {
  source = "../../modules/security"
  providers = {
    aws = aws.euc1
  }
  VPCID   = module.network_frankfurt.VPCID
  env     = var.env
  project = var.project
}

# ----------------------------
# key
# ----------------------------
resource "aws_key_pair" "tokyo" {
  provider   = aws
  key_name   = "multi-region-spot-dev-keypair"
  public_key = file("../../key/spot-db-test.pub")
}

resource "aws_key_pair" "korea" {
  provider   = aws.apne2
  key_name   = "multi-region-spot-dev-keypair"
  public_key = file("../../key/spot-db-test.pub")
}

resource "aws_key_pair" "virginia" {
  provider   = aws.use1
  key_name   = "multi-region-spot-dev-keypair"
  public_key = file("../../key/spot-db-test.pub")
}

resource "aws_key_pair" "oregon" {
  provider   = aws.usw2
  key_name   = "multi-region-spot-dev-keypair"
  public_key = file("../../key/spot-db-test.pub")
}

resource "aws_key_pair" "frankfurt" {
  provider   = aws.euc1
  key_name   = "multi-region-spot-dev-keypair"
  public_key = file("../../key/spot-db-test.pub")
}


module "lambda_source_s3" {
  source          = "../../modules/s3_lambda_source"
  bucket_name     = "${var.env}-${var.project}-lambda-source"
  object_key      = "lambda_source/boot_spot.zip"
  source_zip_path = "./../../lambda_source/boot_spot.zip"
  bucket_data_name = "${var.env}-${var.project}-data-source"
  data_object_key      = "data_source/employee_data.csv"
  source_data_path = "./../../data_source/employee_data.csv"

  env          = var.env
  project      = var.project
}

locals {
  network_map = {
    ap-northeast-1 = {
      vpc_id     = module.network_tokyo.VPCID
      subnet_id  = module.network_tokyo.public1ID
    }
    ap-northeast-2 = {
      vpc_id     = module.network_korea.VPCID
      subnet_id  = module.network_korea.public1ID
    }
    us-east-1 = {
      vpc_id     = module.network_virginia.VPCID
      subnet_id  = module.network_virginia.public1ID
    }
    us-west-2 = {
      vpc_id     = module.network_oregon.VPCID
      subnet_id  = module.network_oregon.public1ID
    }
    eu-central-1 = {
      vpc_id     = module.network_frankfurt.VPCID
      subnet_id  = module.network_frankfurt.public1ID
    }
  }
}

locals {
  sg_map = {
    ap-northeast-1 = module.security_tokyo.sg_id
    ap-northeast-2 = module.security_korea.sg_id
    us-east-1      = module.security_virginia.sg_id
    us-west-2      = module.security_oregon.sg_id
    eu-central-1   = module.security_frankfurt.sg_id
  }
}

locals {
  key_map = {
    ap-northeast-1 = aws_key_pair.tokyo.key_name
    ap-northeast-2 = aws_key_pair.korea.key_name
    us-east-1      = aws_key_pair.virginia.key_name
    us-west-2      = aws_key_pair.oregon.key_name
    eu-central-1   = aws_key_pair.frankfurt.key_name
  }
}

locals {
  s3_data_path = "s3://${module.lambda_source_s3.bucket_data_name}/${module.lambda_source_s3.data_object_key}"
}

module "event_bridge" {
  source = "../../modules/event_bridge"
  env = var.env
  project = var.project
  s3_bucket = module.lambda_source_s3.bucket_name
  s3_key = module.lambda_source_s3.object_key
  s3_data_path = local.s3_data_path
  VPCID     = module.network_tokyo.VPCID
  public1ID = module.network_tokyo.public1ID 
  network_map = local.network_map
  sg_map = local.sg_map
  key_map = local.key_map
}