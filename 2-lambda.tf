# Package the Python Lambda function.
data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "${path.module}/src/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda needs its own execution role.
# This is separate from the GitLab OIDC deployment role.
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_execution" {
  name               = "${var.project_name}-lambda-execution"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project   = "CloudApplication"
    ManagedBy = "Terraform"
  }
}

# Provides CloudWatch logging and permissions Lambda needs
# to manage its network interfaces in the configured VPC.
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role = aws_iam_role.lambda_execution.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Allow this function to read and write only the tasks table.

data "aws_iam_policy_document" "lambda_dynamodb" {
  # Allow the application to create and retrieve tasks.
  statement {
    sid    = "TaskTableReadWrite"
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem"
    ]

    resources = [
      aws_dynamodb_table.tasks.arn
    ]
  }

  # Allow DynamoDB to use the customer-managed KMS key
  # on behalf of this Lambda execution role.
  statement {
    sid    = "UseTasksKmsKey"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]

    resources = [
      aws_kms_key.tasks.arn
    ]
  }
}


resource "aws_iam_role_policy" "lambda_dynamodb" {
  name   = "${var.project_name}-tasks-access"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.lambda_dynamodb.json
}

# Security group for Lambda.
# No inbound rules are needed for this API design.
# Outbound HTTPS goes through the existing NAT Gateway.
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Allow Lambda outbound HTTPS to DynamoDB"
  vpc_id      = aws_vpc.main.id

  # Permit HTTPS only to DynamoDB's AWS-managed IP ranges.
  egress {
    description     = "HTTPS to DynamoDB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.dynamodb.id]
  }

  tags = {
    Name    = "${var.project_name}-lambda-sg"
    Project = "CloudApplication"
  }
}

# Deploy Lambda into both private subnets.
resource "aws_lambda_function" "tasks" {
  function_name = "${var.project_name}-tasks"
  description   = "Creates and retrieves tasks using DynamoDB"

  role             = aws_iam_role.lambda_execution.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  memory_size = 128
  timeout     = 10

  environment {
    variables = {
      TASKS_TABLE = aws_dynamodb_table.tasks.name
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy.lambda_dynamodb
  ]

  tags = {
    Project   = "CloudApplication"
    ManagedBy = "Terraform"
  }
}
