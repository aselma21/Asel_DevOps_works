# Create an IAM role for the SNS with access to CloudWatch
resource "aws_iam_role" "sns_logs" {
  name = "sns-logs"
	
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# Allow SNS to write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "sns_logs" {
  role       = aws_iam_role.sns_logs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSNSRole"
}

# Create an SNS topic to receive notifications from CloudWatch
resource "aws_sns_topic" "alarms" {
  name  = "alarms" 
  
  # Important! Only for testing, set to log every single message 
  # For production, set it to 0 or close
  lambda_success_feedback_sample_rate = 0
  lambda_failure_feedback_role_arn = aws_iam_role.sns_logs.arn
  lambda_success_feedback_role_arn = aws_iam_role.sns_logs.arn	
  tags = merge(var.tags, var.sns_topic_tags)
}

# Generate a random string to create a unique S3 bucket
resource "random_pet" "lambda_bucket_name" {
  prefix = "lambda"
  length = 2
}

# Create an S3 bucket to store lambda source code (zip archives)
resource "aws_s3_bucket" "lambda_bucket" {
  bucket        = random_pet.lambda_bucket_name.id
  force_destroy = true
}

# Disable all public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create an IAM role for the lambda function
resource "aws_iam_role" "send_cloudwatch_alarms_to_slack" {
  name = "send-cloudwatch-alarms-to-slack"
# Terraform's "jsonencode" function converts a
# Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# Allow lambda to write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "send_cloudwatch_alarms_to_slack_basic" {
  role       = aws_iam_role.send_cloudwatch_alarms_to_slack.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create ZIP archive with a lambda function
data "archive_file" "notify_py" {
	type = "zip"
	source_file = "./lambda/asgSlackNotifications.py"
	output_path = "./lambda/asgSlackNotifications.zip"
}

# Upload ZIP archive with lambda to S3 bucket
resource "aws_s3_object" "asgSlackNotifications" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "asgSlackNotifications.zip"
  source = data.archive_file.notify_py.output_path
  etag = filemd5(data.archive_file.notify_py.output_path)
  tags = {
    Name        = "My bucket"
    Environment = "prod"
  }
}

# Create lambda function using ZIP archive from S3 bucket
resource "aws_lambda_function" "slack_notification" {
  function_name = "slack_notification"
  description   = "notify slack channel on sns topic"
  s3_bucket     = aws_s3_bucket.lambda_bucket.id
  s3_key        = aws_s3_object.asgSlackNotifications.key
  runtime       = var.runtime
  handler       = var.lambda_handler
  memory_size   = var.memory_size
  timeout       = var.timeout
  publish       = var.publish
  source_code_hash = data.archive_file.notify_py.output_base64sha256
  role = aws_iam_role.send_cloudwatch_alarms_to_slack.arn
  
  environment {
    variables = {
      SLACK_CHANNEL = "${var.slack_channel}"
      SLACK_WEBHOOK = "${var.slack_webhook_url}"
    }
  }
} 

# Create CloudWatch log group with 2 weeks retention policy
resource "aws_cloudwatch_log_group" "asg_scale_up_alarm" {
  name = "/aws/lambda/${aws_lambda_function.slack_notification.function_name}"
  retention_in_days = var.retention_in_days
  tags = merge(var.tags, var.cloudwatch_log_group_tags)
}

# Grant access to SNS topic to invoke a lambda function
# To allow Lambda to be executed from the SNS service, add a permission: 
resource "aws_lambda_permission" "sns_alarms" {
  statement_id  = "AllowExecutionFromSNSAlarms"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notification.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alarms.arn
}

# Trigger lambda function when a message is published to "alarms" topic
# To get notified by SNS, the Lambda functions subscribes to the SNS topic
resource "aws_sns_topic_subscription" "alarms" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notification.arn
}

# Define CloudWatch Alarms for Autoscaling Groups
# scale up policy
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "asg_scale_up"
  autoscaling_group_name = data.aws_autoscaling_group.eks-centos-node-groupe-4ec29b4d-24ce-30b3-c1dc-5e3b8b17e463.id
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = var.scale_up_adjustment #increasing instance by 1
  cooldown               = var.scale_up_cooldown #Period (in seconds) to wait between scale down events
  policy_type            = var.policy_type
}

# CloudWatch Alarm to trigger the above scaling policy when CPU Utilization is more than 20%
resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "asg_scale_up_alarm"
  alarm_description   = "asg_scale_up_cpu_alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2" ##Amazon EC2 instance metrics that collect CPU and other usage data from Auto Scaling instances are in the AWS/EC2 namespace.
  period              = var.period_up_alarm ##The period in seconds over which the specified statistic is applied. 
  statistic           = "Average"
  threshold           = var.threshold_up_alarm ##The value against which the specified statistic is compared.  
  dimensions = {
    "AutoScalingGroupName" = data.aws_autoscaling_group.eks-centos-node-groupe-4ec29b4d-24ce-30b3-c1dc-5e3b8b17e463.id
  }
  actions_enabled = true
  alarm_actions   = [
    aws_autoscaling_policy.scale_down.arn,
    aws_sns_topic.alarms.arn ]
}

# scale down policy
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "asg-scale-down"
  autoscaling_group_name = data.aws_autoscaling_group.eks-centos-node-groupe-4ec29b4d-24ce-30b3-c1dc-5e3b8b17e463.id
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = var.scale_down_adjustment # decreasing instance by 1
  cooldown               = var.scale_down_cooldown #Period (in seconds) to wait between scale down events
  policy_type            = var.policy_type 
}

# Cloud Watch Alarm to trigger the above scaling policy when CPU Utilization is above 5%
resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "asg-scale-down-alarm"
  alarm_description   = "asg-scale-down-cpu-alarm"
  comparison_operator = "LessThanOrEqualToThreshold" 
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2" #Amazon EC2 instance metrics that collect CPU and other usage data from Auto Scaling instances are in the AWS/EC2 namespace.
  period              = var.period_down_alarm #The period in seconds over which the specified statistic is applied. 
  statistic           = "Average"
  threshold           = var.threshold_down_alarm #The value against which the specified statistic is compared.  
  dimensions = {
    "AutoScalingGroupName" = data.aws_autoscaling_group.eks-centos-node-groupe-4ec29b4d-24ce-30b3-c1dc-5e3b8b17e463.id
  }
  actions_enabled = true
  alarm_actions     = [
    aws_autoscaling_policy.scale_down.arn,
    aws_sns_topic.alarms.arn]
}
  

  










