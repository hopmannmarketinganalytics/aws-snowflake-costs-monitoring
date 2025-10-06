variable "region" {
  description = "region"
  type        = string
  default     = "eu-central-1"
}

variable "budget_alert_emails" {
  type    = list(string)
  default = [
    "your-first-email-address",
    "your-second-email-address",
  ]
}

variable "environment" {
  description = "environment - dev or prod"
  type        = string
}
