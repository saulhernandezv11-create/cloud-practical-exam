import json
from main import handler


def test_responde_200():
    resp = handler({"name": "test"}, None)
    assert resp["statusCode"] == 200


def test_nombre_en_mensaje():
    resp = handler({"name": "saul"}, None)
    body = json.loads(resp["body"])
    assert body["message"] == "Hello saul"


def test_nombre_por_defecto():
    resp = handler({}, None)
    body = json.loads(resp["body"])
    assert body["message"] == "Hello world"
