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
  lambda_name = var.function_name
  environment = var.environment
  # fix 4: el handler correcto es main.handler, no lambda_function.lambda_handler
  handler     = "main.handler"
  publish     = true
  source_dir  = "${path.module}/../app"

  tags = {
    environment = var.environment
    proyecto    = "cloud-lab-fixed"
  }
}

variable "function_name" { type = string; default = "interview-lambda" }
variable "aws_region"    { type = string; default = "us-east-1" }
variable "environment"   { type = string; default = "dev" }

output "function_name" { value = module.lambda.function_name }
output "function_arn"  { value = module.lambda.function_arn }
