# Caso 6 – Webhook asíncrono

El problema es que el cliente espera respuesta en menos de 2 segundos pero el procesamiento tarda 17+. La solución es separar la recepción del procesamiento.

```
cliente → API Gateway → Lambda Receiver → SQS → Lambda Processor → DynamoDB
              (responde 202 en < 2s)              (procesa async, 17+ seg)
```

El Receiver solo guarda el request en DynamoDB con status `PENDIENTE`, manda el mensaje a SQS y responde 202. El Processor consume la cola de forma asíncrona.

Si el Processor falla, SQS reintenta hasta 3 veces. Si sigue fallando, el mensaje va a la DLQ en lugar de perderse.

Uso HTTP API de API Gateway en lugar de REST API porque es ~70% más barato según la [documentación oficial](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html) y para un webhook es más que suficiente.

DynamoDB con `PAY_PER_REQUEST` para no pagar capacidad reservada cuando no hay carga. TTL de 90 días para que los registros se limpien solos.
