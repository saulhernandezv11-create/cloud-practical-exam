# Monitoreo

Las alarmas están definidas en `terraform/main.tf`.

## Alarmas configuradas

| Alarma | Condición | Qué significa |
|--------|-----------|---------------|
| `dlq-mensajes` | Mensajes en DLQ > 0 | El procesador está fallando repetidamente |
| `receiver-errores` | Errores del receiver > 5/min | Algo está roto en la recepción |
| `receiver-lento` | Duration promedio > 1,500ms | Nos estamos acercando al límite de 2s |

## Consultas útiles

```bash
# ver estado de una ejecución
aws dynamodb get-item \
  --table-name <TABLA> \
  --key '{"execution_id":{"S":"<UUID>"},"created_at":{"S":"<ISO8601>"}}'

# todas las ejecuciones fallidas
aws dynamodb query \
  --table-name <TABLA> \
  --index-name status-created_at-index \
  --key-condition-expression '#s = :s' \
  --expression-attribute-names '{"#s":"status"}' \
  --expression-attribute-values '{":s":{"S":"FALLIDO"}}'

# cuántos mensajes hay en la DLQ
aws sqs get-queue-attributes \
  --queue-url <URL_DLQ> \
  --attribute-names ApproximateNumberOfMessages

# logs del receiver en tiempo real
aws logs tail /aws/lambda/<PREFIJO>-receiver --follow

# logs del processor
aws logs tail /aws/lambda/<PREFIJO>-processor --follow
```
