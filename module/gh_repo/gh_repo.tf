terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

variable "gh_owner" {
  type        = string
  description = "Repository owner"
}

variable "gh_repo_name" {
  type        = string
  description = "Repository name"
}

data "github_repository" "repo" {
  # full_name = "${var.gh_owner}/${var.gh_repo_name}"
  name = var.gh_repo_name
}

output "gh_repo_name" {
  value = data.github_repository.repo.name
}

output "gh_repo_full_name" {
  value = data.github_repository.repo.full_name
}
