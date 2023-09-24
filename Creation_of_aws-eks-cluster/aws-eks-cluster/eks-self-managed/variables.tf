### Default value for VPC

variable "vpc_name" {
    default = "eks-project-vpc"
    description = "VPC name that we will be create in the code"
}
variable "cidr_vpc"{
    default = "10.0.0.0/16"
    description = "CIDR for my VPC"
}
variable "private_sub" {
    default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"] 
    description = "CIDR range for private subnets"
}
variable "public_sub" {
    default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"] 
    description = "CIDR range for public subnets"
}

### The EKS value declared 

variable "clustername"{
    default = "Project-EKS"
    description = "Project  EKS Cluster"
}
variable "version_eks"{
    default = "1.23"
    description = " Versiob for our eks cluster"
}
variable "spot_instance_types"{
    default = ["t3.small","t2.small"]
    description = "List of instance types for SPOT instance selection"
}
variable "ondemand_instance_type"{
    default = "t3.medium"
    description = "On Demand instance type"
}
variable "spot_max_size"{
    default = 4
    description = "How many SPOT instance can be created max"
}
variable "spot_desired_size"{
    default = 2
    description = "How many SPOT instance should be running at all times"
}

variable "ondemand_desired_size"{
    default = 2
    description = "How many OnDemand instances should be running at all times"
}

