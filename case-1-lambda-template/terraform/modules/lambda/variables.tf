variable "lambda_name" {
  type = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.lambda_name))
    error_message = "Solo letras, números, guiones y guiones bajos."
  }
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Tiene que ser dev, staging o prod."
  }
}

variable "source_dir" {
  type    = string
  default = "../../template/src"
}

variable "handler" {
  type    = string
  default = "lambda_function.lambda_handler"
}

variable "memory_size" {
  type    = number
  default = 128
}

variable "timeout" {
  type    = number
  default = 30
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "publish" {
  type    = bool
  default = false
}

variable "env_vars" {
  type    = map(string)
  default = {}
}

variable "description" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
