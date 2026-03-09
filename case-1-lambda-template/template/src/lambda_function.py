import json


def lambda_handler(event, context):
    # TODO: implementar lógica
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }
