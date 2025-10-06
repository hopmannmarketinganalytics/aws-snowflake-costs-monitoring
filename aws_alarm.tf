#-----------------------------------------------------------
# AWS cost alarm
#-----------------------------------------------------------

provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}
# ---------- SNS Topic for Budget Alerts ----------

resource "aws_sns_topic_subscription" "aws_budget_emails" {
  # Email subscriptions for AWS budget alerts
  provider  = aws.us_east
  for_each  = toset(var.budget_alert_emails)

  topic_arn = aws_sns_topic.aws_budget_alerts.arn
  protocol  = "email"
  endpoint  = each.value

  depends_on = [aws_sns_topic.aws_budget_alerts]
}

resource "aws_sns_topic" "aws_budget_alerts" {
  # AWS SNS topic for AWS budget notifications
  provider = aws.us_east
  name     = "aws-budget-alerts-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowBudgetsToPublish",
        Effect    = "Allow",
        Principal = {
          Service = "budgets.amazonaws.com"
        },
        Action   = "SNS:Publish",
        Resource = "*"
      }
    ]
  })
}

# ---------- AWS Monthly Budget ----------
resource "aws_budgets_budget" "aws_monthly_cost_budget" {
  provider = aws.us_east
  name              = "aws-monthly-cost-budget-${var.environment}"
  budget_type       = "COST"
  limit_amount      = local.aws_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"   # resets at the start of each month

  cost_types {
    include_credit        = true
    include_discount      = true
    include_refund        = true
    include_subscription  = true
    include_support       = true
    include_tax           = true
    include_upfront       = true
    use_amortized         = false
    use_blended           = false
  }

  # Notification when ACTUAL spend > 130% of budget
  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 130
    threshold_type      = "PERCENTAGE"
    notification_type   = "ACTUAL"

    subscriber_sns_topic_arns = [
      aws_sns_topic.aws_budget_alerts.arn
    ]
  }
}
