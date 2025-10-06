locals {
  account_ids = {
    dev  = "123456789012" # insert-your-dev-aws-account
    prod = "123456789013" # insert-your-prod-aws-account
  }
}

locals {
  aws_limits = {
    dev  = 10 # insert your aws limit for dev as integer
    prod = 20 # insert your aws limit for prod as integer
  }

  snowflake_limits = {
    dev  = 100 # insert your snowflake aws limit for dev as integer
    prod = 200 # insert your snowflake aws limit for prod as integer
  }

  aws_limit = lookup(local.aws_limits, var.environment)
  snowflake_limit = lookup(local.snowflake_limits, var.environment)
}
