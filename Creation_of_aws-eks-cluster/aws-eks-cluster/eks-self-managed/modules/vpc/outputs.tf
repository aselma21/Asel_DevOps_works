output "vpc_id" {
  description = "The ID of the VPC"
  value       = concat(aws_vpc.eks-vpc.*.id, [""])[0]
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = concat(aws_vpc.eks-vpc.*.arn, [""])[0]
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = concat(aws_vpc.eks-vpc.*.cidr_block, [""])[0]
}

output "default_security_group_id" {
  description = "The ID of the security group created by default on VPC creation"
  value       = concat(aws_vpc.eks-vpc.*.default_security_group_id, [""])[0]
}

output "vpc_main_route_table_id" {
  description = "The ID of the main route table associated with this VPC"
  value       = concat(aws_vpc.eks-vpc.*.main_route_table_id, [""])[0]
}


output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private.*.id
}


output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public.*.id
}


output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = concat(aws_internet_gateway.this.*.id, [""])[0]
}

# Static values (arguments)
output "azs" {
  description = "A list of availability zones specified as argument to this module"
  value       = var.azs
}

output "name" {
  description = "The name of the VPC specified as argument to this module"
  value       = var.name
}

