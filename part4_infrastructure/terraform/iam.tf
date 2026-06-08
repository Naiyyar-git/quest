# ─────────────────────────────────────────────
# IAM ROLE — LAMBDA 1 SCRAPE
# only needs cloudwatch — just scrapes a webpage
# no S3 or DynamoDB access needed
# ─────────────────────────────────────────────

resource "aws_iam_role" "lambda_scrape" {
  name = "rearc-quest-lambda-scrape-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_scrape" {
  name = "rearc-quest-lambda-scrape-policy"
  role = aws_iam_role.lambda_scrape.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# IAM ROLE — LAMBDA 2 CHECK ETAG
# needs dynamodb read and cloudwatch
# ─────────────────────────────────────────────

resource "aws_iam_role" "lambda_check_etag" {
  name = "rearc-quest-lambda-check-etag-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_check_etag" {
  name = "rearc-quest-lambda-check-etag-policy"
  role = aws_iam_role.lambda_check_etag.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem"]
        Resource = aws_dynamodb_table.pipeline_metadata.arn
      },
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# IAM ROLE — LAMBDA 3 SYNC FILES
# needs S3 read write list and dynamodb write
# ─────────────────────────────────────────────

resource "aws_iam_role" "lambda_sync_files" {
  name = "rearc-quest-lambda-sync-files-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_sync_files" {
  name = "rearc-quest-lambda-sync-files-policy"
  role = aws_iam_role.lambda_sync_files.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.rearc_quest.arn,
          "${aws_s3_bucket.rearc_quest.arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.pipeline_metadata.arn
      },
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# IAM ROLE — LAMBDA 4 FETCH API
# needs S3 write and cloudwatch only
# ─────────────────────────────────────────────

resource "aws_iam_role" "lambda_fetch_api" {
  name = "rearc-quest-lambda-fetch-api-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_fetch_api" {
  name = "rearc-quest-lambda-fetch-api-policy"
  role = aws_iam_role.lambda_fetch_api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.rearc_quest.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# IAM ROLE — LAMBDA 5 ANALYTICS
# needs S3 read, SQS read and delete, dynamodb read write
# ─────────────────────────────────────────────

resource "aws_iam_role" "lambda_analytics" {
  name = "rearc-quest-lambda-analytics-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_analytics" {
  name = "rearc-quest-lambda-analytics-policy"
  role = aws_iam_role.lambda_analytics.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.rearc_quest.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.analytics_queue.arn
      },
      {
        Effect   = "Allow"
        Action   = [
          "dynamodb:GetItem",
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.pipeline_metadata.arn
      },
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# IAM ROLE — STEP FUNCTIONS
# allows step functions to invoke all 4 ingest lambdas
# ─────────────────────────────────────────────

resource "aws_iam_role" "step_functions" {
  name = "rearc-quest-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "step_functions" {
  name = "rearc-quest-step-functions-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = [
          aws_lambda_function.lambda_scrape.arn,
          aws_lambda_function.lambda_check_etag.arn,
          aws_lambda_function.lambda_sync_files.arn,
          aws_lambda_function.lambda_fetch_api.arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogDelivery",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# IAM ROLE — EVENTBRIDGE
# allows eventbridge to start step functions execution
# ─────────────────────────────────────────────

resource "aws_iam_role" "eventbridge" {
  name = "rearc-quest-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge" {
  name = "rearc-quest-eventbridge-policy"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = aws_sfn_state_machine.ingest_pipeline.arn
      }
    ]
  })
}