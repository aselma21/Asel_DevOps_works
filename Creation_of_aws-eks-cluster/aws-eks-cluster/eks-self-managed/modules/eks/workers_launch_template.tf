# Worker Groups using Launch Templates

resource "aws_autoscaling_group" "workers_launch_template" {
  count = local.worker_group_launch_template_count

 # Project-EKS-worker-group-on-demand20230112040140507800000007
  name_prefix = join(
    "-",
    compact(
      [
        local.cluster_name,
        lookup(var.worker_groups_launch_template[count.index], "name", count.index)
      ]
    )
  )
  desired_capacity = lookup(
    var.worker_groups_launch_template[count.index],
    "asg_desired_capacity",
    local.workers_group_defaults["asg_desired_capacity"],
  )
  max_size = lookup(
    var.worker_groups_launch_template[count.index],
    "asg_max_size",
    local.workers_group_defaults["asg_max_size"],
  )
  min_size = lookup(
    var.worker_groups_launch_template[count.index],
    "asg_min_size",
    local.workers_group_defaults["asg_min_size"],
  )
  force_delete = lookup(
    var.worker_groups_launch_template[count.index],
    "asg_force_delete",
    local.workers_group_defaults["asg_force_delete"],
  )

  vpc_zone_identifier = lookup(
    var.worker_groups_launch_template[count.index],
    "subnets",
    local.workers_group_defaults["subnets"]
  )
  protect_from_scale_in = lookup(
    var.worker_groups_launch_template[count.index],
    "protect_from_scale_in",
    local.workers_group_defaults["protect_from_scale_in"],
  )
  enabled_metrics = lookup(
    var.worker_groups_launch_template[count.index],
    "enabled_metrics",
    local.workers_group_defaults["enabled_metrics"]
  )
  placement_group = lookup(
    var.worker_groups_launch_template[count.index],
    "placement_group",
    local.workers_group_defaults["placement_group"],
  )
  termination_policies = lookup(
    var.worker_groups_launch_template[count.index],
    "termination_policies",
    local.workers_group_defaults["termination_policies"]
  )
  max_instance_lifetime = lookup(
    var.worker_groups_launch_template[count.index],
    "max_instance_lifetime",
    local.workers_group_defaults["max_instance_lifetime"],
  )

  health_check_type = lookup(
    var.worker_groups_launch_template[count.index],
    "health_check_type",
    local.workers_group_defaults["health_check_type"]
  )
  health_check_grace_period = lookup(
    var.worker_groups_launch_template[count.index],
    "health_check_grace_period",
    local.workers_group_defaults["health_check_grace_period"]
  )

  dynamic "mixed_instances_policy" {
    iterator = item
    for_each = (lookup(var.worker_groups_launch_template[count.index], "override_instance_types", null) != null) || (lookup(var.worker_groups_launch_template[count.index], "on_demand_allocation_strategy", local.workers_group_defaults["on_demand_allocation_strategy"]) != null) ? [var.worker_groups_launch_template[count.index]] : []

    content {
      instances_distribution {
        on_demand_allocation_strategy = lookup(
          item.value,
          "on_demand_allocation_strategy",
          "prioritized",
        )
        on_demand_base_capacity = lookup(
          item.value,
          "on_demand_base_capacity",
          local.workers_group_defaults["on_demand_base_capacity"],
        )
        on_demand_percentage_above_base_capacity = lookup(
          item.value,
          "on_demand_percentage_above_base_capacity",
          local.workers_group_defaults["on_demand_percentage_above_base_capacity"],
        )
        spot_allocation_strategy = lookup(
          item.value,
          "spot_allocation_strategy",
          local.workers_group_defaults["spot_allocation_strategy"],
        )
        spot_instance_pools = lookup(
          item.value,
          "spot_instance_pools",
          local.workers_group_defaults["spot_instance_pools"],
        )
        spot_max_price = lookup(
          item.value,
          "spot_max_price",
          local.workers_group_defaults["spot_max_price"],
        )
      }

      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.workers_launch_template.*.id[count.index]
          version = lookup(
            var.worker_groups_launch_template[count.index],
            "launch_template_version",
            lookup(
              var.worker_groups_launch_template[count.index],
              "launch_template_version",
              local.workers_group_defaults["launch_template_version"]
            ) == "$Latest"
            ? aws_launch_template.workers_launch_template.*.latest_version[count.index]
            : aws_launch_template.workers_launch_template.*.default_version[count.index]
          
          )
        }

        dynamic "override" {
          for_each = lookup(
            var.worker_groups_launch_template[count.index],
            "override_instance_types",
            local.workers_group_defaults["override_instance_types"]
          )

          content {
            instance_type = override.value
          }
        }
      }
    }
  }

  dynamic "launch_template" {
    iterator = item
    for_each = (lookup(var.worker_groups_launch_template[count.index], "override_instance_types", null) != null) || (lookup(var.worker_groups_launch_template[count.index], "on_demand_allocation_strategy", local.workers_group_defaults["on_demand_allocation_strategy"]) != null) ? [] : [var.worker_groups_launch_template[count.index]]

    content {
      id = aws_launch_template.workers_launch_template.*.id[count.index]
      version = lookup(
        var.worker_groups_launch_template[count.index],
        "launch_template_version",
        lookup(
          var.worker_groups_launch_template[count.index],
          "launch_template_version",
          local.workers_group_defaults["launch_template_version"]
        ) == "$Latest"
        ? aws_launch_template.workers_launch_template.*.latest_version[count.index]
        : aws_launch_template.workers_launch_template.*.default_version[count.index]
      
      )
    }
  }


  dynamic "warm_pool" {
    for_each = lookup(var.worker_groups_launch_template[count.index], "warm_pool", null) != null ? [lookup(var.worker_groups_launch_template[count.index], "warm_pool")] : []

    content {
      pool_state                  = lookup(warm_pool.value, "pool_state", null)
      min_size                    = lookup(warm_pool.value, "min_size", null)
      max_group_prepared_capacity = lookup(warm_pool.value, "max_group_prepared_capacity", null)
    }
  }

  dynamic "tag" {
    for_each = concat(
      [
        {
          "key" = "Name"
          "value" = "${local.cluster_name}-${lookup(
            var.worker_groups_launch_template[count.index],
            "name",
            count.index,
          )}-eks_asg"
          "propagate_at_launch" = true
        },
        {
          "key"                 = "kubernetes.io/cluster/${local.cluster_name}"
          "value"               = "owned"
          "propagate_at_launch" = true
        },
      ],
      [
        for tag_key, tag_value in var.tags :
        tomap({
          key                 = tag_key
          value               = tag_value
          propagate_at_launch = "true"
        })
        if tag_key != "Name" && !contains([for tag in lookup(var.worker_groups_launch_template[count.index], "tags", local.workers_group_defaults["tags"]) : tag["key"]], tag_key)
      ],
      lookup(
        var.worker_groups_launch_template[count.index],
        "tags",
        local.workers_group_defaults["tags"]
      )
    )
    content {
      key                 = tag.value.key
      value               = tag.value.value
      propagate_at_launch = tag.value.propagate_at_launch
    }
  }
 }

