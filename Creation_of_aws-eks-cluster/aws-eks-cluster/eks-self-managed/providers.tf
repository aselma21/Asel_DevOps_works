provider "aws" {
  region  = "us-east-1"
 
}

variable "region" {
  default     = "us-east-1"
  description = "AWS region"
}

terraform {
  backend "s3" {
    bucket = "22j-project-centos"
    key = "terraform.tfstate"
    region = "us-east-1"
  }
}

# Kubernetes provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  config_path            = "~/.kube/config"


  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.aws_eks_cluster.cluster.name
    ]
  }
}


