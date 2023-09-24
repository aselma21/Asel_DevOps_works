provider "aws" {
  region  = var.aws_region 
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.39.0"
    }
  }

  required_version = ">= 1.3.7"
}

data "aws_autoscaling_group" "eks-centos-node-groupe-4ec29b4d-24ce-30b3-c1dc-5e3b8b17e463" {
  name = "eks-centos-node-groupe-4ec29b4d-24ce-30b3-c1dc-5e3b8b17e463"
}

data "aws_launch_template" "eks-4ec29b4d-24ce-30b3-c1dc-5e3b8b17e463" {
  name = "eks-4ec29b4d-24ce-30b3-c1dc-5e3b8b17e463"
}
