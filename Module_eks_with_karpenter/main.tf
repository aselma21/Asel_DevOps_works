provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name            = "ex-${replace(basename(path.cwd), "_", "-")}"
  cluster_version = "1.26"
  region          = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  current_directory = basename(dirname(path.cwd))

  tags = {
    Example    = local.name
    GithubRepo = "terraform-aws-eks"
    GithubOrg  = "terraform-aws-modules"
  }
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source = "../.."

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = false
  

  # IPV6
  # cluster_ip_family = "ipv6"
  # IPV4
  cluster_ip_family = "ipv4"

  # We are using the IRSA created below for permissions
  # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
  # and then turn this off after the cluster/node group is created. Without this initial policy,
  # the VPC CNI fails to assign IPs and nodes cannot join the cluster
  # See https://github.com/aws/containers-roadmap/issues/1666 for more context
  # TODO - remove this policy once AWS releases a managed version similar to AmazonEKS_CNI_Policy (IPv4)
  
  # create_cni_ipv6_iam_policy = true

  cluster_addons = {
    coredns = {
      most_recent = true

    }
    aws-ebs-csi-driver = {
      #service_account_role_arn  = aws_iam_role.ebs_csi_role.arn
      service_account_role_arn = aws_iam_role.ebs_csi_controller.arn
      resolve_conflicts        = "OVERWRITE"
      addon_version     = "v1.18.0-eksbuild.1"
      tags = {
      "eks_addon" = "ebs-csi"
      "terraform" = "true"
  }
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  manage_aws_auth_configmap = true
  aws_auth_roles = [
  # We need to add in the Karpenter node IAM role for nodes launched by Karpenter
  {
    rolearn  = module.karpenter.role_arn
    username = "system:node:{{EC2PrivateDNSName}}"
    groups = [
      "system:bootstrappers",
      "system:nodes",
    ]
  },
  ]

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = [ "m4.4xlarge", "m6i.2xlarge", "m5.4xlarge","m5.4xlarge", "m5n.2xlarge", "m5zn.2xlarge", "m5zn.12xlarge"]
    #instance_types = ["t3.2xlarge", "t2.2xlarge", "t3a.2xlarge", "m4.4xlarge", "m6i.2xlarge", "m5.4xlarge","m5.4xlarge", "m5n.2xlarge", "m5zn.2xlarge", "m5zn.12xlarge"]

    # We are using the IRSA created below for permissions
    # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
    # and then turn this off after the cluster/node group is created. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the cluster
    # See https://github.com/aws/containers-roadmap/issues/1666 for more context
    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
    # Default node group - as provided by AWS EKS
    default_node_group = {
      # By default, the module creates a launch template to ensure tags are propagated to instances, etc.,
      # so we need to disable it to use the default template provided by the AWS EKS managed node group service
      use_custom_launch_template = false

      disk_size = 50

      # Remote access cannot be specified with a launch template
      remote_access = {
        ec2_ssh_key               = module.key_pair.key_pair_name
        source_security_group_ids = [aws_security_group.remote_access.id]
      }
      update_config = {
        max_unavailable_percentage = 25
      }

      min_size     = 4
      max_size     = 10
      desired_size = 4
      # instance_types          = ["t3.large", "t2.large", "t3a.large", "m5.large", "m4.large"]
      instance_market_options = {
        market_type = "on-demand"
      }
      capacity_type = "ON_DEMAND"  
      iam_role_additional_policies = {
        additional = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      } 
      // Add policy required for SSM
      # iam_role_additional_policies = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"]   
    }

    # Default node group - as provided by AWS EKS using Bottlerocket
/*     bottlerocket_default = {
      # By default, the module creates a launch template to ensure tags are propagated to instances, etc.,
      # so we need to disable it to use the default template provided by the AWS EKS managed node group service
      use_custom_launch_template = false

      ami_type = "BOTTLEROCKET_x86_64"
      platform = "bottlerocket"
    }

    # Adds to the AWS provided user data
    bottlerocket_add = {
      ami_type = "BOTTLEROCKET_x86_64"
      platform = "bottlerocket"

      # This will get added to what AWS provides
      bootstrap_extra_args = <<-EOT
        # extra args added
        [settings.kernel]
        lockdown = "integrity"
      EOT
    } */

    # Custom AMI, using module provided bootstrap data
/*     bottlerocket_custom = {
      # Current bottlerocket AMI
      ami_id   = data.aws_ami.eks_default_bottlerocket.image_id
      platform = "bottlerocket"

      # Use module user data template to bootstrap
      enable_bootstrap_user_data = true
      # This will get added to the template
      bootstrap_extra_args = <<-EOT
        # The admin host container provides SSH access and runs with "superpowers".
        # It is disabled by default, but can be disabled explicitly.
        [settings.host-containers.admin]
        enabled = false

        # The control host container provides out-of-band access via SSM.
        # It is enabled by default, and can be disabled if you do not expect to use SSM.
        # This could leave you with no way to access the API and change settings on an existing node!
        [settings.host-containers.control]
        enabled = true

        # extra args added
        [settings.kernel]
        lockdown = "integrity"

        [settings.kubernetes.node-labels]
        label1 = "foo"
        label2 = "bar"

        [settings.kubernetes.node-taints]
        dedicated = "experimental:PreferNoSchedule"
        special = "true:NoSchedule"
      EOT
    } */

    # Use a custom AMI
/*     custom_ami = {
      ami_type = "AL2_ARM_64"
      # Current default AMI used by managed node groups - pseudo "custom"
      ami_id = data.aws_ami.eks_default_arm.image_id

      # This will ensure the bootstrap user data is used to join the node
      # By default, EKS managed node groups will not append bootstrap script;
      # this adds it back in using the default template provided by the module
      # Note: this assumes the AMI provided is an EKS optimized AMI derivative
      enable_bootstrap_user_data = true

      instance_types = ["t4g.medium"]
    } */

    # Complete
    # complete = {
    #   name            = "complete-eks-mng"
    #   use_name_prefix = true

    #   subnet_ids = module.vpc.private_subnets

    #   min_size     = 0
    #   max_size     = 7
    #   desired_size = 0

    #   ami_id                     = data.aws_ami.eks_default.image_id
    #   enable_bootstrap_user_data = true

    #   pre_bootstrap_user_data = <<-EOT
    #     export FOO=bar
    #   EOT

    #   post_bootstrap_user_data = <<-EOT
    #     echo "you are free little kubelet!"
    #   EOT

    #   capacity_type        = "SPOT"
    #   force_update_version = true
    #   instance_types       = ["t3.xlarge"]
    #   labels = {
    #     GithubRepo = "terraform-aws-eks"
    #     GithubOrg  = "terraform-aws-modules"
    #   }

    #   taints = [
    #     {
    #       key    = "dedicated"
    #       value  = "gpuGroup"
    #       effect = "NO_SCHEDULE"
    #     }
    #   ]

    #   update_config = {
    #     max_unavailable_percentage = 33 # or set `max_unavailable`
    #   }

    #   description = "EKS managed node group example launch template"

    #   ebs_optimized           = true
    #   disable_api_termination = false
    #   enable_monitoring       = true

    #   block_device_mappings = {
    #     xvda = {
    #       device_name = "/dev/xvda"
    #       ebs = {
    #         volume_size           = 75
    #         volume_type           = "gp3"
    #         iops                  = 3000
    #         throughput            = 150
    #         encrypted             = true
    #         kms_key_id            = module.ebs_kms_key.key_arn
    #         delete_on_termination = true
    #       }
    #     }
    #   }

    #   metadata_options = {
    #     http_endpoint               = "enabled"
    #     http_tokens                 = "required"
    #     http_put_response_hop_limit = 2
    #     instance_metadata_tags      = "disabled"
    #   }

    #   create_iam_role          = true
    #   iam_role_name            = "eks-managed-node-group-complete-example"
    #   iam_role_use_name_prefix = false
    #   iam_role_description     = "EKS managed node group complete example role"
    #   iam_role_tags = {
    #     Purpose = "Protector of the kubelet"
    #   }
    #   iam_role_additional_policies = {
    #     AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    #     additional                         = aws_iam_policy.node_additional.arn
    #   }

    #   schedules = {
    #     scale-up = {
    #       min_size     = 1
    #       max_size     = "-1" # Retains current max size
    #       desired_size = 1
    #       start_time   = "2024-03-05T00:00:00Z"
    #       end_time     = "2025-03-05T00:00:00Z"
    #       timezone     = "Etc/GMT+0"
    #       recurrence   = "0 0 * * *"
    #     },
    #     scale-down = {
    #       min_size     = 0
    #       max_size     = "-1" # Retains current max size
    #       desired_size = 0
    #       start_time   = "2024-03-05T12:00:00Z"
    #       end_time     = "2025-03-05T12:00:00Z"
    #       timezone     = "Etc/GMT+0"
    #       recurrence   = "0 12 * * *"
    #     }
    #   }

    #   tags = {
    #     ExtraTag = "EKS managed node group complete example"
    #   }
    # }
}


  # tags = local.tags


}


