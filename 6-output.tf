# --------------------------------------------------
# 9. Outputs
# --------------------------------------------------

output "vpc_id" {
  value = aws_vpc.main.id
}

output "availability_zones" {
  value = local.availability_zones
}

output "internet_gateway_id" {
  value = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.main.id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}


output "tasks_table_name" {
  description = "DynamoDB table name used by Lambda"
  value       = aws_dynamodb_table.tasks.name
}

output "tasks_table_arn" {
  description = "DynamoDB table ARN for IAM permissions"
  value       = aws_dynamodb_table.tasks.arn
}

output "tasks_kms_key_arn" {
  description = "Customer-managed key encrypting the table"
  value       = aws_kms_key.tasks.arn
}





output "lambda_function_name" {
  description = "Task API Lambda function name"
  value       = aws_lambda_function.tasks.function_name
}

output "lambda_function_arn" {
  description = "Task API Lambda function ARN"
  value       = aws_lambda_function.tasks.arn
}

# --------------------------------------------------
# 6. Outputs
# --------------------------------------------------

output "api_endpoint" {
  description = "Public HTTPS endpoint for the Task API"
  value       = aws_apigatewayv2_api.tasks.api_endpoint
}
