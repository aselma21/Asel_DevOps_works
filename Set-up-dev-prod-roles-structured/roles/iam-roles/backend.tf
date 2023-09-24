terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

terraform {
  required_version = ">= 1.3.4" 
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# use terraform workspaces for keeping separate tfstate files
terraform {
  backend "s3" {
    bucket = "terraform-backend-statefile-centoes"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
  }
}
