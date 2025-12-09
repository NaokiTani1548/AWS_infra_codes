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

module "ec2_server" {
  source = "../../modules/ec2_server"
  VPCID     = module.network.VPCID
  public1ID = module.network.public1ID 
  env       = var.env
  project   = var.project
}
