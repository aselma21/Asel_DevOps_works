# devops-tools-22j-centos
Create Cloudwatch alarm for RDS in Versus and Exchange apps for prod and dev environments
1. Step #1
Create the main resources such as cloudwatch_metric_alarm
SNS_Topic name was used from the existing 
2. Step #2
Create two modules with db_instance_id for each app
Create two .tfvars files for dev and prod environment
3. Step #3
Run terraform init
    terraform plan -var-file="dev.tfvars"
    terraform apply -var-file="dev.tfvars"
