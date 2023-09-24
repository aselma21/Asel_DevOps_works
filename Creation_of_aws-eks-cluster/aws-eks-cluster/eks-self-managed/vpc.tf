
# for all AZ available in aws
data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "./modules/vpc"
  
  name                 = var.vpc_name
  cidr                 = var.cidr_vpc               
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = var.private_sub     
  public_subnets       = var.public_sub     
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = false   #in our case we do not need the NAT
  single_nat_gateway   = false

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}