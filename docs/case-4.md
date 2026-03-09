# Caso 4 – Corrección del pipeline cloud-lab

## Problemas encontrados

Revisé el `deploy.yml` original y tiene varios problemas que lo hacen no funcional o poco confiable. Los anoto todos con el fix correspondiente.

---

### Problema 1 – `pytest` sin ruta

```yaml
# original
- name: Run tests
  run: pytest
```

Esto falla porque `test_main.py` hace `from main import handler`, y `main.py` está en `app/`. Corriendo `pytest` desde la raíz, Python no encuentra el módulo.

```yaml
# fix
- name: Run tests
  run: cd app && python -m pytest . -v
```

---

### Problema 2 – El ZIP está mal armado

```yaml
# original
- name: Package Lambda
  run: zip function.zip app/*
```

Dos problemas aquí:
- `app/*` mete `test_main.py` y `requirements.txt` dentro del bundle (no deberían estar)
- Las dependencias (`boto3`) **no se incluyen**, así que Lambda no puede importarlas en runtime

```yaml
# fix
- name: Package Lambda
  run: |
    mkdir -p package
    pip install -r app/requirements.txt -t package/
    cp app/main.py package/
    cd package && zip -r ../function.zip . -x "*.pyc" -x "__pycache__/*"
```

---

### Problema 3 – No hay credenciales AWS configuradas

El step de deploy llama a `aws lambda update-function-code` pero nunca se configuraron credenciales en el job. Fallaría con un error de autenticación.

```yaml
# fix: agregar antes del deploy
- name: Configurar credenciales AWS
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1
```

---

### Problema 4 – Handler incorrecto

La función en `main.py` se llama `handler`, no `lambda_handler`. Y el archivo se llama `main.py`, no `lambda_function.py`. La configuración de la Lambda tiene que reflejar eso.

```hcl
# en Terraform
handler = "main.handler"
```

---

### Problema 5 – No espera a que el update termine

Después de `update-function-code`, Lambda puede tardar unos segundos en procesar el nuevo código. Si se invoca inmediatamente puede agarrar la versión vieja.

```yaml
# fix
- run: |
    aws lambda update-function-code ...
    aws lambda wait function-updated --function-name interview-lambda
```

---

### Problema 6 – Sin verificación post-deploy

Si el código nuevo tiene un bug, el pipeline reporta éxito igual. No hay forma de saberlo hasta que alguien lo reporta.

Agregué un smoke test que invoca la lambda después del deploy y hace rollback automático si falla.

---

## Resumen

| # | Problema | Fix |
|---|----------|-----|
| 1 | `pytest` sin ruta | `cd app && python -m pytest .` |
| 2 | ZIP sin deps, con archivos de test | `pip install -t package/` + solo `main.py` |
| 3 | Sin credenciales AWS | `aws-actions/configure-aws-credentials@v4` |
| 4 | Handler apuntando al archivo equivocado | `main.handler` en Terraform |
| 5 | Sin espera post-update | `lambda wait function-updated` |
| 6 | Sin verificación de que funcionó | smoke test + rollback automático |

## Cómo ejecutarlo

```bash
# crear la infraestructura primero
cd case-4-fix-existing-project/terraform
terraform init
terraform apply -var="function_name=interview-lambda"

# agregar secrets en GitHub y hacer push a main
```

Verificación manual:
```bash
aws lambda invoke \
  --function-name interview-lambda \
  --payload '{"name": "saul"}' \
  response.json && cat response.json
# esperado: {"statusCode": 200, "body": "{\"message\": \"Hello saul\"}"}
```
