terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      managed-by  = "terraform"
      environment = var.environment
      proyecto    = "lambda-template"
    }
  }
}

module "lambda" {
  source = "./modules/lambda"

  lambda_name        = var.lambda_name
  environment        = var.environment
  description        = var.description
  memory_size        = var.memory_size
  timeout            = var.timeout
  log_retention_days = var.log_retention_days
  env_vars           = var.env_vars

  tags = {
    environment = var.environment
  }
}
