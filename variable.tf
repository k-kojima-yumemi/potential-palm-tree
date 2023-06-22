variable "aws_region" {
  type = string
}

variable "gh_token" {
  sensitive = true
  type = string
  description = "A token to access github, can be given via command line"
}

variable "gh_owner" {
  type = string
  description = "Repository owner"
}

variable "gh_repo_name" {
  type        = string
  description = "Repository name, no containing owner"
}

variable "gh_repo_env_name" {
  type        = string
  description = "Environment name to be created"
}

variable "gh_repo_env_secret_name" {
  type = string
}

variable "gh_repo_env_variable_name" {
  type = string
}

variable "aws_id_provider_arn" {
  type = string
  default = ""
}

variable "aws_role_name" {
  type = string
}
