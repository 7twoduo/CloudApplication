
# --------------------------------------------------
# Variables
# --------------------------------------------------

variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-1"
}

variable "gitlab_project_path" {
  description = "GitLab namespace/project allowed to assume this role"
  type        = string
  default     = "7twoduo/CloudApplication"
}

variable "gitlab_branch" {
  description = "GitLab branch allowed to assume this role"
  type        = string
  default     = "main"
}

variable "role_name" {
  description = "IAM role used by GitLab CI/CD"
  type        = string
  default     = "GitLabCloudApplicationTerraformRole"
}

variable "terraform_state_bucket" {
  description = "Existing S3 bucket containing Terraform state"
  type        = string
  default     = "deathless-godx"
}

variable "terraform_state_key" {
  description = "Exact Terraform state object key"
  type        = string
  default     = "environments/production/terraform.tfstate"
}
