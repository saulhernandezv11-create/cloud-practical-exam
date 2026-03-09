import json
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../src"))

from lambda_function import lambda_handler


def test_status_200():
    resp = lambda_handler({}, None)
    assert resp["statusCode"] == 200


def test_body_es_json_valido():
    resp = lambda_handler({}, None)
    body = json.loads(resp["body"])
    assert isinstance(body, str)


def test_tiene_las_claves_requeridas():
    resp = lambda_handler({}, None)
    assert "statusCode" in resp
    assert "body" in resp
