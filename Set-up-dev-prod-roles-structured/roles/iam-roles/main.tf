module "iam-roles-dev" {
    count = var.stage == "dev" ? 1 : 0
    source = "./modules/dev"
    trusted_account_number = var.trusted_account_number
    developer_role = var.developer_role
    devops_role = var.devops_role
    developer_policy = var.developer_policy
    devops_policy = var.devops_policy
}

module "iam-roles-prod" {
    count = var.stage == "prod" ? 1 : 0
    source = "./modules/prod"
    trusted_account_number = var.trusted_account_number
    developer_role = var.developer_role
    devops_role = var.devops_role
    developer_policy = var.developer_policy
    devops_policy = var.devops_policy
}