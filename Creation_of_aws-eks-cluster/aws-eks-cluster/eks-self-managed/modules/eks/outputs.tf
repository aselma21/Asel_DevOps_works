output "cluster_id" {
  description = "The name/id of the EKS cluster. Will block on cluster creation until the cluster is really ready."
  value       = local.cluster_id

  # So that calling plans wait for the cluster to be available before attempting to use it.
  # There is no need to duplicate this datasource
  depends_on = [data.http.wait_for_cluster]
}

output "cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API."
  value       = local.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the EKS cluster."
  value       = element(concat(aws_eks_cluster.this[*].version, [""]), 0)
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster. On 1.14 or later, this is the 'Additional security groups' in the EKS console."
  value       = local.cluster_security_group_id
}

output "config_map_aws_auth" {
  description = "A kubernetes configuration to authenticate to this EKS cluster."
  value       = kubernetes_config_map.aws_auth.*
}

output "cluster_iam_role_name" {
  description = "IAM role name of the EKS cluster."
  value       = local.cluster_iam_role_name
}

output "worker_security_group_id" {
  description = "Security group ID attached to the EKS workers."
  value       = local.worker_security_group_id
}

