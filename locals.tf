locals {
  aws_limits = {
    dev  = 10 # insert your AWS budget limit for dev (integer)
    prod = 20 # insert your AWS budget limit for prod (integer)
  }

  snowflake_limits = {
    dev  = 100 # insert your Snowflake budget limit for dev (integer)
    prod = 200 # insert your Snowflake budget limit for prod (integer)
  }

  aws_limit = lookup(local.aws_limits, var.environment)
  snowflake_limit = lookup(local.snowflake_limits, var.environment)
}
