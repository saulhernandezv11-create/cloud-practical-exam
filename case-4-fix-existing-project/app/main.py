import json


def handler(event, context):
    name = event.get("name", "world")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": f"Hello {name}"
        })
    }
