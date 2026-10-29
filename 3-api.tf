
# --------------------------------------------------
# 1. Public HTTP API
# --------------------------------------------------

resource "aws_apigatewayv2_api" "tasks" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  tags = {
    Project   = "CloudApplication"
    ManagedBy = "Terraform"
  }
}

# --------------------------------------------------
# 2. Connect API Gateway to the Lambda function
# --------------------------------------------------

resource "aws_apigatewayv2_integration" "lambda" {
  api_id = aws_apigatewayv2_api.tasks.id

  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.tasks.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 10000
}

# --------------------------------------------------
# 3. API Routes
# --------------------------------------------------
# Public browser-based Task API tester.
resource "aws_apigatewayv2_route" "home" {
  api_id    = aws_apigatewayv2_api.tasks.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# GET /health
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.tasks.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# POST /tasks
resource "aws_apigatewayv2_route" "create_task" {
  api_id    = aws_apigatewayv2_api.tasks.id
  route_key = "POST /tasks"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# GET /tasks/{id}
resource "aws_apigatewayv2_route" "get_task" {
  api_id    = aws_apigatewayv2_api.tasks.id
  route_key = "GET /tasks/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# --------------------------------------------------
# 4. Default Stage
# --------------------------------------------------

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.tasks.id
  name        = "$default"
  auto_deploy = true
}

# --------------------------------------------------
# 5. Allow API Gateway to Invoke Lambda
# --------------------------------------------------

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tasks.function_name
  principal     = "apigateway.amazonaws.com"

  # Restrict invocation permission to this API.
  source_arn = "${aws_apigatewayv2_api.tasks.execution_arn}/*/*"
}
