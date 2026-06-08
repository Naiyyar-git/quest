# ─────────────────────────────────────────────
# LAMBDA 1 — SCRAPE BLS DIRECTORY
# discovers all filenames on BLS page dynamically
# returns file list to Step Functions
# ─────────────────────────────────────────────

resource "aws_lambda_function" "lambda_scrape" {
  filename         = "${path.module}/lambda_scrape.zip"
  function_name    = "rearc-quest-scrape-bls"
  role             = aws_iam_role.lambda_scrape.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60
  source_code_hash = filebase64sha256("${path.module}/lambda_scrape.zip")

  environment {
    variables = {
      USER_AGENT = var.user_agent
    }
  }

  tags = {
    Project = "rearc-data-quest"
  }
}

# ─────────────────────────────────────────────
# LAMBDA 2 — CHECK ETAG
# checks each file fingerprint against dynamodb
# returns only changed or new files
# ─────────────────────────────────────────────

resource "aws_lambda_function" "lambda_check_etag" {
  filename         = "${path.module}/lambda_check_etag.zip"
  function_name    = "rearc-quest-check-etag"
  role             = aws_iam_role.lambda_check_etag.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 120
  source_code_hash = filebase64sha256("${path.module}/lambda_check_etag.zip")

  environment {
    variables = {
      DYNAMO_TABLE = var.dynamodb_table_name
      USER_AGENT   = var.user_agent
    }
  }

  tags = {
    Project = "rearc-data-quest"
  }
}

# ─────────────────────────────────────────────
# LAMBDA 3 — SYNC FILES TO S3
# downloads changed files from BLS
# uploads raw bytes to S3 bronze layer
# updates dynamodb etag after each upload
# ─────────────────────────────────────────────

resource "aws_lambda_function" "lambda_sync_files" {
  filename         = "${path.module}/lambda_sync_files.zip"
  function_name    = "rearc-quest-sync-files"
  role             = aws_iam_role.lambda_sync_files.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 300
  source_code_hash = filebase64sha256("${path.module}/lambda_sync_files.zip")

  environment {
    variables = {
      S3_BUCKET    = var.s3_bucket_name
      DYNAMO_TABLE = var.dynamodb_table_name
      USER_AGENT   = var.user_agent
    }
  }

  tags = {
    Project = "rearc-data-quest"
  }
}

# ─────────────────────────────────────────────
# LAMBDA 4 — FETCH POPULATION API
# calls datausa.io population API
# saves JSON to S3 bronze/api/population.json
# this S3 write triggers SQS notification
# ─────────────────────────────────────────────

resource "aws_lambda_function" "lambda_fetch_api" {
  filename         = "${path.module}/lambda_fetch_api.zip"
  function_name    = "rearc-quest-fetch-api"
  role             = aws_iam_role.lambda_fetch_api.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60
  source_code_hash = filebase64sha256("${path.module}/lambda_fetch_api.zip")

  environment {
    variables = {
      S3_BUCKET = var.s3_bucket_name
    }
  }

  tags = {
    Project = "rearc-data-quest"
  }
}

# ─────────────────────────────────────────────
# LAMBDA 5 — ANALYTICS
# triggered by SQS when population.json lands
# loads both files from S3
# runs three analytics reports
# logs results to cloudwatch
# ─────────────────────────────────────────────

resource "aws_lambda_function" "lambda_analytics" {
  s3_bucket        = var.s3_bucket_name
  s3_key           = "lambda-packages/lambda_analytics.zip"
  function_name    = "rearc-quest-analytics"
  role             = aws_iam_role.lambda_analytics.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 300
  source_code_hash = filebase64sha256("${path.module}/lambda_analytics.zip")
  
  environment {
    variables = {
      S3_BUCKET    = var.s3_bucket_name
      DYNAMO_TABLE = var.dynamodb_table_name
    }
  }

  tags = {
    Project = "rearc-data-quest"
  }
}

# ─────────────────────────────────────────────
# SQS EVENT SOURCE MAPPING
# wires SQS queue to Lambda 5
# AWS polls SQS on our behalf
# invokes Lambda 5 when message arrives
# ─────────────────────────────────────────────

resource "aws_lambda_event_source_mapping" "sqs_to_analytics" {
  event_source_arn = aws_sqs_queue.analytics_queue.arn
  function_name    = aws_lambda_function.lambda_analytics.arn
  batch_size       = 1
  enabled          = true
}