resource "aws_launch_template" "workers_launch_template" {
  count = local.worker_group_launch_template_count

  name_prefix = "${local.cluster_name}-${lookup(
    var.worker_groups_launch_template[count.index],
    "name",
    count.index,
  )}"


  network_interfaces {
    associate_public_ip_address = lookup(
      var.worker_groups_launch_template[count.index],
      "public_ip",
      local.workers_group_defaults["public_ip"],
    )
    delete_on_termination = lookup(
      var.worker_groups_launch_template[count.index],
      "eni_delete",
      local.workers_group_defaults["eni_delete"],
    )
    security_groups = flatten([
      local.worker_security_group_id,
      lookup(
        var.worker_groups_launch_template[count.index],
        "additional_security_group_ids",
        local.workers_group_defaults["additional_security_group_ids"],
      ),
    ])
  }

  iam_instance_profile {
    name = coalescelist(
      aws_iam_instance_profile.workers_launch_template.*.name,
      data.aws_iam_instance_profile.custom_worker_group_launch_template_iam_instance_profile.*.name,
    )[count.index]
  }

  image_id = lookup(
    var.worker_groups_launch_template[count.index],
    "ami_id",
    local.default_ami_id_linux,
  )
  instance_type = lookup(
    var.worker_groups_launch_template[count.index],
    "instance_type",
    local.workers_group_defaults["instance_type"],
  )

  key_name = lookup(
    var.worker_groups_launch_template[count.index],
    "key_name",
    local.workers_group_defaults["key_name"],
  )
  user_data = base64encode(
    local.launch_template_userdata_rendered[count.index],
  )

  monitoring {
    enabled = lookup(
      var.worker_groups_launch_template[count.index],
      "enable_monitoring",
      local.workers_group_defaults["enable_monitoring"],
    )
    
  }

  dynamic "placement" {
    for_each = lookup(var.worker_groups_launch_template[count.index], "launch_template_placement_group", local.workers_group_defaults["launch_template_placement_group"]) != null ? [lookup(var.worker_groups_launch_template[count.index], "launch_template_placement_group", local.workers_group_defaults["launch_template_placement_group"])] : []

    content {
      tenancy = lookup(
        var.worker_groups_launch_template[count.index],
        "launch_template_placement_tenancy",
        local.workers_group_defaults["launch_template_placement_tenancy"],
      )
      group_name = placement.value
    }
  }
  ## This is optional
  
  dynamic "block_device_mappings" {
    for_each = lookup(var.worker_groups_launch_template[count.index], "additional_ebs_volumes", local.workers_group_defaults["additional_ebs_volumes"])
    content {
      device_name = block_device_mappings.value.block_device_name

      ebs {
        volume_size = lookup(
          block_device_mappings.value,
          "volume_size",
          local.workers_group_defaults["root_volume_size"],
        )
        volume_type = lookup(
          block_device_mappings.value,
          "volume_type",
          local.workers_group_defaults["root_volume_type"],
        )
        iops = lookup(
          block_device_mappings.value,
          "iops",
          local.workers_group_defaults["root_iops"],
        )
        throughput = lookup(
          block_device_mappings.value,
          "throughput",
          local.workers_group_defaults["root_volume_throughput"],
        )
        encrypted = lookup(
          block_device_mappings.value,
          "encrypted",
          local.workers_group_defaults["root_encrypted"],
        )
        kms_key_id = lookup(
          block_device_mappings.value,
          "kms_key_id",
          local.workers_group_defaults["root_kms_key_id"],
        )
        snapshot_id = lookup(
          block_device_mappings.value,
          "snapshot_id",
          local.workers_group_defaults["snapshot_id"],
        )
        delete_on_termination = lookup(block_device_mappings.value, "delete_on_termination", true)
      }
    }

  }

  tag_specifications {
    resource_type = "volume"

   # Project-EKS-worker-group-spot-eks_asg
   # Attached instance : i-07f34261e1e2f1211 (Project-EKS-worker-group-spot-eks_asg): /dev/xvda (attached)

    tags = merge(
      {
        "Name" = "${local.cluster_name}-${lookup(
          var.worker_groups_launch_template[count.index],
          "name",
          count.index,
        )}-eks_asg"
      },
      var.tags,
      {
        for tag in lookup(var.worker_groups_launch_template[count.index], "tags", local.workers_group_defaults["tags"]) :
        tag["key"] => tag["value"]
        if tag["key"] != "Name" && tag["propagate_at_launch"]
      }
    )
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      {
        "Name" = "${local.cluster_name}-${lookup(
          var.worker_groups_launch_template[count.index],
          "name",
          count.index,
        )}-eks_asg"
      },
      { for tag_key, tag_value in var.tags :
        tag_key => tag_value
        if tag_key != "Name" && !contains([for tag in lookup(var.worker_groups_launch_template[count.index], "tags", local.workers_group_defaults["tags"]) : tag["key"]], tag_key)
      }
    )
  }


  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }

  # Prevent premature access of security group roles and policies by pods that
  # require permissions on create/destroy that depend on workers.
  depends_on = [
    aws_security_group_rule.workers_egress_internet,
    aws_security_group_rule.workers_ingress_self,
    aws_security_group_rule.workers_ingress_cluster,
    aws_security_group_rule.workers_ingress_cluster_kubelet,
    aws_security_group_rule.workers_ingress_cluster_primary,
    aws_security_group_rule.cluster_primary_ingress_workers,
    aws_iam_role_policy_attachment.workers_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.workers_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.workers_AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_iam_instance_profile" "workers_launch_template" {
  count = var.manage_worker_iam_resources ? local.worker_group_launch_template_count : 0

  name_prefix = local.cluster_name
  role = lookup(
    var.worker_groups_launch_template[count.index],
    "iam_role_id",
    local.default_iam_role_id,
  )
  path = var.iam_path

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
