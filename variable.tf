variable "aws_region" {
  type = string
  description = "The region of AWS resources, like ap-northeast-1"
}

variable "gh_token" {
  sensitive = true
  type = string
  description = <<EOF
A token to access github, can be given via command line
`terraform plan -var "gh_token=$(gh auth token)"`
EOF
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
  description = "The name of secret in environment, where the IAM Role arn is saved"
}

variable "gh_repo_env_variable_name" {
  type = string
  description = "The name of variable in environment, where the AWS Region is saved"
}

variable "aws_id_provider_arn" {
  type = string
  default = ""
  description = "If give, the IAM Role is created with this arn. If empty, a new provider is created and used in role"
}

variable "aws_role_name" {
  type = string
  description = "The name of IAM Role"
}
