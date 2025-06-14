# --------------------------------
# Terraform configuration
# --------------------------------

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
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