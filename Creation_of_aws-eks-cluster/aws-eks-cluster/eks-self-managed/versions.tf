

terraform {
  required_version = ">= 0.14"   #terraform version
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.20.0"
    }
      local = {
      source  = "hashicorp/local"
      version = "2.1.0"
    }
  }
}