################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  # enable_ipv6                     = true
  # assign_ipv6_address_on_creation = true
  create_egress_only_igw          = true

  # public_subnet_ipv6_prefixes  = [0, 1, 2]
  # private_subnet_ipv6_prefixes = [3, 4, 5]
  # intra_subnet_ipv6_prefixes   = [6, 7, 8]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "kubernetes.io/cluster/${local.name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
     "kubernetes.io/cluster/${local.name}" = "shared"
     "karpenter.sh/discovery" = local.name
  }

  tags = local.tags
}

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  # vpc_cni_enable_ipv6   = true
  vpc_cni_enable_ipv4   = true  

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}

module "ebs_kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 1.5"

  description = "Customer managed key to encrypt EKS managed node group volumes"

  # Policy
  key_administrators = [
    data.aws_caller_identity.current.arn
  ]

  key_service_roles_for_autoscaling = [
    # required for the ASG to manage encrypted volumes for nodes
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
    # required for the cluster / persistentvolume-controller to create encrypted PVCs
    module.eks.cluster_iam_role_arn,
  ]

  # Aliases
  aliases = ["eks/${local.name}/ebs"]

  tags = local.tags
}

module "key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "~> 2.0"

  key_name_prefix    = local.name
  create_private_key = true

  tags = local.tags
}

