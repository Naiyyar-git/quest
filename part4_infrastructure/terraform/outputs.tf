# ─────────────────────────────────────────────
# OUTPUTS
# values printed after terraform apply completes
# useful for verifying what was created
# and for wiring resources together manually if needed
# ─────────────────────────────────────────────

output "s3_bucket_name" {
  description = "S3 bucket where raw data lands"
  value       = aws_s3_bucket.rearc_quest.bucket
}

output "dynamodb_table_name" {
  description = "DynamoDB table for pipeline metadata"
  value       = aws_dynamodb_table.pipeline_metadata.name
}

output "sqs_queue_url" {
  description = "SQS queue URL for analytics trigger"
  value       = aws_sqs_queue.analytics_queue.url
}

output "sqs_queue_arn" {
  description = "SQS queue ARN"
  value       = aws_sqs_queue.analytics_queue.arn
}

output "state_machine_arn" {
  description = "Step Functions state machine ARN"
  value       = aws_sfn_state_machine.ingest_pipeline.arn
}

output "lambda_scrape_arn" {
  description = "Lambda 1 scrape BLS directory ARN"
  value       = aws_lambda_function.lambda_scrape.arn
}

output "lambda_check_etag_arn" {
  description = "Lambda 2 check ETag ARN"
  value       = aws_lambda_function.lambda_check_etag.arn
}

output "lambda_sync_files_arn" {
  description = "Lambda 3 sync files to S3 ARN"
  value       = aws_lambda_function.lambda_sync_files.arn
}

output "lambda_fetch_api_arn" {
  description = "Lambda 4 fetch population API ARN"
  value       = aws_lambda_function.lambda_fetch_api.arn
}

output "lambda_analytics_arn" {
  description = "Lambda 5 analytics ARN"
  value       = aws_lambda_function.lambda_analytics.arn
}

output "eventbridge_rule_arn" {
  description = "EventBridge daily schedule rule ARN"
  value       = aws_cloudwatch_event_rule.daily_schedule.arn
}