import json
import os
import uuid
import boto3
from datetime import datetime, timezone

sqs = boto3.client("sqs")
dynamodb = boto3.resource("dynamodb")

QUEUE_URL  = os.environ["SQS_QUEUE_URL"]
TABLE_NAME = os.environ["DYNAMODB_TABLE"]


def lambda_handler(event, context):
    """
    Recibe el webhook y responde en < 2 segundos.
    El procesamiento pesado lo hace la otra lambda de forma asíncrona.
    """
    try:
        body = json.loads(event.get("body") or "{}")
        execution_id = str(uuid.uuid4())
        ahora = datetime.now(timezone.utc).isoformat()
        # TTL: 90 días desde ahora
        ttl = int(datetime.now(timezone.utc).timestamp()) + (90 * 24 * 60 * 60)

        # guardar registro en dynamo con status pendiente
        tabla = dynamodb.Table(TABLE_NAME)
        tabla.put_item(Item={
            "execution_id": execution_id,
            "created_at":   ahora,
            "status":       "PENDIENTE",
            "payload":      json.dumps(body),
            "expires_at":   ttl,
        })

        # mandar a la cola para procesamiento asíncrono
        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps({
                "execution_id": execution_id,
                "payload":      body,
                "created_at":   ahora,
            }),
        )

        # responder inmediatamente - el cliente no espera el procesamiento
        return {
            "statusCode": 202,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "accepted":     True,
                "execution_id": execution_id,
            }),
        }

    except Exception as e:
        print(f"error en receiver: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "error interno"}),
        }
