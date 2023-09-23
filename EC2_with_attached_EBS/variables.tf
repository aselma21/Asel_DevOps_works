variable "region" {
    type = string
    description = "aws region"
} 

 
variable "cidr_block" {
    type = string
    description = "cidr block for VPC"
} 

variable "name" {
    type = string
    description = "VPC name"
} 

variable "cidr_block_subnets" {
    type = string
    description = "cidr block for subnets"
} 

variable "rt_name" {
    type = string
    description = "Public route table name"
} 

variable "destination_cidr_block" {
    type = string
    description = "cidr block for route tables"
} 

variable "name_prefix" {
    type = string
    description = "Security Group name"
} 

variable "sg_inbound_ports" {
    description = "sg inbound ports"
} 

variable "sg_protocol" {
} 

variable "cidr_blocks" {
    description = "the sg cidr block"
}


variable "sg_http_inbound_ports" {
    description = "sg inbound ports"
} 

variable "sg_http_protocol" {
} 

variable "ami_name" {
    type = string
    description = "AMI name"
} 


variable "instance_type" {
    type = string 
    description = "instance type"
}

variable "instance_name" {
    type = string
    description = "EC2 instance name"
} 