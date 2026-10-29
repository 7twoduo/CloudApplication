
# --------------------------------------------------
# 1. Lambda CloudWatch Log Group
# --------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  name = "/aws/lambda/${aws_lambda_function.tasks.function_name}"

  # Keep logs for 14 days to control storage costs.
  retention_in_days = 14

  tags = {
    Project   = "CloudApplication"
    ManagedBy = "Terraform"
  }
}

# --------------------------------------------------
# 2. Lambda Errors Alarm
# Triggers when at least one invocation fails.
# --------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name        = "${var.project_name}-lambda-errors"
  alarm_description = "Lambda invocation errors detected"

  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.tasks.function_name
  }

  tags = {
    Project = "CloudApplication"
  }
}

# --------------------------------------------------
# 3. Lambda Throttling Alarm
# Triggers when Lambda rejects an invocation
# because of concurrency or capacity limits.
# --------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name        = "${var.project_name}-lambda-throttles"
  alarm_description = "Lambda invocation throttles detected"

  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.tasks.function_name
  }

  tags = {
    Project = "CloudApplication"
  }
}

# --------------------------------------------------
# 4. Lambda Slow Execution Alarm
# Triggers when maximum execution time reaches
# 8 seconds. Your Lambda timeout is 10 seconds.
# --------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name        = "${var.project_name}-lambda-slow"
  alarm_description = "Lambda execution reached 8 seconds"

  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 8000
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.tasks.function_name
  }

  tags = {
    Project = "CloudApplication"
  }
}
