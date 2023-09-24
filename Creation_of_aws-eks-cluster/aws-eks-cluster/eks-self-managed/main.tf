locals {
  cluster_name = var.clustername
}

module "eks"{
  source = "./modules/eks"
  cluster_name = var.clustername
  cluster_version = var.version_eks
  subnets = module.vpc.public_subnets
  enable_irsa = true                 
  vpc_id = module.vpc.vpc_id


  worker_groups_launch_template = [
    {
      name                    = "worker-group-spot"
      override_instance_types = var.spot_instance_types
      spot_allocation_strategy = "lowest-price"
      asg_max_size            = var.spot_max_size      #overwrite the value from local.tf of eks module
      asg_desired_capacity    = var.spot_desired_size  #overwrite the value from local.tf of eks module
      kubelet_extra_args      = "--node-labels=node.kubernetes.io/lifecycle=spot"
    },
  ]
  worker_groups = [
    {
      name                          = "worker-group-on-demand"
      instance_type                 = var.ondemand_instance_type
      additional_userdata           = "echo foo bar"
      asg_desired_capacity          = var.ondemand_desired_size
      kubelet_extra_args            = "--node-labels=node.kubernetes.io/lifecycle=ondemand"
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    }
  ]
}

#will gonna hold the cluster ID
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id              
}
#for aws eks is cluster auth , which will hold the cluster ID also
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}
