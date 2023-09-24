# task-create-iam-roles-for-dev-prod-accounts

In this task i need to create two different roles in each account prod and dev using terraform

# Why should I use IAM roles? 

You should use IAM roles to grant access to your AWS accounts by relying on short-term credentials, a security best practice. Authorized identities, which can be AWS services or users from your identity provider, can assume roles to make AWS requests 

# How IAM roles works?

An IAM role is similar to an IAM user, in that it is an AWS identity with permission policies that determine what the identity can and cannot do in AWS. However, instead of being uniquely associated with one person, a role is intended to be assumable by anyone who needs it.

![image](https://user-images.githubusercontent.com/114795949/209452918-df696ec0-5a6c-470c-930c-a47bc1e34552.png)



To create IAM roles we will follow best practise by using terraform and make our code reusable 
# Why use terraform for AWS?
Terraform allows you to reference output variables from one module for use in different modules. The benefit is that you can create multiple, smaller Terraform files grouped by function or service as opposed to one large file with potentially hundreds or thousands of lines of code

![image](https://user-images.githubusercontent.com/114795949/209452950-0a254e1e-a81f-4a46-bbeb-5d99fcfbdc8b.png)


## ***steps for creation IAM roles with terraform***
We need to create 4 different IAM roles 2 for prod and 2 for dev account
* ***create main.tf file***: Terraform modules must follow the standard module structure. Start every module with a main.tf file, where resources are located by default. In every module, include a README.md file in Markdown format.

https://registry.terraform.io/providers/hashicorp/aws/latest/docs 

* ***gitignore***: store all required files names in .gitignore to revent accidental push junk to yours git repository


* ***remote backend for  terraform.tfstate***: A Terraform backend determines how Terraform loads and stores state. The default backend, which you've been using this entire time, is the local backend, which stores the state file on your local disk. Remote backends allow you to store the state file in a remote, shared store.

**run command:**

(aws) s3api create-bucket --bucket roles$(account)

(in this case we will create uniqe bucket for our terraform.tfstate file)

 * ***modify main.tf***: include s3 bucket name this need to be done for backend our terraform history you can use link bellow for documentation

https://developer.hashicorp.com/terraform/language/settings/backends/s3


 # We have created our main.tf file with all required configuration 
 Now we can start to create aws roles for documentation and example you can use link below

https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role

In this task we have followed terraform best practices and use module for centralized creation all required resources link below will help you understand how modules works more clearly,

https://developer.hashicorp.com/terraform/language/modules/sources

# To follow best practice we have to use  terraform variable for all  hard coded value 
Variables in Terraform are a great way to define centrally controlled reusable values. The information in Terraform variables is saved independently from the deployment plans, which makes the values easy to read and edit from a single file

![image](https://user-images.githubusercontent.com/114795949/209452961-4ed5d09f-ba00-4db2-a2e0-c38b3eb3fe63.png)


# Issue during compliting test

 * ***resources in defferent accounts***: our resources located in two different account in this case we will not be able to use same module for both resources as my permission have to be changed for each account make sure you switch credential for different account you should have stored credential at ~/.aws/configure file run command bellow with your profile name to change credentials

export AWS_PROFILE=profile_name


* ***permissions***: most of permissions needed in this are provided by AWS manged policy but some of them is not available by default we have to create them for this operation you can use AWS Policy Generator
linke for the website you can find bellow

https://awspolicygen.s3.amazonaws.com/policygen.html


* ***git ignore***: problem with git .gitignore file 
My .gitignore is working, but it still tracks the files because they were already in the index.

To stop this you have to do : git rm -r --cached file_name
