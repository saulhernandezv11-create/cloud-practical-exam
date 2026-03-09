# Caso 4 – Corrección pipeline cloud-lab

Revisé el `deploy.yml` original y el `main.tf` y encontré varios problemas que hacen que el pipeline no funcione.

**Pipeline (deploy.yml)**

`pytest` se corre desde la raíz pero `test_main.py` importa desde `app/`, así que no encuentra el módulo. Fix: `cd app && python -m pytest .`

El zip se arma con `zip function.zip app/*` que incluye los archivos de test y no incluye las dependencias. Lambda no puede importar `boto3` en runtime porque no está en el bundle. Fix: instalar deps con `pip install -t package/` y copiar solo `main.py`.

No hay ningún step de credenciales AWS antes del deploy. Fix: agregar `aws-actions/configure-aws-credentials@v4`.

Después de `update-function-code` el pipeline continúa sin esperar a que Lambda termine de procesar el nuevo código. Fix: `aws lambda wait function-updated`.

**Terraform (main.tf)**

El handler está configurado como `lambda_function.lambda_handler` pero la función en `main.py` se llama `handler`. Fix: `handler = "main.handler"`.
