terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

module "lambda" {
  source      = "../../case-1-lambda-template/terraform/modules/lambda"
  lambda_name = var.lambda_name
  environment = "dev"
  publish     = true
  log_retention_days = 7
}

resource "aws_cloudwatch_log_group" "staging" {
  name              = "/aws/lambda/${var.lambda_name}/staging"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "prod" {
  name              = "/aws/lambda/${var.lambda_name}/prod"
  retention_in_days = 30
}

resource "aws_lambda_alias" "dev" {
  name             = "dev"
  function_name    = module.lambda.function_name
  function_version = "$LATEST"
  description      = "dev - siempre el código más reciente"
}

resource "aws_lambda_alias" "staging" {
  name             = "staging"
  function_name    = module.lambda.function_name
  function_version = var.version_staging != "" ? var.version_staging : module.lambda.version
}

resource "aws_lambda_alias" "prod" {
  name             = "prod"
  function_name    = module.lambda.function_name
  function_version = var.version_prod != "" ? var.version_prod : module.lambda.version
}

# para rollback: cambiar version_prod en el tfvars y aplicar de nuevo
variable "lambda_name"     { type = string; default = "mi-lambda-multienv" }
variable "aws_region"      { type = string; default = "us-east-1" }
variable "version_staging" { type = string; default = "" }
variable "version_prod"    { type = string; default = "" }

output "alias_dev_arn"     { value = aws_lambda_alias.dev.arn }
output "alias_staging_arn" { value = aws_lambda_alias.staging.arn }
output "alias_prod_arn"    { value = aws_lambda_alias.prod.arn }
output "version_actual"    { value = module.lambda.version }
