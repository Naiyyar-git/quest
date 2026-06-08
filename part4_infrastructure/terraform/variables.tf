# ─────────────────────────────────────────────
# VARIABLES
# all configurable values in one place
# change these to deploy to a different account
# or region without touching any other file
# ─────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-west-2"
}

variable "s3_bucket_name" {
  description = "S3 bucket for raw BLS and population data"
  type        = string
  default     = "rearc-quest-naiyyar"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table for pipeline metadata and idempotency"
  type        = string
  default     = "pipeline_metadata"
}

variable "sqs_queue_name" {
  description = "SQS queue that receives S3 event notifications"
  type        = string
  default     = "rearc-quest-analytics-queue"
}

variable "user_agent" {
  description = "User agent string for BLS HTTP requests"
  type        = string
  default     = "naiyyar@outlook.com - Rearc Data Quest pipeline"
}

variable "schedule_expression" {
  description = "EventBridge schedule for daily pipeline run"
  type        = string
  default     = "cron(0 0 * * ? *)"
}