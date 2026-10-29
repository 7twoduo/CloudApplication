
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --------------------------------------------------
# 1. GitLab OIDC Provider
# --------------------------------------------------

resource "aws_iam_openid_connect_provider" "gitlab" {
  url = "https://gitlab.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}

# --------------------------------------------------
# 2. Trust Policy
# Only the configured GitLab project and branch can
# assume this AWS role.
# --------------------------------------------------

data "aws_iam_policy_document" "gitlab_trust" {
  statement {
    sid     = "AllowGitLabMainBranch"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.gitlab.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "gitlab.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "gitlab.com:sub"

      values = [
        "project_path:${var.gitlab_project_path}:ref_type:branch:ref:${var.gitlab_branch}"
      ]
    }
  }
}

# --------------------------------------------------
# 3. GitLab Terraform Deployment Role
# --------------------------------------------------

resource "aws_iam_role" "gitlab_terraform" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.gitlab_trust.json
  max_session_duration = 3600

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "GitLab-CICD"
    Project   = "CloudApplication"
  }
}

# --------------------------------------------------
# 4. Full AWS Administrator Permissions
#
# Allows management of AWS services and resources,
# including VPC, S3, DynamoDB, KMS, Lambda, API
# Gateway, CloudWatch, IAM, and future services.
# --------------------------------------------------

resource "aws_iam_role_policy_attachment" "administrator_access" {
  role = aws_iam_role.gitlab_terraform.name

  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
