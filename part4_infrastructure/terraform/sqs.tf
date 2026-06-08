# ─────────────────────────────────────────────
# SQS QUEUE
# receives notification from S3 when
# population.json is written to bronze/api/
# holds message until Lambda 5 processes it
# guarantees at-least-once delivery
# ─────────────────────────────────────────────

resource "aws_sqs_queue" "analytics_queue" {
  name                       = var.sqs_queue_name

  # how long message stays invisible after Lambda receives it
  # gives Lambda 5 time to process before SQS retries
  visibility_timeout_seconds = 300

  # how long message stays in queue if never processed
  message_retention_seconds  = 86400  # 1 day

  # how long to wait for a message before returning empty
  receive_wait_time_seconds  = 20     # long polling — cheaper than short polling

  tags = {
    Project     = "rearc-data-quest"
    Environment = "dev"
  }
}

# ─────────────────────────────────────────────
# SQS QUEUE POLICY
# explicitly allows S3 to send messages to this queue
# without this policy S3 event notification is rejected
# this is the most commonly forgotten resource
# ─────────────────────────────────────────────

resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.analytics_queue.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3ToSendMessages"
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.analytics_queue.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.rearc_quest.arn
          }
        }
      }
    ]
  })
}