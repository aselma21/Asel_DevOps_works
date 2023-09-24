Task:

Using the IaC tool  create a free-tier VM in AWS that meets the
following objectives:
● The instance should use a 1 GB attached block storage volume and contain a valid
partition table with one partition. The partition should contain a valid file system.
● The filesystem residing on the attached volume should be mounted automatically upon
reboot of the instance.
● The instance should serve web pages via an appropriate service such as Apache, Nginx
or IIS. This service should start automatically upon boot.
● The instance should serve a web page index.html containing the text “Hello World”.
This file should reside on the filesystem within the attached volume and be served from
the Document Root directory.
● The instance should effectively use security groups to restrict traffic to HTTP and either
RDP or SSH.
● The instance should be associated with a static IP address.
For this task I used Terraform as IaC tool, created EC2 instance on AWS Cloud. 


Terraform

is an open-source infrastructure as code software tool that provides a consistent CLI workflow to manage hundreds of cloud services. Terraform codifies cloud APIs into declarative configuration files.

Usage
To run this example you need to execute:

$ terraform init
$ terraform plan
$ terraform apply

Requirements
Name	Version
terraform	>= 0.13.1
aws	>= 3.72
