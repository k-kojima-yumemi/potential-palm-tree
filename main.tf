terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "github" {
  token = var.gh_token
  owner = var.gh_owner
}

module "gh_repo" {
  source       = "./module/gh_repo"
  gh_repo_name = var.gh_repo_name
  gh_owner     = var.gh_owner
}

output "gh_repo_name" {
  value = module.gh_repo.gh_repo_full_name
}

module "gh_env" {
  source           = "./module/gh_env"
  gh_repo_name     = module.gh_repo.gh_repo_name
  gh_repo_env_name = var.gh_repo_env_name
}

module "aws_id_provider" {
  for_each = length(var.aws_id_provider_arn) == 0 ? toset(["1"]) : toset([])
  source   = "./module/id_provider"
}

module "aws_iam" {
  source          = "./module/iam"
  repo_full_name  = "${var.gh_owner}/${module.gh_repo.gh_repo_name}"
  id_provider_arn = length(var.aws_id_provider_arn) == 0 ? module.aws_id_provider[0].id_provider_arn : var.aws_id_provider_arn
  repo_env_name   = module.gh_env.gh_repo_env_name
  role_name       = var.aws_role_name
}

module "gh_env_values" {
  source                    = "./module/gh_env_secret"
  aws_iam_role_arn          = module.aws_iam.iam_role_arn
  aws_region                = var.aws_region
  gh_repo_name              = module.gh_repo.gh_repo_name
  gh_repo_env_name          = module.gh_env.gh_repo_env_name
  gh_repo_env_secret_name   = var.gh_repo_env_secret_name
  gh_repo_env_variable_name = var.gh_repo_env_variable_name
}
