variable "lambda_name" { type = string }
variable "aws_region"  { type = string; default = "us-east-1" }
variable "environment" { type = string; default = "dev" }
variable "description" { type = string; default = "" }
variable "memory_size" { type = number; default = 128 }
variable "timeout"     { type = number; default = 30 }
variable "log_retention_days" { type = number; default = 7 }
variable "env_vars"    { type = map(string); default = {} }
