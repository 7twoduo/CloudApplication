# --------------------------------------------------
# 4. Outputs
# --------------------------------------------------

output "gitlab_role_arn" {
  description = "Set this as AWS_ROLE_ARN in GitLab CI/CD"
  value       = aws_iam_role.gitlab_terraform.arn
}

output "gitlab_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.gitlab.arn
}

data "aws_caller_identity" "current" {}

output "aws_account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "The AWS account ID of the current caller"
}