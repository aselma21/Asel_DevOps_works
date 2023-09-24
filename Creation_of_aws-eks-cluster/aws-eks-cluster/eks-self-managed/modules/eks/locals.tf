locals {

  # EKS Cluster
  
  # coalescelist function - takes any number of list arguments and returns the first one that isn't empty.
  # flatten takes a list and replaces any elements that are lists with a flattened sequence of the list contents.
  # join produces a string by concatenating together all elements of a given list of strings with the given delimiter.


  cluster_id                        = coalescelist(aws_eks_cluster.this[*].id, [""])[0]
  cluster_arn                       = coalescelist(aws_eks_cluster.this[*].arn, [""])[0]
  cluster_name                      = coalescelist(aws_eks_cluster.this[*].name, [""])[0]
  cluster_endpoint                  = coalescelist(aws_eks_cluster.this[*].endpoint, [""])[0]
  cluster_auth_base64               = coalescelist(aws_eks_cluster.this[*].certificate_authority[0].data, [""])[0]
  cluster_oidc_issuer_url           = flatten(concat(aws_eks_cluster.this[*].identity[*].oidc[0].issuer, [""]))[0]
  cluster_primary_security_group_id = coalescelist(aws_eks_cluster.this[*].vpc_config[0].cluster_security_group_id, [""])[0]

  cluster_security_group_id = var.cluster_create_security_group ? join("", aws_security_group.cluster.*.id) : var.cluster_security_group_id
  cluster_iam_role_name     = var.manage_cluster_iam_resources ? join("", aws_iam_role.cluster.*.name) : var.cluster_iam_role_name
  cluster_iam_role_arn      = var.manage_cluster_iam_resources ? join("", aws_iam_role.cluster.*.arn) : join("", data.aws_iam_role.custom_cluster_iam_role.*.arn)

  # Worker groups
  worker_security_group_id = var.worker_create_security_group ? join("", aws_security_group.workers.*.id) : var.worker_security_group_id

  default_iam_role_id    = concat(aws_iam_role.workers.*.id, [""])[0]
  default_ami_id_linux   = local.workers_group_defaults.ami_id != "" ? local.workers_group_defaults.ami_id : concat(data.aws_ami.eks_worker.*.id, [""])[0]

  worker_group_launch_configuration_count = length(var.worker_groups)
  worker_group_launch_template_count      = length(var.worker_groups_launch_template)

  worker_groups_platforms = "linux"    #can set up as var.default_platform if we want to use another one

  worker_ami_name_filter         = coalesce(var.worker_ami_name_filter, "amazon-eks-node-${coalesce(var.cluster_version, "cluster_version")}-v*")

# To ensure test configurations are partition agnostic, any hardcoded Partition identifiers ([a-z]{2}(-[a-z]+)+) 
# and domains should be replaced with the aws_partition data source.

  ec2_principal     = "ec2.${data.aws_partition.current.dns_suffix}"
  sts_principal     = "sts.${data.aws_partition.current.dns_suffix}"
  policy_arn_prefix = "arn:${data.aws_partition.current.partition}:iam::aws:policy"
  client_id_list    = []
  

  workers_group_defaults= {
    name                              = "count.index"               # Name of the worker group. Literal count.index will never be used but if name is not set, the count.index interpolation will be used.
    tags                              = []                          # A list of maps defining extra tags to be applied to the worker group autoscaling group and volumes.
    ami_id                            = ""                          # AMI ID for the eks linux based workers. If none is provided, Terraform will search for the latest version of their EKS optimized worker AMI based on platform.
    asg_desired_capacity              = "2"                         # Desired worker capacity in the autoscaling group and changing its value will not affect the autoscaling group's desired capacity because the cluster-autoscaler manages up and down scaling of the nodes. Cluster-autoscaler add nodes when pods are in pending state and remove the nodes when they are not required by modifying the desired_capacity of the autoscaling group. Although an issue exists in which if the value of the asg_min_size is changed it modifies the value of asg_desired_capacity.
    asg_max_size                      = "4"                         # Maximum worker capacity in the autoscaling group.
    asg_min_size                      = "1"                         # Minimum worker capacity in the autoscaling group. NOTE: Change in this paramater will affect the asg_desired_capacity, like changing its value to 2 will change asg_desired_capacity value to 2 but bringing back it to 1 will not affect the asg_desired_capacity.
    asg_force_delete                  = false                       # Enable forced deletion for the autoscaling group.
    asg_initial_lifecycle_hooks       = []                          # Initital lifecycle hook for the autoscaling group.
    health_check_type                 = null                        # Controls how health checking is done. Valid values are "EC2" or "ELB".
    health_check_grace_period         = null                        # Time in seconds after instance comes into service before checking health.
    instance_type                     = "t3.medium"                  # Size of the workers instances.
    spot_price                        = ""                          # Cost of spot instance.
    placement_tenancy                 = ""                          # The tenancy of the instance. Valid values are "default" or "dedicated".
    root_volume_size                  = "100"                       # root volume size of workers instances.
    root_volume_type                  = "gp2"                       # root volume type of workers instances, can be "standard", "gp3", "gp2", or "io1"
    root_iops                         = "0"                         # The amount of provisioned IOPS. This must be set with a volume_type of "io1".
    root_volume_throughput            = null                        # The amount of throughput to provision for a gp3 volume.
    key_name                          = ""                          # The key pair name that should be used for the instances in the autoscaling group
    pre_userdata                      = ""                          # userdata to pre-append to the default userdata.
    userdata_template_file            = ""                          # alternate template to use for userdata
    userdata_template_extra_args      = {}                          # Additional arguments to use when expanding the userdata template file
    bootstrap_extra_args              = ""                          # Extra arguments passed to the bootstrap.sh script from the EKS AMI (Amazon Machine Image).
    additional_userdata               = ""                          # userdata to append to the default userdata.
    ebs_optimized                     = true                        # sets whether to use ebs optimization on supported types.
    enable_monitoring                 = true                        # Enables/disables detailed monitoring.
    public_ip                         = true                        # Associate a public ip address with a worker
    kubelet_extra_args                = ""                          # This string is passed directly to kubelet if set. Useful for adding labels or taints.
    subnets                           = var.subnets                 # A list of subnets to place the worker nodes in. i.e. ["subnet-123", "subnet-456", "subnet-789"]
    additional_security_group_ids     = []                          # A list of additional security group ids to include in worker launch config
    protect_from_scale_in             = false                       # Prevent AWS from scaling in, so that cluster-autoscaler is solely responsible.
    iam_instance_profile_name         = ""                          # A custom IAM instance profile name. Used when manage_worker_iam_resources is set to false. Incompatible with iam_role_id.
    iam_role_id                       = "local.default_iam_role_id" # A custom IAM role id. Incompatible with iam_instance_profile_name.  Literal local.default_iam_role_id will never be used but if iam_role_id is not set, the local.default_iam_role_id interpolation will be used.
    target_group_arns                 = null                        # A list of Application LoadBalancer (ALB) target group ARNs to be associated to the autoscaling group
    enabled_metrics                   = []                          # A list of metrics to be collected i.e. ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity"]
    placement_group                   = null                        # The name of the placement group into which to launch the instances, if any.
    termination_policies              = []                          # A list of policies to decide how the instances in the auto scale group should be terminated.
    platform                          = "linux"                     # Platform of workers. We have by default linux
    additional_ebs_volumes            = []                          # A list of additional volumes to be attached to the instances on this Auto Scaling group. Each volume should be an object with the following: block_device_name (required), volume_size, volume_type, iops, throughput, encrypted, kms_key_id (only on launch-template), delete_on_termination, snapshot_id. Optional values are grabbed from root volume or from defaults
    additional_instance_store_volumes = []                          # A list of additional instance store (local disk) volumes to be attached to the instances on this Auto Scaling group. Each volume should be an object with the following: block_device_name (required), virtual_name.
    warm_pool                         = null                        # If this block is configured, add a Warm Pool to the specified Auto Scaling group.
    timeouts                          = {}                          # A map of timeouts for create/update/delete operations
    snapshot_id                       = null                        # A custom snapshot ID.

    # Settings for launch templates
    root_block_device_name               = concat(data.aws_ami.eks_worker.*.root_device_name, [""])[0]         # Root device name for Linux workers. If not provided, will assume default Linux AMI was used.
    root_kms_key_id                      = ""                                                                  # The KMS key to use when encrypting the root storage device
    launch_template_id                   = null                                                                # The id of the launch template used for managed node_groups
    launch_template_version              = "$Latest"                                                           # The latest version of the launch template to use in the autoscaling group
    launch_template_placement_tenancy    = "default"                                                           # The placement tenancy for instances
    launch_template_placement_group      = null                                                                # The name of the placement group into which to launch the instances, if any.
    root_encrypted                       = false                                                               # Whether the volume should be encrypted or not
    eni_delete                           = true                                                                # Delete the Elastic Network Interface (ENI) on termination (if set to false you will have to manually delete before destroying)
    cpu_credits                          = "standard"                                                          # T2/T3 unlimited mode, can be 'standard' or 'unlimited'. Used 'standard' mode as default to avoid paying higher costs
    market_type                          = null
    metadata_http_endpoint               = "enabled"  # The state of the metadata service: enabled, disabled.
    metadata_http_tokens                 = "optional" # If session tokens are required: optional, required.
    metadata_http_put_response_hop_limit = null       # The desired HTTP PUT response hop limit for instance metadata requests.
    
    # Settings for launch templates with mixed instances policy
    override_instance_types                  = ["m5.large", "m5a.large", "m5d.large", "m5ad.large"] # A list of override instance types for mixed instances policy
    on_demand_allocation_strategy            = null                                                 # Strategy to use when launching on-demand instances. Valid values: prioritized.
    on_demand_base_capacity                  = "0"                                                  # Absolute minimum amount of desired capacity that must be fulfilled by on-demand instances
    on_demand_percentage_above_base_capacity = "25"                                                  # Percentage split between on-demand and Spot instances above the base on-demand capacity
    spot_allocation_strategy                 = "lowest-price"                                       # Valid options are 'lowest-price' and 'capacity-optimized'. If 'lowest-price', the Auto Scaling group launches instances using the Spot pools with the lowest price, and evenly allocates your instances across the number of Spot pools. If 'capacity-optimized', the Auto Scaling group launches instances using Spot pools that are optimally chosen based on the available Spot capacity.
    spot_instance_pools                      = 10                                                   # "Number of Spot pools per availability zone to allocate capacity. EC2 Auto Scaling selects the cheapest Spot pools and evenly allocates Spot capacity across the number of Spot pools that you specify."
    spot_max_price                           = ""                                                   # Maximum price per unit hour that the user is willing to pay for the Spot instances. Default is the on-demand price
    max_instance_lifetime                    = 0                                                    # Maximum number of seconds instances can run in the ASG. 0 is unlimited.The maximum instance lifetime specifies the maximum amount of time (in seconds) that an instance can be in service before it is terminated and replaced.
    instance_refresh_strategy                = "Rolling"                                            # Strategy to use for instance refresh. Default is 'Rolling' which the only valid value.
    instance_refresh_min_healthy_percentage  = 90                                                   # The amount of capacity in the ASG that must remain healthy during an instance refresh, as a percentage of the ASG's desired capacity.
    instance_refresh_instance_warmup         = null                                                 # The number of seconds until a newly launched instance is configured and ready to use. Defaults to the ASG's health check grace period.
    instance_refresh_triggers                = []                                                   # Set of additional property names that will trigger an Instance Refresh. A refresh will always be triggered by a change in any of launch_configuration, launch_template, or mixed_instances_policy.
  }



  ebs_optimized_not_supported = [
    "c1.medium",
    "cc2.8xlarge",
    "cr1.8xlarge",
    "g2.8xlarge",
    "i2.8xlarge",
    "m1.medium",
    "m1.small",
    "m2.xlarge",
    "m3.large",
    "m3.medium",
    "r5ad.16xlarge",
    "r5ad.8xlarge",
    "t1.micro",
    "t2.2xlarge",
    "t2.large",
    "t2.medium",
    "t2.micro",
    "t2.nano",
    "t2.small",
    "t2.xlarge"
  ]


  launch_configuration_userdata_rendered = [
    for index in range( local.worker_group_launch_configuration_count) : templatefile(
      lookup(
        var.worker_groups[index],
        "userdata_template_file",
        lookup(var.worker_groups[index], "platform", local.workers_group_defaults["platform"]) == "linux"
        ? "${path.module}/templates/userdata.sh.tpl"
        : "${path.module}/templates/userdata.sh.tpl"
      ),
      merge({
        platform            = local.workers_group_defaults["platform"]
        cluster_name        = local.cluster_name
        endpoint            = local.cluster_endpoint
        cluster_auth_base64 = local.cluster_auth_base64
        pre_userdata = lookup(
          var.worker_groups[index],
          "pre_userdata",
          local.workers_group_defaults["pre_userdata"],
        )
        additional_userdata = lookup(
          var.worker_groups[index],
          "additional_userdata",
          local.workers_group_defaults["additional_userdata"],
        )
        bootstrap_extra_args = lookup(
          var.worker_groups[index],
          "bootstrap_extra_args",
          local.workers_group_defaults["bootstrap_extra_args"],
        )
        kubelet_extra_args = lookup(
          var.worker_groups[index],
          "kubelet_extra_args",
          local.workers_group_defaults["kubelet_extra_args"],
        ) 

        # this depends on userdata.sh from templates

        },
        lookup(
          var.worker_groups[index],
          "userdata_template_extra_args",
          local.workers_group_defaults["userdata_template_extra_args"]
        )
      )
    )
  ]

  launch_template_userdata_rendered = [
    for index in range(local.worker_group_launch_template_count) : templatefile(
      lookup(
        var.worker_groups_launch_template[index],
        "userdata_template_file",
        lookup(var.worker_groups_launch_template[index], "platform", local.workers_group_defaults["platform"]) == "linux"
        ? "${path.module}/templates/userdata.sh.tpl"
        : "${path.module}/templates/userdata.sh.tpl"
      ),
      merge({
        platform            = local.workers_group_defaults["platform"]
        cluster_name        = local.cluster_name
        endpoint            = local.cluster_endpoint
        cluster_auth_base64 = local.cluster_auth_base64
        pre_userdata = lookup(
          var.worker_groups_launch_template[index],
          "pre_userdata",
          local.workers_group_defaults["pre_userdata"],
        )
        additional_userdata = lookup(
          var.worker_groups_launch_template[index],
          "additional_userdata",
          local.workers_group_defaults["additional_userdata"],
        )
        bootstrap_extra_args = lookup(
          var.worker_groups_launch_template[index],
          "bootstrap_extra_args",
          local.workers_group_defaults["bootstrap_extra_args"],
        )
        kubelet_extra_args = lookup(
          var.worker_groups_launch_template[index],
          "kubelet_extra_args",
          local.workers_group_defaults["kubelet_extra_args"],
        )
        },
        lookup(
          var.worker_groups_launch_template[index],
          "userdata_template_extra_args",
          local.workers_group_defaults["userdata_template_extra_args"]
        )
      )
    )
  ]
}
