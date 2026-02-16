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
  region  = "ap-northeast-2"
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
# 東京 (ap-northeast-2)
# ----------------------------
module "network" {
  source = "../../modules/network"
  providers = {
    aws = aws
  }
  cidr_vpc     = "10.1.0.0/16"
  cidr_public1 = "10.1.1.0/24"
  cidr_public2 = "10.1.2.0/24"
  az_public1   = "ap-northeast-2a"
  az_public2   = "ap-northeast-2b"
  env          = var.env
  project      = var.project
}

# ----------------------------
# security_group
# ----------------------------
module "security" {
  source = "../../modules/security"
  providers = {
    aws = aws
  }
  VPCID   = module.network.VPCID
  env     = var.env
  project = var.project
}

# ----------------------------
# key
# ----------------------------
resource "aws_key_pair" "soul" {
  provider   = aws
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
    ap-northeast-2 = {
      vpc_id     = module.network.VPCID
      subnet_id  = module.network.public1ID
    }
  }
}

locals {
  sg_map = {
    ap-northeast-2 = module.security.sg_id
  }
}

locals {
  key_map = {
    ap-northeast-2 = aws_key_pair.soul.key_name
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
  VPCID     = module.network.VPCID
  public1ID = module.network.public1ID 
  network_map = local.network_map
  sg_map = local.sg_map
  key_map = local.key_map
}

module "event_bridge_soul" {
  source = "../../modules/event_bridge_all_region"
  providers = {
    aws = aws
  }
  eventbridge_local_role = module.event_bridge.eventbridge_local_role
  env = var.env
  project = var.project
}