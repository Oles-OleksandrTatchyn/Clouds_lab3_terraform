provider "aws" {
  region = "eu-central-1"
}

locals {
  prefix             = "tatchyn-oles-19"
  notification_email = ""
}

module "logs_bucket" {
  source      = "../../modules/s3_logs"
  bucket_name = "${local.prefix}-lab5-logs"
}

module "database" {
  source     = "../../modules/dynamodb"
  table_name = "${local.prefix}-lab5-registrations"
}

module "notifications" {
  source             = "../../modules/sns"
  topic_name         = "${local.prefix}-lab5-notifications"
  notification_email = local.notification_email
}

module "backend" {
  source              = "../../modules/lambda"
  function_name       = "${local.prefix}-lab5-api-handler"
  source_file         = "${path.root}/../../src/app.py"
  dynamodb_table_arn  = module.database.table_arn
  dynamodb_table_name = module.database.table_name
  sns_topic_arn       = module.notifications.topic_arn
  log_bucket_name     = "${local.prefix}-lab5-logs"
}

module "api" {
  source               = "../../modules/api_gateway"
  api_name             = "${local.prefix}-lab5-http-api"
  lambda_invoke_arn    = module.backend.invoke_arn
  lambda_function_name = module.backend.function_name
}

output "api_url" {
  description = "Base URL of the deployed HTTP API"
  value       = module.api.api_endpoint
}

output "dynamodb_table" {
  description = "Name of the DynamoDB registrations table"
  value       = module.database.table_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS notifications topic"
  value       = module.notifications.topic_arn
}

output "logs_bucket" {
  description = "Name of the S3 logs bucket"
  value       = module.logs_bucket.bucket_name
}

output "usage" {
  description = "Quick reference for API endpoints"
  value       = <<-EOT
    POST ${module.api.api_endpoint}/registrations
      Body: {"name":"...", "email":"...", "event_id":"..."}
      → registers participant, detects language via Comprehend, stores in DynamoDB, sends SNS

    GET ${module.api.api_endpoint}/registrations/{id}/lang
      → returns detected language_code + confidence for a registration

    GET ${module.api.api_endpoint}/registrations/{event_id}/count
      → returns participant count for an event
  EOT
}
