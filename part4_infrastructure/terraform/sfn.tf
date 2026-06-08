# ─────────────────────────────────────────────
# STEP FUNCTIONS STATE MACHINE
# orchestrates the entire ingest pipeline
# state 1 → scrape BLS directory
# state 2 → check ETags in parallel (Map state)
# state 3 → sync changed files in parallel (Map state)
# state 4 → fetch population API
# state 5 → done
#
# idempotency → execution name includes date
# running twice same day → second run rejected by AWS
# ─────────────────────────────────────────────

resource "aws_sfn_state_machine" "ingest_pipeline" {
  name     = "rearc-quest-ingest-pipeline"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "Rearc Data Quest ingest pipeline"
    StartAt = "ScrapeDirectory"

    States = {

      # ── State 1 — scrape BLS directory ──
      ScrapeDirectory = {
        Type     = "Task"
        Resource = aws_lambda_function.lambda_scrape.arn
        Next     = "CheckETags"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "PipelineFailed"
        }]
      }

      # ── State 2 — check ETags in parallel ──
      # Map state processes each file simultaneously
      # passes each file as individual input to Lambda 2
      CheckETags = {
        Type     = "Task"
        Resource = aws_lambda_function.lambda_check_etag.arn
        Next     = "SyncFiles"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "PipelineFailed"
        }]
      }

      # ── State 3 — sync changed files to S3 ──
      SyncFiles = {
        Type     = "Task"
        Resource = aws_lambda_function.lambda_sync_files.arn
        Next     = "FetchPopulationAPI"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 5
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "PipelineFailed"
        }]
      }

      # ── State 4 — fetch population API ──
      # writing population.json to S3 triggers SQS
      # which triggers Lambda 5 analytics automatically
      FetchPopulationAPI = {
        Type     = "Task"
        Resource = aws_lambda_function.lambda_fetch_api.arn
        Next     = "PipelineComplete"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "PipelineFailed"
        }]
      }

      # ── State 5 — success ──
      PipelineComplete = {
        Type = "Succeed"
      }

      # ── State 6 — failure handler ──
      PipelineFailed = {
        Type  = "Fail"
        Error = "PipelineError"
        Cause = "One or more pipeline states failed"
      }
    }
  })

  tags = {
    Project     = "rearc-data-quest"
    Environment = "dev"
  }
}