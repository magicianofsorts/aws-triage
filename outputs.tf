output "lambda_function_name" {
  value = aws_lambda_function.triage.function_name
}

output "dynamodb_table" {
  value = aws_dynamodb_table.findings.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "detector_id" {
  description = "Use this with: aws guardduty create-sample-findings --detector-id <id>"
  value       = data.aws_guardduty_detector.main.id
}
