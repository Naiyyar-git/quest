# Rearc Data Quest — Solution

Data pipeline that ingests BLS labor statistics and US population data,
stores raw files in S3, runs analytics, and automates everything on AWS.

## Structure

part1_bls/                    BLS ingestion — 4 Lambda functions
  lambda_scrape/              discovers files from BLS directory
  lambda_check_etag/          checks if files changed via ETag
  lambda_sync_files/          downloads and uploads to S3
  lambda_fetch_api/           fetches population API to S3
part2_api/                    population API local test script
part3_analytics/              analytics notebook and Lambda
  analytics.ipynb             Part 3 reports with all outputs
  lambda_analytics/           analytics Lambda triggered by SQS
part4_infrastructure/terraform/   all AWS infrastructure as code
docs/                         architecture diagram

## Architecture

EventBridge daily schedule triggers Step Functions state machine
which orcheses 4 ingest Lambdas in sequence. Population JSON
landing in S3 triggers SQS which triggers the analytics Lambda.

Key decisions:
- Step Functions for orchestration with per-state retry logic
- ETag comparison in DynamoDB prevents re-uploading unchanged files
- S3 event notification pushes to SQS — analytics runs automatically
- Left join on year — nulls for BLS rows with no population data
- Single DynamoDB table for file metadata and SQS deduplication

## S3 Data

s3://rearc-quest-naiyyar/bronze/bls/        BLS CSV files
s3://rearc-quest-naiyyar/bronze/api/        population JSON

## How to deploy

cd part4_infrastructure/terraform
terraform init
terraform plan
terraform apply

Requires AWS CLI configured with appropriate permissions.
Analytics Lambda uses AWSSDKPandas-Python311 layer for pandas.

## Analytics results

All three reports in part3_analytics/analytics.ipynb with full outputs.
Also visible in CloudWatch Logs under /aws/lambda/rearc-quest-analytics

Report 1 — mean population 2013-2018: 3,808 std: 4,158,441
Report 2 — best year per series across 282 series IDs
Report 3 — PRS30006032 Q01 joined with population by year — 32 rows

## AI usage

Used Claude as a reference tool for architecture decisions, AWS service
wiring, and code structure. All design decisions reasoned through
independently — pipeline sequencing, IAM scoping, join strategy, and
idempotency approach. Every component tested and verified end to end.
