# Caso 6 – Webhook asíncrono

## El problema

El cliente externo que llama al webhook espera respuesta en menos de 2 segundos. El procesamiento interno tarda al menos 17 segundos. No se pueden hacer los dos en la misma ejecución.

La solución es separar la recepción del procesamiento:

```
cliente
  │
  ▼
API Gateway → Lambda Receiver
                  │  (< 2 seg)
                  ├── guarda en DynamoDB con status=PENDIENTE
                  ├── manda mensaje a SQS
                  └── responde 202 al cliente  ✓

                              │  (async, el cliente ya no espera)
                              ▼
                          Lambda Processor
                              │  (17+ seg)
                              ├── procesa la información
                              └── actualiza DynamoDB → COMPLETADO / FALLIDO
```

## Recursos y por qué cada uno

**API Gateway (HTTP API)**
El entry point público. Uso HTTP API en lugar de REST API porque es más barato (~70%) y para un endpoint de webhook es más que suficiente.

**Lambda Receiver**
Timeout configurado en 5 segundos. Así si algo se traba en la recepción, Lambda lo corta antes de que el cliente haga timeout. En condiciones normales responde en < 500ms.

**SQS**
El buffer entre la recepción y el procesamiento. Si el procesador se cae, el mensaje sigue en la cola y se reintenta. Con Dead Letter Queue configurada: después de 3 intentos fallidos el mensaje se mueve a la DLQ en lugar de perderse.

**Lambda Processor**
Timeout de 60 segundos (más que suficiente para los 17 seg de procesamiento). Se activa automáticamente cada vez que hay mensajes en la cola.

**DynamoDB**
Historial de todas las ejecuciones. Con `PAY_PER_REQUEST` no se paga capacidad en momentos de baja carga. TTL de 90 días para que los registros se eliminen solos y no crezca indefinidamente.

## Estados de una ejecución

```
PENDIENTE → PROCESANDO → COMPLETADO
                      ↘ FALLIDO (SQS reintenta hasta 3 veces) → DLQ
```

## Monitoreo

Hay tres alarmas de CloudWatch configuradas en Terraform:

- **Mensajes en DLQ > 0** → el procesador está fallando repetidamente
- **Errores del Receiver > 5/min** → algo está mal en la recepción
- **Duration promedio del Receiver > 1.5 seg** → se está acercando al límite de 2 seg

## Consultas útiles

```bash
# ver el estado de una ejecución
aws dynamodb get-item \
  --table-name webhook-async-dev-executions \
  --key '{"execution_id":{"S":"uuid-aqui"},"created_at":{"S":"2024-01-01T00:00:00"}}'

# ver ejecuciones fallidas
aws dynamodb query \
  --table-name webhook-async-dev-executions \
  --index-name status-created_at-index \
  --key-condition-expression '#s = :s' \
  --expression-attribute-names '{"#s":"status"}' \
  --expression-attribute-values '{":s":{"S":"FALLIDO"}}'

# revisar cuántos mensajes hay en la DLQ
aws sqs get-queue-attributes \
  --queue-url <url-dlq> \
  --attribute-names ApproximateNumberOfMessages
```

## Cómo desplegarlo

```bash
cd case-6-webhook-async/terraform
terraform init
terraform apply -var="environment=dev"

# probar
curl -X POST $(terraform output -raw webhook_endpoint) \
  -H 'Content-Type: application/json' \
  -d '{"evento": "orden_creada", "id": "12345"}'

# respuesta esperada
# {"accepted": true, "execution_id": "uuid-generado"}
```

## Costo estimado

Para 100,000 webhooks al mes el costo es prácticamente cero: ~$1.20/mes entre API Gateway, ambas lambdas, SQS y DynamoDB. El free tier de Lambda y SQS cubre la mayoría.
