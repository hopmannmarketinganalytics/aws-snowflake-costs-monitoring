#-----------------------------------------------------------
# Snowflake cost alarm
#-----------------------------------------------------------

# ---------- SNS Topic for Alerts ----------
resource "aws_sns_topic" "snowflake_budget_alerts" {
  # AWS SNS topic for Snowflake budget notifications
  name     = "snowflake-budget-alerts-${var.environment}"
}

resource "aws_sns_topic_subscription" "snowflake_budget_email" {
  # Email subscriptions for Snowflake budget alerts
  for_each  = toset(var.budget_alert_emails)
  topic_arn = aws_sns_topic.snowflake_budget_alerts.arn
  protocol  = "email"
  endpoint  = each.value

  depends_on = [aws_sns_topic.snowflake_budget_alerts]
}

# ---------- IAM Role for Lambda ----------
resource "aws_iam_role" "lambda_role" {
  name = "snowflake-cost-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "sns_publish" {
  name     = "sns-publish"
  role     = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.snowflake_budget_alerts.arn
    }]
  })
}

resource "aws_iam_role_policy" "ssm_access" {
  name     = "ssm-parameter-access"
  role     = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = "arn:aws:ssm:*:${local.account_ids[var.environment]}:parameter/snowflake_cost_alarm"
    }]
  })
}

# ---------- Lambda Function ----------
resource "aws_lambda_function" "snowflake_cost_checker" {
  function_name = "Snowflake-cost-checker"
  handler       = "src.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_role.arn
  timeout       = 60

  filename         = "lambda_package.zip"
  source_code_hash = filebase64sha256("lambda_package.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN  = aws_sns_topic.snowflake_budget_alerts.arn
      THRESHOLD_COST = local.snowflake_limit
      SSM_PARAM_NAME = "/snowflake_cost_alarm"
      ENVIRONMENT = var.environment
    }
  }
}

# ---------- EventBridge Rule ----------
resource "aws_cloudwatch_event_rule" "daily" {
  name                = "snowflake-cost-checker-daily"
  description         = "Triggers Snowflake cost checker Lambda every day at 10:00 UTC"
  schedule_expression = "cron(0 10 * * ? *)"
}

# ---------- EventBridge Target ----------
resource "aws_cloudwatch_event_target" "lambda_trigger" {
  rule      = aws_cloudwatch_event_rule.daily.name
  target_id = "SnowflakeCostCheckerLambda"
  arn       = aws_lambda_function.snowflake_cost_checker.arn
}

# ---------- Lambda Permission for EventBridge ----------
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snowflake_cost_checker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily.arn
}

