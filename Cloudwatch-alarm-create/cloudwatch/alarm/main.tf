terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.48.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_cloudwatch_metric_alarm" "db_high_cpu" {
  alarm_name          = var.alarm_name
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Maximum"
  threshold           = "80"
  actions_enabled     = "true"
  alarm_actions       = [data.aws_sns_topic.rds_alarm.arn]
  ok_actions          = [data.aws_sns_topic.rds_alarm.arn] 
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
}
data "aws_sns_topic""rds_alarm" {
  name = "HighPriority-CPUUtilizationExceeded"
}
variable "db_instance_id" {}
variable "alarm_name" {}
