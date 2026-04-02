variable "topic_name" {
  description = "Name of the SNS topic for participant notifications"
  type        = string
}

variable "notification_email" {
  description = "Email address to subscribe for registration confirmations"
  type        = string
  default     = ""
}

resource "aws_sns_topic" "notifications" {
  name = var.topic_name

  tags = {
    Name = var.topic_name
  }
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

output "topic_arn" {
  value = aws_sns_topic.notifications.arn
}

output "topic_name" {
  value = aws_sns_topic.notifications.name
}
