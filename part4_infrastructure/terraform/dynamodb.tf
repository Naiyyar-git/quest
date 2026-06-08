# ─────────────────────────────────────────────
# DYNAMODB TABLE
# single table design — three record types
#
# FILE#filename    → BLS file ETag tracking
# MSG#message_id   → SQS message deduplication
# EXEC#date        → Step Functions audit trail
#
# PAY_PER_REQUEST billing — no minimum cost
# only pay for actual reads and writes
# ─────────────────────────────────────────────

resource "aws_dynamodb_table" "pipeline_metadata" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  # keep deleted items recoverable for 35 days
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Project     = "rearc-data-quest"
    Environment = "dev"
  }
}