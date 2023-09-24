# ARCHITECTURE

The eks autoscaling group will periodically send its CPU usage to CloudWatch. Once the CPU usage crosses a particular threshold (20% for testing purpuses), the CloudWatch alarm goes from “OK” to “In Alarm”. When this happens, a message is sent to an SNS topic which in turn triggers a lambda function and sends a notification to the slack workspace.

<img width="700" alt="Screen Shot 2023-01-12 at 9 12 36 PM" src="https://user-images.githubusercontent.com/114625779/212380469-fc59e106-2a27-4d4b-a055-50d81ff2946b.png">




STRUCTURE

1. Create a Slack app: First, we need to need to create a Slack app at https://api.slack.com/apps/new and set a development workspace for the application. When the Slack app is created, the next step is to activate incoming webhooks. 
<img width="1198" alt="Screen Shot 2023-01-12 at 9 02 37 PM" src="https://user-images.githubusercontent.com/114625779/212220136-81fea2d1-435b-4cc9-bd05-f9d7413397aa.png">

2.Next, we are going to create an SNS topic that will be responsible for receiving the cloudwatch messages when the CPU usage of our autoscaling group crosses a certain threshold.

3.Create autoscaling group policy, Next we are going to create a CloudWatch alarm to receive metrics from the autoscaling group.

4.Create the Lambda Function: The next step is to create the lambda function that will push the high alarm notifications to slack before we create a Lambda function, we need to create an IAM execution role for our function. 

5.The next step is to add a trigger to our function. Triggers are services that execute the functions they are attached when a specified condition is met. We will select the SNS topic that receives messages from CloudWatch as our trigger. 


Testing 
Stress is a Simple command-line utility used to conduct CPU memory and disk tests. Now, we have to install some extra Linux packages in our instance in order to make this utility available. Afterwhich we would install stress. 

# Install Extra Packages for Enterprise Linux
sudo amazon-linux-extras install epel
# Install stress
sudo yum install -y stress

Now, we’re going to beat up the CPU for 5 mins with the code below.

# Beat it up for 5 mins
stress --cpu 2 --timeout 600s


Notification on slack when Lambda was triggered.
<img width="1664" alt="Screen Shot 2023-01-18 at 12 37 25 PM" src="https://user-images.githubusercontent.com/114625779/213260855-d998edc1-2037-4512-a748-9eabc4302946.png">



Usage
# To run this you need to execute:

$ terraform init

$ terraform plan

$ terraform apply


# Requirements
# Name	Version
terraform	>= 1.3.7

aws	>= 4.39.0


# Providers
# Name	Version
aws	>= 4.39.0


