terraform {
  required_version = ">= 1.0.0" # Or your desired Terraform version
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Or your desired AWS provider version
    }
  }
}