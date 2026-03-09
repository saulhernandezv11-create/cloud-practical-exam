import json
import os
import boto3
from datetime import datetime, timezone

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ["DYNAMODB_TABLE"]


def lambda_handler(event, context):
    """
    Procesa los mensajes de SQS. Timeout de 60s para cubrir los 17s+ de procesamiento.
    Si falla, SQS reintenta hasta 3 veces antes de mandar a la DLQ.
    """
    tabla = dynamodb.Table(TABLE_NAME)

    for record in event.get("Records", []):
        execution_id = None
        try:
            mensaje      = json.loads(record["body"])
            execution_id = mensaje["execution_id"]
            created_at   = mensaje["created_at"]
            payload      = mensaje.get("payload", {})

            print(f"procesando: {execution_id}")

            _actualizar_status(tabla, execution_id, created_at, "PROCESANDO",
                               procesando_desde=datetime.now(timezone.utc).isoformat())

            # lógica de negocio aquí
            resultado = _procesar(payload)

            _actualizar_status(tabla, execution_id, created_at, "COMPLETADO",
                               completado_en=datetime.now(timezone.utc).isoformat(),
                               resultado=json.dumps(resultado))

            print(f"completado: {execution_id}")

        except Exception as e:
            print(f"error procesando {execution_id}: {e}")
            if execution_id:
                _actualizar_status(tabla, execution_id,
                                   mensaje.get("created_at", ""),
                                   "FALLIDO", error=str(e))
            # re-lanzar para que SQS reintente
            raise


def _procesar(payload: dict) -> dict:
    """
    Aquí va la lógica real que tarda 17+ segundos.
    Por ejemplo: llamada a API externa, transformación de datos, etc.
    """
    # TODO: implementar lógica de negocio
    return {"ok": True, "campos": list(payload.keys())}


def _actualizar_status(tabla, execution_id: str, created_at: str, status: str, **extra):
    sets   = {"#s": ":s"}
    nombres = {"#s": "status"}
    valores = {":s": status}

    for k, v in extra.items():
        sets[k] = f":{k}"
        valores[f":{k}"] = v

    expr = "SET " + ", ".join(f"{k} = {v}" for k, v in sets.items())
    tabla.update_item(
        Key={"execution_id": execution_id, "created_at": created_at},
        UpdateExpression=expr,
        ExpressionAttributeNames=nombres,
        ExpressionAttributeValues=valores,
    )
