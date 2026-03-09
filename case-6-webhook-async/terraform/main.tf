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
      proyecto    = "webhook-async"
      environment = var.environment
    }
  }
}

locals {
  prefijo = "${var.project_name}-${var.environment}"
}

# ── IAM: receiver ────────────────────────────────────────────────────────────

resource "aws_iam_role" "receiver" {
  name = "${local.prefijo}-receiver-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "receiver" {
  role = aws_iam_role.receiver.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.principal.arn
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:GetItem"]
        Resource = [aws_dynamodb_table.ejecuciones.arn, "${aws_dynamodb_table.ejecuciones.arn}/index/*"]
      }
    ]
  })
}

# ── IAM: processor ───────────────────────────────────────────────────────────

resource "aws_iam_role" "processor" {
  name = "${local.prefijo}-processor-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "processor" {
  role = aws_iam_role.processor.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
        Resource = aws_sqs_queue.principal.arn
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:GetItem", "dynamodb:Query"]
        Resource = [aws_dynamodb_table.ejecuciones.arn, "${aws_dynamodb_table.ejecuciones.arn}/index/*"]
      }
    ]
  })
}

# ── SQS ──────────────────────────────────────────────────────────────────────

resource "aws_sqs_queue" "dlq" {
  name                      = "${local.prefijo}-dlq"
  message_retention_seconds = 1209600 # 14 días
}

resource "aws_sqs_queue" "principal" {
  name                       = "${local.prefijo}-queue"
  visibility_timeout_seconds = 60      # tiene que ser mayor al timeout del processor
  message_retention_seconds  = 86400   # 24h

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# ── DynamoDB ─────────────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "ejecuciones" {
  name         = "${local.prefijo}-ejecuciones"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "execution_id"
  range_key    = "created_at"

  attribute { name = "execution_id"; type = "S" }
  attribute { name = "created_at";   type = "S" }
  attribute { name = "status";       type = "S" }

  global_secondary_index {
    name            = "status-created_at-index"
    hash_key        = "status"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}

# ── Lambda: receiver ─────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "receiver" {
  name              = "/aws/lambda/${local.prefijo}-receiver"
  retention_in_days = 14
}

data "archive_file" "receiver" {
  type        = "zip"
  source_file = "${path.module}/../src/webhook_receiver/lambda_function.py"
  output_path = "${path.module}/.build/receiver.zip"
}

resource "aws_lambda_function" "receiver" {
  function_name    = "${local.prefijo}-receiver"
  filename         = data.archive_file.receiver.output_path
  source_code_hash = data.archive_file.receiver.output_base64sha256
  role             = aws_iam_role.receiver.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 5 # garantiza respuesta < 2s; si algo se traba, lambda lo corta a los 5s

  environment {
    variables = {
      SQS_QUEUE_URL  = aws_sqs_queue.principal.url
      DYNAMODB_TABLE = aws_dynamodb_table.ejecuciones.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.receiver]
}

# ── Lambda: processor ────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "processor" {
  name              = "/aws/lambda/${local.prefijo}-processor"
  retention_in_days = 14
}

data "archive_file" "processor" {
  type        = "zip"
  source_file = "${path.module}/../src/processor/lambda_function.py"
  output_path = "${path.module}/.build/processor.zip"
}

resource "aws_lambda_function" "processor" {
  function_name    = "${local.prefijo}-processor"
  filename         = data.archive_file.processor.output_path
  source_code_hash = data.archive_file.processor.output_base64sha256
  role             = aws_iam_role.processor.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  architectures    = ["arm64"]
  memory_size      = 256
  timeout          = 60 # margen suficiente para los 17s+ de procesamiento

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.ejecuciones.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.processor]
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.principal.arn
  function_name    = aws_lambda_function.processor.function_name
  batch_size       = 1
  enabled          = true
}

# ── API Gateway ───────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/${local.prefijo}"
  retention_in_days = 7
}

resource "aws_apigatewayv2_api" "webhook" {
  name          = "${local.prefijo}-api"
  protocol_type = "HTTP" # HTTP API es 70% más barato que REST API para este caso
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.webhook.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
  }
}

resource "aws_apigatewayv2_integration" "receiver" {
  api_id                 = aws_apigatewayv2_api.webhook.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.receiver.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "webhook" {
  api_id    = aws_apigatewayv2_api.webhook.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.receiver.id}"
}

resource "aws_lambda_permission" "apigw" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.receiver.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.webhook.execution_arn}/*/*"
}

# ── CloudWatch Alarms ─────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "dlq_con_mensajes" {
  alarm_name          = "${local.prefijo}-dlq-mensajes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Hay mensajes en la DLQ - el processor está fallando"
  dimensions          = { QueueName = aws_sqs_queue.dlq.name }
}

resource "aws_cloudwatch_metric_alarm" "receiver_errores" {
  alarm_name          = "${local.prefijo}-receiver-errores"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "El receiver tiene más de 5 errores por minuto"
  dimensions          = { FunctionName = aws_lambda_function.receiver.function_name }
}

resource "aws_cloudwatch_metric_alarm" "receiver_lento" {
  alarm_name          = "${local.prefijo}-receiver-lento"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Average"
  threshold           = 1500 # alerta a 1.5s para reaccionar antes de romper el SLA de 2s
  alarm_description   = "El receiver promedia más de 1.5s - riesgo de romper el SLA"
  dimensions          = { FunctionName = aws_lambda_function.receiver.function_name }
}
