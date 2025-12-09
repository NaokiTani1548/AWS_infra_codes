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
module "network" {
  source = "../../modules/network"
  cidr_vpc     = "192.168.0.0/16"
  cidr_public1 = "192.168.1.0/24"
  cidr_public2 = "192.168.2.0/24"
  az_public1   = "ap-northeast-1c"
  az_public2   = "ap-northeast-1d"
  env          = var.env
  project      = var.project
}

module "lambda_source_s3" {
  source          = "../../modules/s3_lambda_source"
  bucket_name     = "${var.env}-${var.project}-lambda-source"                 # 適宜変更
  object_key      = "lambda_source/boot_spot.zip"
  source_zip_path = "./../../lambda_source/boot_spot.zip"
  env          = var.env
  project      = var.project
}

module "event_bridge" {
  source = "../../modules/event_bridge"
  env = var.env
  project = var.project
  s3_bucket = module.lambda_source_s3.bucket_name
  s3_key = module.lambda_source_s3.object_key
  VPCID     = module.network.VPCID
  public1ID = module.network.public1ID 
}