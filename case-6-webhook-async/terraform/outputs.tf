output "webhook_url"    { value = "${aws_apigatewayv2_stage.default.invoke_url}/webhook" }
output "tabla_dynamo"   { value = aws_dynamodb_table.ejecuciones.name }
output "queue_url"      { value = aws_sqs_queue.principal.url }
output "dlq_url"        { value = aws_sqs_queue.dlq.url }
output "receiver_arn"   { value = aws_lambda_function.receiver.arn }
output "processor_arn"  { value = aws_lambda_function.processor.arn }
