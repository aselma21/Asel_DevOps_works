# Project Create EKS Cluster on AWS!

Deploy an EKS K8 Cluster with Self managed Worker nodes on AWS using Terraform.
![](https://user-images.githubusercontent.com/78129381/153542906-59e29ff1-f2b0-4278-93f0-1a785a991904.png)

I use as a guide this repo on GitHub: [EKS](https://github.com/AKSarav/TerraformEKS-SPOT)

# Getting Started
There is a more sophisticated [terraform-aws-eks](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws) module on the Terraform registry, which allows you to create and manage Amazon EKS clusters along with managed and self-managed node groups. The terraform-aws-eks module's [code](https://github.com/312-bc/devops-tools-22j-centos/tree/aws-eks-cluster) is more complex to read and understand. With that complexity, the registry module provides more functionality and flexibility than this sample code module.

To allow the nodes to register with your EKS cluster, you will need to configure the AWS IAM Authenticator (`aws-auth`) ConfigMap with the node group's IAM role and add the role to the `system:bootstrappers` and `system:nodes` Kubernetes RBAC groups. 

### Dependencies
-   AWS user with programmatic access and high privileges
-   Linux terminal
- Kubernetes

### Installing
-   Clone the repository
-   Set environment variable TF_VAR_AWS_PROFILE or export AWS_PROFILE=OrganizationAccountAccessRole
-   Review terraform variable values in variables.tf, locals.tf, this are the value for the ec2-instances type to be created.

### Run Terraform apply to create the EKS cluster, k8 worker nodes and related AWS resources.

``terraform init``
``terraform validate``
``terraform plan``
``terraform apply``

## Resolution and troubleshooting
1. Verify that AWS CLI version 1.16.308 or greater is installed on your system:
``aws --version``
**Important:**  You must have Python version 2.7.9 or greater installed on your system. Otherwise, you receive an error.

2. Check the current identity to verify that you're using the correct credentials that have permissions for the Amazon EKS cluster:
```aws sts get-caller-identity```
The AWS Identity and Access Management (IAM) entity user or role that creates an Amazon cluster is automatically granted permissions when the cluster is created. These permissions are granted in the cluster's RBAC configuration in the control plane. IAM users or roles can also be granted access to an Amazon EKS cluster in [aws-auth ConfigMap](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html).

3. Create or update the **kubeconfig** file for your cluster:
``aws eks --region region update-kubeconfig --name cluster_name``
**Note:** Replace **region** with your AWS Region. Replace **cluster_name** with your cluster name "[Project-EKS](https://us-east-1.console.aws.amazon.com/eks/home?region=us-east-1#/clusters/Project-EKS)".

4. By default, the configuration file is created at the **kubeconfig** path (**$HOME/.kube/config**) in your home directory or merged with an existing **kubeconfig** at that location.
`` kubectl get pods -A``
``
kubectl get nodes
``

5. Test your configuration:
``kubectl get svc``


- Upon initial terraform apply, perform the steps below to migrate TFstate from Local to AWS S3.
```
    terraform init -force-copy
```
- Proceed with Terraform destroy.
``
terraform destroy
``

## Terraform resources

![anatomy of an EKS self-managed node group](https://github.com/aws-samples/amazon-eks-self-managed-node-group/raw/main/diagrams/amazon-eks-self-managed-node-group.svg)

## Now, let's start creating terraform scripts for the Kubernetes cluster.
### **Step 1:- Set the  environment variables**
``
export AWS_PROFILE=OrganizationAccountAccessRole 
``
    
   **Step 2:- Create `.tf`  file for AWS Configuration**
    -   Create  `provider.tf`  file and add below content in it also to add the backend and k8s endpoint

    provider "aws" {
      region = "us-east-1"
    }
 
    

     
   -  In the above code, we are using a recently created cluster as the host and authentication token as token
    
-   We are using the cluster_ca_certificate for the CA certificate
  ```
provider "kubernetes" {
  host = data.aws_eks_cluster.cluster.endpoint
  token = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64encode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}

  ```
  
  **Step 3:- Create .tf file for AWS VPC**

-   Create  `vpc.tf`  file for VPC and add below content in it, 
-  data  `"aws_availability_zones"`  `"available"`  will provide the list of availability zone for the us-east-1 region
- We create the cluster in the public subnets, so the nat_gateway value = false
```
variable  "region" {
default =  "us-east-1"
description =  "AWS region"
}

data  "aws_availability_zones"  "available" {}

locals {
cluster_name = var.clustername
}

module  "vpc" {
source =  "./modules/vpc"

name =  "eks-project-vpc"
cidr =  "10.0.0.0/16"
azs = data.aws_availability_zones.available.names
private_subnets =  ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnets =  ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
enable_nat_gateway =  false
single_nat_gateway =  false
enable_dns_hostnames =  true

tags =  {
"kubernetes.io/cluster/${local.cluster_name}" = "shared"
}

public_subnet_tags =  {
"kubernetes.io/cluster/${local.cluster_name}" = "shared"
"kubernetes.io/role/elb" = "1"
}

private_subnet_tags =  {
"kubernetes.io/cluster/${local.cluster_name}" = "shared"
"kubernetes.io/role/internal-elb" = "1"
}
}
```
-   We are using the AWS VPC module for VPC creation
    
-   The above code will create the AWS VPC of  `10.0.0.0/16`  CIDR range in  `us-east-1`  region
    
-   The VPC will have 3 public and 3 private subnets
    
   **Step 4:- Create .tf file for AWS Security Group**

-   Create  `security-groups.tf`  file for AWS Security Group and add below content in it
```
resource  "aws_security_group"  "worker_group_mgmt_one" {
name_prefix =  "worker_group_mgmt_one"
vpc_id = module.vpc.vpc_id

ingress {
from_port =  22
to_port =  22
protocol =  "tcp"

cidr_blocks =  [
"10.0.0.0/8",
]
}
}


```
-   We are creating the security group for the nodes group
    
-   We are allowing only 22 port for the SSH connection
    
-   We are restricting the SSH access for  `10.0.0.0/8` CIDR Block for diffrent nodes

**Step 5:- Create .tf file for the EKS Cluster**

-   Create  `main.tf`  file for VPC and add below content in it
   ```
module  "eks"{
source =  "./modules/eks"
cluster_name = var.clustername
cluster_version =  "1.23"
subnets = module.vpc.public_subnets
enable_irsa =  true
vpc_id = module.vpc.vpc_id

workers_group_defaults =  {
root_volume_type = "gp2"
}

worker_groups_launch_template =  [
{
name = "worker-group-spot-1"
override_instance_types = var.spot_instance_types
spot_allocation_strategy = "lowest-price"
asg_max_size = var.spot_max_size
asg_desired_capacity = var.spot_desired_size
kubelet_extra_args = "--node-labels=node.kubernetes.io/lifecycle=spot"
},
]

worker_groups =  [
{
name = "worker-group-1"
instance_type = var.ondemand_instance_type
additional_userdata = "echo foo bar"
asg_desired_capacity = var.ondemand_desired_size
kubelet_extra_args = "--node-labels=node.kubernetes.io/lifecycle=ondemand"
additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
}
]
}

data  "aws_eks_cluster"  "cluster" {
name = module.eks.cluster_id
}

data  "aws_eks_cluster_auth"  "cluster" {
name = module.eks.cluster_id
}
```
-   For EKS Cluster creation we are using the launch template to have the ASG desired capacity of ec-2 instance
    
-   The below code will create 2 worker groups that must contain at least 1 t3.medium instance along with at least 2 and at most 4  **mixed spot and on-demand instances**
    
-   We are attaching the recently created security group to the worker-group-1

**Step 6:- Initialize the working directory**

-   Run  `terraform init`  command in the working directory. It will download all the necessary providers and all the modules

**Step 7:- Create a terraform plan**

-   Run  `terraform plan`  command in the working directory. It will give the execution plan

**Step 8:- Create the cluster on AWS**
-   Run  `terraform apply`  command in the working directory. It will be going to create the Kubernetes cluster on AWS
    
-   Terraform will create the below resources on AWS
    
-   VPC
    
-   Route Table
    
-   IAM Role
    
-   Security Group
- Launch template
- Auto-Scaling Group
    
-   Public & Private Subnets
    
- Worker nodes 
-   EKS Cluster


 **Step 11:- Verify the resources on AWS**

-   Navigate to your AWS account and verify the resources


## Deploy the ingress-nginx

For reference I did used the following link:                                                                     
(https://kubernetes.github.io/ingress-nginx/deploy/\#aws)

On most Kubernetes clusters, the ingress controller will work without requiring any extra configuration.
In AWS, we use a Network load balancer (NLB) to expose the NGINX Ingress controller behind a Service of `Type=LoadBalancer`.

1.  Edit the file and change the VPC CIDR in use for the Kubernetes cluster:
    
    `proxy-real-ip-cidr: XXX.XXX.XXX/XX` 
    
2.  Change the AWS Certificate Manager (ACM) ID as well:
 (we will not needed for now)
    
    `arn:aws:acm:us-west-2:XXXXXXXX:certificate/XXXXXX-XXXXXXX-XXXXXXX-XXXXXXXX` 
    
4.  Deploy the manifest:
    
    `kubectl apply -f deploy.yaml`


``
kubectl get service/ingress-nginx-controller -n ingress-nginx
``

##  Dependency Violation
I faced the error when try to destroy the resources, they get depended to the VPC subnets , because of the LB created for testing purpose outside the code. So if we apply the yaml file after the cluster its connected we need manual to delete the yaml.file or to delete LB from console, after that to detach the Network interfaces from subnets.


