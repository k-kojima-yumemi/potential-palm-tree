# TerraformでAWSのIAM Roleを作成しGitHubの設定まで一気に済ませる

# 概要

TerraformではAWSなどのクラウドサービスのみならず、GitHubのリソースの管理もできます。
本記事ではTerraformを使ってGitHub ActionsからAssume RoleできるIAM Roleの作成をします。
また、TerraformでGitHub Actionsのシークレットに作成したRoleのarnを登録するところまで一括でやります。

## 参考

* https://zenn.dev/kou_pg_0131/articles/gh-actions-oidc-aws
* https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
* https://zenn.dev/miyajan/articles/github-actions-support-openid-connect
  * TerraformでOpenID Providerを作成する部分はこの記事を参考に作成しました

検証に使用したコードは以下のリポジトリにあります。

https://github.com/k-kojima-yumemi/potential-palm-tree

# 使用する環境

* terraform
  * v1.4.7

# Terraformの作成

ここではコードの例を紹介しますが、変数の定義は省略しています。
ある程度推測できる命名にしているので、渡している情報の参考にしてください。
上のリンクのリポジトリには変数の定義を含むコードがあるので、そちらも参照してください。

## 今回作成する構成

GitHubのリポジトリは既存のものを使用します。
GitHub ActionsのEnvironmentsの機能を使用するために、Environmentsを作成します。
またその中にsecretとしてIAM Roleのarn、variableとしてリージョンを入れます。

IAM Roleには何もPolicyをアタッチせず、GitHub ActionsからAssume Roleできるのみにします。

## 使用するProvider

```terraform
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
```

IAM Roleを作成するためにawsのProvider, GitHubのリソース作成のためにgithubのProviderを使用します。
GitHubのProviderはdeprecatedになった昔のものもあるので、sourceを指定して正しいProviderを使用するようにしてください。

GitHubのProviderのドキュメントはこちらです。
https://registry.terraform.io/providers/integrations/github/latest/docs

各Providerの設定は以下のようにしました
```terraform
provider "aws" {
  region = var.aws_region
}

provider "github" {
  token = var.gh_token
  owner = var.gh_owner
}
```
GitHubのTokenはGitHub CLIから入手できるものを使用しています。
実行時に`terraform plan -var "gh_token=$(gh auth token)"`のようにすることで挿入しています。
`owner`はOptionalであるとドキュメントにはありますが、`owner`の値がセットされない泥沼にはまったため指定しています。
操作したいリポジトリの所有者を入れておきます。
`k-kojima-yumemi/potential-palm-tree`のリポジトリであれば、`k-kojima-yumemi`の部分が`owner`です。

## Moduleにする際の注意点

再利用性を考えてModuleにする際にProviderで設定した内容が反映されずハマってしまうポイントがあります。

Module側でProviderを指定せずにGitHubのリソースを参照したり作成すると、deprecatedである`hashicorp/github`が使われてしまいます。
その場合、最初に設定したProviderの内容が別のProviderの情報として扱われてしまうため、設定した項目がModule内では反映されなくなってしまいます。
そのためModuleのリソースを定義するファイルに以下の要素を指定することでProviderがずれてしまう問題を解決しています。

```terraform
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}
```

`terraform providers`を実行した際に、githubのProviderがdeprecatedであるメッセージが出た際にはこの現象が起こっている可能性があります。

## Environmentsの作成

Environmentsは[`github_repository_environment`](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_environment)のリソースで作成できます。

```terraform
resource "github_repository_environment" "gh_env" {
  repository = var.gh_repo_name
  environment = var.gh_repo_env_name
}
```
`repository`はownerを含まない文字列である必要があります。
どうやらここの文字列と、Provider側で保持しているownerを`/{owner}/{repogitory}`の形で結合してAPIを呼び出しているようです。
`environment`はEnvironmentsの名称で、後で指定するIAM Roleでの指定と合わせる必要があります。

## AWSのID Providerの作成

ID Providerは https://zenn.dev/miyajan/articles/github-actions-support-openid-connect を参考に作成しました。

```terraform
# Ref: https://zenn.dev/miyajan/articles/github-actions-support-openid-connect

data "http" "github_actions_openid_configuration" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

data "tls_certificate" "github_actions" {
  url = jsondecode(data.http.github_actions_openid_configuration.response_body).jwks_uri
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = data.tls_certificate.github_actions.certificates[*].sha1_fingerprint
}

output "id_provider_arn" {
  value = aws_iam_openid_connect_provider.github_actions.arn
}
```

