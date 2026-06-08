# ─────────────────────────────────────────────
# S3 BUCKET
# stores all raw data in bronze layer
# bronze/bls/     → BLS CSV files
# bronze/api/     → population JSON file
# ─────────────────────────────────────────────

resource "aws_s3_bucket" "rearc_quest" {
  bucket = var.s3_bucket_name

  tags = {
    Project     = "rearc-data-quest"
    Environment = "dev"
  }
}

# ─────────────────────────────────────────────
# S3 BUCKET VERSIONING
# keeps previous versions of files
# useful for recovery if data gets corrupted
# ─────────────────────────────────────────────

resource "aws_s3_bucket_versioning" "rearc_quest" {
  bucket = aws_s3_bucket.rearc_quest.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ─────────────────────────────────────────────
# S3 EVENT NOTIFICATION
# watches for population.json being written
# pushes notification to SQS automatically
# this triggers the analytics chain
# ─────────────────────────────────────────────

resource "aws_s3_bucket_notification" "population_json_notification" {
  bucket = aws_s3_bucket.rearc_quest.id

  queue {
    queue_arn     = aws_sqs_queue.analytics_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "bronze/api/"
    filter_suffix = ".json"
  }

  # notification depends on SQS queue policy existing first
  # otherwise S3 cannot send to SQS
  depends_on = [aws_sqs_queue_policy.allow_s3]
}