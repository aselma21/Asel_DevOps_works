
resource "aws_eks_cluster" "this" {
  count = var.create_eks ? 1 : 0

  name                      = var.cluster_name
  enabled_cluster_log_types = var.cluster_enabled_log_types
  role_arn                  = local.cluster_iam_role_arn
  version                   = var.cluster_version

  vpc_config {
    security_group_ids      = compact([local.cluster_security_group_id])   #the EKS cluster will be attached to this security group. If not given, a security group will be created with necessary ingress/egress to work with the workers"
    subnet_ids              = var.subnets
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }
 }

resource "aws_security_group" "cluster" {
  count = var.cluster_create_security_group ? 1 : 0

  name_prefix = var.cluster_name
  description = "EKS cluster security group."
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      "Name" = "${var.cluster_name}-eks_cluster_sg"
    },
  )
}

resource "aws_security_group_rule" "cluster_egress_internet" {
  count = var.cluster_create_security_group  ? 1 : 0

  description       = "Allow cluster egress access to the Internet."
  protocol          = "-1"
  security_group_id = local.cluster_security_group_id
  cidr_blocks       = var.cluster_egress_cidrs
  from_port         = 0
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "cluster_https_worker_ingress" {
  count = var.cluster_create_security_group && var.worker_create_security_group ? 1 : 0

  description              = "Allow pods to communicate with the EKS cluster API."
  protocol                 = "tcp"
  security_group_id        = local.cluster_security_group_id
  source_security_group_id = local.worker_security_group_id
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
  
}

resource "aws_security_group_rule" "cluster_private_access_cidrs_source" {
  for_each = var.cluster_endpoint_private_access && var.cluster_endpoint_private_access_cidrs != null ? toset(var.cluster_endpoint_private_access_cidrs) : []

  description = "Allow private K8S API ingress from custom CIDR source."
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = [each.value]

  security_group_id = aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "cluster_private_access_sg_source" {
  count = var.cluster_endpoint_private_access && var.cluster_endpoint_private_access_sg != null ? length(var.cluster_endpoint_private_access_sg) : 0

  description              = "Allow private K8S API ingress from custom Security Groups source."
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = var.cluster_endpoint_private_access_sg[count.index]

  security_group_id = aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id
}

resource "aws_iam_role" "cluster" {
  count = var.manage_cluster_iam_resources  ? 1 : 0

  name_prefix           = var.cluster_iam_role_name != "" ? null : var.cluster_name
  name                  = var.cluster_iam_role_name != "" ? var.cluster_iam_role_name : null
  assume_role_policy    = data.aws_iam_policy_document.cluster_assume_role_policy.json
  permissions_boundary  = var.permissions_boundary
  path                  = var.iam_path
  force_detach_policies = true

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  count = var.manage_cluster_iam_resources  ? 1 : 0

  policy_arn = "${local.policy_arn_prefix}/AmazonEKSClusterPolicy"
  role       = local.cluster_iam_role_name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  count = var.manage_cluster_iam_resources  ? 1 : 0

  policy_arn = "${local.policy_arn_prefix}/AmazonEKSServicePolicy"
  role       = local.cluster_iam_role_name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceControllerPolicy" {
  count = var.manage_cluster_iam_resources ? 1 : 0

  policy_arn = "${local.policy_arn_prefix}/AmazonEKSVPCResourceController"
  role       = local.cluster_iam_role_name
}

/*
 Adding a policy to cluster IAM role that allow permissions
 required to create AWSServiceRoleForElasticLoadBalancing service-linked role by EKS during ELB provisioning
*/

data "aws_iam_policy_document" "cluster_elb_sl_role_creation" {
  count = var.manage_cluster_iam_resources  ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeAddresses"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cluster_elb_sl_role_creation" {
  count = var.manage_cluster_iam_resources  ? 1 : 0

  name_prefix = "${var.cluster_name}-elb-sl-role-creation"
  description = "Permissions for EKS to create AWSServiceRoleForElasticLoadBalancing service-linked role"
  policy      = data.aws_iam_policy_document.cluster_elb_sl_role_creation[0].json
  path        = var.iam_path

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_elb_sl_role_creation" {
  count = var.manage_cluster_iam_resources  ? 1 : 0

  policy_arn = aws_iam_policy.cluster_elb_sl_role_creation[0].arn
  role       = local.cluster_iam_role_name
}

