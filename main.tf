terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_guardduty_detector" "main" {}

resource "aws_dynamodb_table" "findings" {
  name         = "${var.project}-findings"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "finding_id"

  attribute {
    name = "finding_id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  tags = { Project = var.project }
}

resource "aws_sns_topic" "alerts" {
  name = "${var.project}-alerts"
  tags = { Project = var.project }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${var.project}-guardduty-findings"
  description = "Route GuardDuty findings to the triage Lambda"

  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
  })

  tags = { Project = var.project }
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "triage-lambda"
  arn       = aws_lambda_function.triage.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.triage.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_findings.arn
}