IAM Roleの作成でID Providerのarnを使用するのでOutputに追加しています。

## IAM Roleの作成

先ほど作成したID Providerを使って認証できるIAM Roleを作成します。
また、認証元を作成したGitHubのEnvironmentからに限定します。

```terraform
resource "aws_iam_role" "iam" {
  name = var.role_name
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : var.id_provider_arn
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
```

`token.actions.githubusercontent.com:sub`の指定でリポジトリとEnvironmentsを指定しています。
ここでのリポジトリ名は`{owner}/{repogitory}`の形を指定します。

## EnvironmentへのSecretとVariableの登録

IAM RoleのarnとAWSのリージョンをGitHubのEnvironmentsに登録します。
Environment Secretの作成には`github_actions_environment_secret`を使用します。
Variableには`github_actions_environment_variable`です。

```terraform
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
```

[ドキュメント](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_environment_secret)にもある通り、本来はシークレットの内容は暗号化するべきです。
今回Secretに書き込むのはIAM Roleのarnで、秘匿性は低いため`plaintext_value`の指定にしています。
`plaintext_value`で入れた値は`terraform.tfstate`の中に平文で保存されています。
実際に秘匿性の高い情報を扱う際には暗号化したり別の手段で値を入れるなどの方法を検討してください。

# Plan

ここまでの内容で作成したTerraformで`terraform plan`を実行した例を紹介します。
検証に使用したGitHubのリポジトリを対象に実行しています。
すでにID Providerが存在する環境なので、ID Providerは作成していません。
また、ID Providerのarnは隠してあります。

```text
module.gh_repo.data.github_repository.repo: Reading...
module.gh_repo.data.github_repository.repo: Read complete after 0s [id=potential-palm-tree]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # module.aws_iam.aws_iam_role.iam will be created
  + resource "aws_iam_role" "iam" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRoleWithWebIdentity"
                      + Condition = {
                          + StringEquals = {
                              + "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
                              + "token.actions.githubusercontent.com:sub" = "repo:k-kojima-yumemi/potential-palm-tree:environment:env1"
                            }
                        }
                      + Effect    = "Allow"
                      + Principal = {
                          + Federated = "<Arn of ID Provider>"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + description           = "Test role created in terraform"
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "k_kojima_terraform_with_github"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags_all              = (known after apply)
      + unique_id             = (known after apply)
    }

  # module.gh_env.github_repository_environment.gh_env will be created
  + resource "github_repository_environment" "gh_env" {
      + environment = "env1"
      + id          = (known after apply)
      + repository  = "potential-palm-tree"
    }

  # module.gh_env_values.github_actions_environment_secret.gh_env_secret_arn will be created
  + resource "github_actions_environment_secret" "gh_env_secret_arn" {
      + created_at      = (known after apply)
      + environment     = "env1"
      + id              = (known after apply)
      + plaintext_value = (sensitive value)
      + repository      = "potential-palm-tree"
      + secret_name     = "test_secret"
      + updated_at      = (known after apply)
    }

  # module.gh_env_values.github_actions_environment_variable.gh_env_variable_region will be created
  + resource "github_actions_environment_variable" "gh_env_variable_region" {
      + created_at    = (known after apply)
      + environment   = "env1"
      + id            = (known after apply)
      + repository    = "potential-palm-tree"
      + updated_at    = (known after apply)
      + value         = "ap-northeast-1"
      + variable_name = "AWS_REGION"
    }

Plan: 4 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + gh_repo_name = "k-kojima-yumemi/potential-palm-tree"

─────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't
guarantee to take exactly these actions if you run "terraform apply" now.
```

Applyするとこのようにリソースが作成されます。

![Environments.png](https://raw.githubusercontent.com/k-kojima-yumemi/potential-palm-tree/main/article/Environments.png)

# GitHub Actionsの実行

検証のため、以下でWorkflowを定義しました。

```yaml
name: Test AWS

on:
  push:

jobs:
  access:
    runs-on: ubuntu-latest
    environment: env1
    permissions:
      id-token: write
    steps:
      - name: access
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-region: ${{vars.AWS_REGION}}
          role-to-assume: ${{secrets.TEST_SECRET}}
```

今回作成したEnvironment内でAssume RoleするだけのWorkflowです。
このように正常に動作することが確認できます。

![Workflow.png](https://raw.githubusercontent.com/k-kojima-yumemi/potential-palm-tree/main/article/Workflow.png)
