terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

variable "gh_repo_name" {
  type = string
}

variable "gh_repo_env_name" {
  type = string
}

variable "gh_repo_env_secret_name" {
  type = string
}

variable "gh_repo_env_variable_name" {
  type = string
}

variable "aws_iam_role_arn" {
  type = string
}

variable "aws_region" {
  type = string
}

resource "github_actions_environment_secret" "gh_env_secret_arn" {
  repository = var.gh_repo_name
  environment = var.gh_repo_env_name
  secret_name = var.gh_repo_env_secret_name
  # Actually, arn is not sensitive value so just use plain text.
  plaintext_value = var.aws_iam_role_arn
}

resource "github_actions_environment_variable" "gh_env_variable_region" {
  repository = var.gh_repo_name
  environment = var.gh_repo_env_name
  variable_name = var.gh_repo_env_variable_name
  value = var.aws_region
}
