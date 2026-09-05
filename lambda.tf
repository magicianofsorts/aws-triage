data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/handler.py"
  output_path = "${path.module}/build/handler.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project}-triage"
  retention_in_days = 14
  tags              = { Project = var.project }
}

resource "aws_lambda_function" "triage" {
  function_name    = "${var.project}-triage"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      MODEL_ID   = var.model_id
      TABLE_NAME = aws_dynamodb_table.findings.name
      TOPIC_ARN  = aws_sns_topic.alerts.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
  tags       = { Project = var.project }
}