resource "aws_security_group" "remote_access" {
  name_prefix = "${local.name}-remote-access"
  description = "Allow remote SSH access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-remote" })
}

resource "aws_iam_policy" "node_additional" {
  name        = "${local.name}-additional"
  description = "Example usage of node additional policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = local.tags
}

data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.cluster_version}-v*"]
  }
}

data "aws_ami" "eks_default_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-arm64-node-${local.cluster_version}-v*"]
  }
}

data "aws_ami" "eks_default_bottlerocket" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["bottlerocket-aws-k8s-${local.cluster_version}-x86_64-*"]
  }
}

################################################################################
# Tags for the ASG to support cluster-autoscaler scale up from 0
################################################################################

/* locals {

  # We need to lookup K8s taint effect from the AWS API value
  taint_effects = {
    NO_SCHEDULE        = "NoSchedule"
    NO_EXECUTE         = "NoExecute"
    PREFER_NO_SCHEDULE = "PreferNoSchedule"
  }

  cluster_autoscaler_label_tags = merge([
    for name, group in module.eks.eks_managed_node_groups : {
      for label_name, label_value in coalesce(group.node_group_labels, {}) : "${name}|label|${label_name}" => {
        autoscaling_group = group.node_group_autoscaling_group_names[0],
        key               = "k8s.io/cluster-autoscaler/node-template/label/${label_name}",
        value             = label_value,
      }
    }
  ]...)

  cluster_autoscaler_taint_tags = merge([
    for name, group in module.eks.eks_managed_node_groups : {
      for taint in coalesce(group.node_group_taints, []) : "${name}|taint|${taint.key}" => {
        autoscaling_group = group.node_group_autoscaling_group_names[0],
        key               = "k8s.io/cluster-autoscaler/node-template/taint/${taint.key}"
        value             = "${taint.value}:${local.taint_effects[taint.effect]}"
      }
    }
  ]...)

  cluster_autoscaler_asg_tags = merge(local.cluster_autoscaler_label_tags, local.cluster_autoscaler_taint_tags)
}

resource "aws_autoscaling_group_tag" "cluster_autoscaler_label_tags" {
  for_each = local.cluster_autoscaler_asg_tags

  autoscaling_group_name = each.value.autoscaling_group

  tag {
    key   = each.value.key
    value = each.value.value

    propagate_at_launch = false
  }
} */


########## EBS CSI ADDON 

# resource "aws_eks_addon" "ebs_csi" {
#   cluster_name             = module.eks.cluster_name
#   addon_name               = "ebs-csi-driver"
#   service_account_role_arn = aws_iam_role.ebs_csi_controller.arn
#   resolve_conflicts        = "OVERWRITE"
#   addon_version     = "v1.17.0-eksbuild.1"
# }
resource "aws_iam_role" "ebs_csi_controller" {
  name               = "${local.name}-ebs-csi-controller"
assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${module.eks.oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${module.eks.oidc_provider}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "ebs_csi_controller_attachment" {
  role       = aws_iam_role.ebs_csi_controller.name
  policy_arn = aws_iam_policy.ebs_csi_controller.arn
}

  
resource "aws_iam_policy" "ebs_csi_controller" {
  name         = var.ebs_csi_controller_policy_name
  # policy       = file("../ebs_csi_controller_iam_policy.json")
  # policy = file("/Users/dheerajkoppisetti/GitHub/terraform-aws-eks/examples/eks_managed_node_group_c/ebs_csi_controller_iam_policy.json")
  policy = file("${path.cwd}/ebs_csi_controller_iam_policy.json")
}
variable "ebs_csi_controller_policy_name" {
  type    = string
  default = "wmh-ebs-csi-controller-policy"
}

################################################################################
# Load Balancer
################################################################################


module "lb_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = local.name
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  tags = local.tags
}

################################################################################
# Helm and Service account for LB
################################################################################
resource "time_sleep" "wait_3_minutes" {
  depends_on = [module.eks]

  create_duration = "3m"
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", local.name]
      command     = "aws"
    }
  }
}

