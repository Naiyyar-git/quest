# ─────────────────────────────────────────────
# EVENTBRIDGE RULE
# daily schedule that fires at midnight UTC
# cron(minutes hours day month weekday year)
# cron(0 0 * * ? *) = every day at 00:00 UTC
# ─────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "daily_schedule" {
  name                = "rearc-quest-daily-schedule"
  description         = "triggers rearc quest ingest pipeline daily at midnight UTC"
  schedule_expression = var.schedule_expression

  tags = {
    Project     = "rearc-data-quest"
    Environment = "dev"
  }
}

# ─────────────────────────────────────────────
# EVENTBRIDGE TARGET
# points the daily schedule at Step Functions
# passes execution name with date for idempotency
# same date = same execution name = rejected by AWS
# prevents duplicate runs on same day
# ─────────────────────────────────────────────

resource "aws_cloudwatch_event_target" "step_functions_target" {
  rule     = aws_cloudwatch_event_rule.daily_schedule.name
  arn      = aws_sfn_state_machine.ingest_pipeline.arn
  role_arn = aws_iam_role.eventbridge.arn

  # execution name includes date for idempotency
  # format: bls-sync-2026-06-07
  input_transformer {
    input_paths = {
      time = "$.time"
    }
    input_template = <<EOF
{
  "execution_name": "bls-sync-<time>",
  "scheduled": true
}
EOF
  }
}