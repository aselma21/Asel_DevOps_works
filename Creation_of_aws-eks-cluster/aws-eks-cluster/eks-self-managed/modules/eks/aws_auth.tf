##If you would like to edit the aws-auth ConfigMap manually, you can run: $ kubectl edit -n kube-system configmap/aws-auth

locals {
  auth_launch_template_worker_roles = [
    for index in range(0,local.worker_group_launch_template_count ) : {
      worker_role_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${element(
        coalescelist(
          aws_iam_instance_profile.workers_launch_template.*.role,
          data.aws_iam_instance_profile.custom_worker_group_launch_template_iam_instance_profile.*.role_name,
          [""]
        ),
        index
      )}"
      platform = lookup(
        var.worker_groups_launch_template[index],
        "platform",
        local.workers_group_defaults["platform"]
      )
    }
  ]

  auth_worker_roles = [
    for index in range(0,  local.worker_group_launch_configuration_count ) : {
      worker_role_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${element(
        coalescelist(
          aws_iam_instance_profile.workers.*.role,
          data.aws_iam_instance_profile.custom_worker_group_iam_instance_profile.*.role_name,
          [""]
        ),
        index,
      )}"
      platform = lookup(
        var.worker_groups[index],
        "platform",
        local.workers_group_defaults["platform"]
      )
    }
  ]

  # Convert to format needed by aws-auth ConfigMap
  configmap_roles = [
    for role in concat(
      local.auth_launch_template_worker_roles,
      local.auth_worker_roles,     

     ) :
     {
      rolearn  = replace(role["worker_role_arn"], replace(var.iam_path, "/^//", ""), "")
      username = role["platform"] == "fargate" ? "system:node:{{SessionName}}" : "system:node:{{EC2PrivateDNSName}}"
      groups = tolist(concat(
        [
          "system:bootstrappers",
          "system:nodes",
        ],
         role["platform"] == "fargate" ? ["system:node-proxier"] : [],
      ))
    }
  ]
}

resource "kubernetes_config_map" "aws_auth" {
  count = var.manage_aws_auth ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
    labels = merge(
      {
        "app.kubernetes.io/managed-by" = "Terraform"
        "terraform.io/module" = "terraform-aws-modules.eks.aws"
      },
    )
  }

  data = {
    mapRoles = yamlencode(
      distinct(concat(
        local.configmap_roles,
        var.map_roles,
      ))
    )
    mapUsers    = yamlencode(var.map_users)
    mapAccounts = yamlencode(var.map_accounts)
  }

  depends_on = [data.http.wait_for_cluster[0]]
}


