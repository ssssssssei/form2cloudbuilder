provider "aws" {
  region = "ap-northeast-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.53.0"
    }
  }
  required_version = ">= 1.6.6"

  backend "s3" {
    bucket  = "(例)bucket"
    region  = "(例)ap-northeast-1"
    key     = "(例)github/dev/terraform.tfstate"
    encrypt = true
  }
}