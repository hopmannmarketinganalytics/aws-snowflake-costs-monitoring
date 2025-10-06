terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.20.0"
    }

  }
  backend "s3" {
    bucket                  = "terraform-s3-state-4637483747"
    key                     = "terraform.tfstate"
    region                  = "eu-central-1"
  }
}

provider "aws" {
  region = var.region
}
