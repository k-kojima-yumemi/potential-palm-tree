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

resource "github_repository_environment" "gh_env" {
  repository  = var.gh_repo_name
  environment = var.gh_repo_env_name
}

output "gh_repo_env_name" {
  value = github_repository_environment.gh_env.environment
}
