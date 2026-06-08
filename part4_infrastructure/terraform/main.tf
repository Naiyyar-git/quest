# ─────────────────────────────────────────────
# TERRAFORM CONFIGURATION
# tells terraform we are using AWS provider
# and which version to use
# ─────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

# ─────────────────────────────────────────────
# AWS PROVIDER
# tells terraform which region to deploy to
# credentials come from aws cli configuration
# no hardcoded keys ever
# ─────────────────────────────────────────────

provider "aws" {
  region = var.aws_region
}