resource "kubernetes_service_account" "service-account" {
  metadata {
    name = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
        "app.kubernetes.io/name"= "aws-load-balancer-controller"
        "app.kubernetes.io/component"= "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = module.lb_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}

################################################################################
# Helm Controller for Load Balancer
################################################################################

resource "helm_release" "lb" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [
    kubernetes_service_account.service-account
  ]

  set {
    name  = "region"
    value = local.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "clusterName"
    value = local.name
  }
  
} 


#####################################################

data "aws_ecrpublic_authorization_token" "token" {}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

resource "kubectl_manifest" "ssm-agent" {
  yaml_body = <<-YAML
    apiVersion: apps/v1
    kind: DaemonSet
    metadata:
      labels:
        k8s-app: ssm-installer
      name: ssm-installer
      namespace: kube-system
    spec:
      selector:
        matchLabels:
          k8s-app: ssm-installer
      template:
        metadata:
          labels:
            k8s-app: ssm-installer
        spec:
          containers:
          - name: sleeper
            image: busybox
            command: ['sh', '-c', 'echo I keep things running! && sleep 3600']
          initContainers:
          - image: amazonlinux
            imagePullPolicy: Always
            name: ssm
            command: ["/bin/bash"]
            args: ["-c","echo '* * * * * root yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm & rm -rf /etc/cron.d/ssmstart' > /etc/cron.d/ssmstart"]
            securityContext:
              allowPrivilegeEscalation: true
            volumeMounts:
            - mountPath: /etc/cron.d
              name: cronfile
            terminationMessagePath: /dev/termination-log
            terminationMessagePolicy: File
          volumes:
          - name: cronfile
            hostPath:
              path: /etc/cron.d
              type: Directory
          dnsPolicy: ClusterFirst
          restartPolicy: Always
          schedulerName: default-scheduler
          terminationGracePeriodSeconds: 30
          YAML
}


module "karpenter" {
  source = "../../modules/karpenter"

  cluster_name           = module.eks.cluster_name
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "v0.21.1"

  set {
    name  = "settings.aws.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter.instance_profile_name
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter.queue_name
  }
}



resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      requirements:
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: ["c", "m", "t"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["8", "16", "32"]
        - key: "karpenter.k8s.aws/instance-hypervisor"
          operator: In
          values: ["nitro"]
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: ${jsonencode(local.azs)}
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
        - key: "karpenter.sh/capacity-type" # If not included, the webhook for the AWS cloud provider will default to on-demand
          operator: In
          values: ["spot"]    #in case of demo and prod add here "spot" as well 
        - key: node.kubernetes.io/instance-type
          operator: NotIn
          values:
            - 'm6g.16xlarge'
            - 'm6gd.16xlarge'
            - 'r6g.16xlarge'
            - 'r6gd.16xlarge'
            - 'c6g.16xlarge'
      kubeletConfiguration:
        containerRuntime: containerd
        maxPods: 110
      limits:
        resources:
          cpu: 1000
      taints:
        - key: karpenter
          value: "true"
          effect: "NoSchedule"
      #labels:
      #    app-state: stateless
      consolidation:
        enabled: true
      providerRef:
        name: default
      ttlSecondsUntilExpired: 604800 # 7 Days = 7 * 24 * 60 * 60 Seconds
  YAML
  depends_on = [
    helm_release.karpenter
 ]
}



resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

# Example deployment using the [pause image](https://www.ianlewis.org/en/almighty-pause-container)
# and starts with zero replicas
resource "kubectl_manifest" "karpenter_example_deployment" {
  yaml_body = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: inflate
    spec:
      replicas: 0
      selector:
        matchLabels:
          app: inflate
      template:
        metadata:
          labels:
            app: inflate
        spec:
          terminationGracePeriodSeconds: 0
          containers:
            - name: inflate
              image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
          tolerations:
          - key: "karpenter"
            operator: "Exists"
            effect: "NoSchedule"
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}
