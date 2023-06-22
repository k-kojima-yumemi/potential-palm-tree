variable "repo_full_name" {
  type = string
}

variable "token_arn" {
  type = string
}

variable "repo_env_name" {
  type = string
}

variable "role_name" {
  type = string
}

resource "aws_iam_role" "iam" {
  name = var.role_name
  description = "Test role created in terrafrom"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : var.token_arn
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com",
            "token.actions.githubusercontent.com:sub" : "repo:${var.repo_full_name}:environment:${var.repo_env_name}"
          },
        }
      }
    ]
  })
}

output "iam_role_arn" {
  value = aws_iam_role.iam.arn
}
