variable "aws_region" {
  description = "The AWS region in which the AWS infrastructure is created."
  type        = string
  default     = "us-east-1"
}

variable "retention_in_days" {
  description = "Specifies the number of days you want to retain log events in log group for Lambda."
  type        = number
  default     = 14
}

variable "timeout" {
  default     = 3
  type        = number
  description = "Number of seconds that the function can run before timing out. The AWS default is 3s and the maximum runtime is 5m"
}

variable "runtime" {
  type        = string
  default     = "python3.9"
  description = "Lambda runtime to use for the function."
}

variable "memory_size" {
  description = "Amount of memory in MB your Lambda Function can use at runtime. Valid value between 128 MB to 10,240 MB (10 GB), in 64 MB increments."
  type        = number
  default     = 128
}

variable "lambda_handler" {
  description = "handler name"
  type        = string
  default     = "asgSlackNotifications.lambda_handler"
}

variable "publish" {
  description = "(Optional) Whether to publish creation/change as new Lambda function. This allows you to use aliases to refer to execute different versions of the function in different environments."
  type        = bool
  default     = false
}

variable "sns_topic_name" {
  description = "The name of the SNS topic to create"
  type        = string
}

variable "scale_down_cooldown" {
  type        = number
  description = "Period (in seconds) to wait between scale down events"
  default     = 300
}

variable "scale_up_cooldown" {
  type        = number
  description = "Period (in seconds) to wait between scale down events"
  default     = 300
}

variable "scale_up_adjustment" {
  type        = number
  description = "Scaling adjustment to make during scale up event"
  default     = 1 #increasing instance by 1
}


variable "scale_down_adjustment" {
  type        = number
  description = "Scaling adjustment to make during scale down event" 
  default     = -1 # decreasing instance by 1
}

variable "slack_webhook_url" {
  description = "The URL of Slack webhook"
  type        = string
  default     = "https://hooks.slack.com/services/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"
}

variable "slack_channel" {
  description = "The name of the channel in Slack for notifications"
  type        = string
  default     = "alarm"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "sns_topic_tags" {
  description = "Additional tags for the SNS topic"
  type        = map(string)
  default     = {}
}

variable "cloudwatch_log_group_tags" {
  description = "Additional tags for the Cloudwatch log group"
  type        = map(string)
  default     = {}
}

variable "threshold_up_alarm" {
  type        = number
  default     = 20 # New instance will be created once CPU utilization is higher than 20 %
  description = "The value against which the specified statistic is compared."
}

variable "threshold_down_alarm" {
  type        = number
  default     = 5 # Instance will scale down when CPU utilization is lower than 5 %
  description = "The value against which the specified statistic is compared."
}

variable "period_up_alarm" {
  type        = string
  default     = 120
  description = "The period in seconds over which the specified statistic is applied."
}

variable "period_down_alarm" {
  type        = string
  default     = 120
  description = "The period in seconds over which the specified statistic is applied."
}

variable "policy_type" {
  type        = string
  default     = "SimpleScaling"
  description = "The scaling policy type."
}
