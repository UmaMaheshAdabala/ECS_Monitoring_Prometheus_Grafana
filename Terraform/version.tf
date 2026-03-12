terraform {
  required_providers {
    aws = {
      version = ">=5.0.0"
      source  = "hashicorp/aws"
    }
  }
  required_version = ">=1.12.0"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}
